extends BaseTest

const TrainingService := preload("res://scripts/campaign/campaign_training_service.gd")

func _state(party_size: int = 0, resources := {"food": 10.0, "wood": 0.0, "iron": 5.0}) -> Dictionary:
	var party: Array = []
	for index in range(party_size):
		party.append({"id": "existing_%d" % index, "class": "fighter", "race": "humans",
			"level": 1, "xp": 0, "stats": {"str": 13}, "luck": 0})
	return {
		"campaign": {"turn": 1, "seed": 1, "phase": "city"},
		"resources": resources.duplicate(true),
		"population": {"count": 20, "housing": 20},
		"party": party,
		"city": {"buildings": {}, "districts": [], "campaign_buildings": [
			{"uid": 10, "id": "barracks", "state": "active"},
		]},
		"map": {"region": "R01", "fog": {}, "nodes": {}},
		"prestige": {"ledger": []},
		"sign": {"id": "R1", "progress": 0},
	}

func _building_catalog(requires_admin: bool = false) -> Dictionary:
	return {"schema_version": 1, "buildings": [{
		"id": "barracks",
		"training": [{"class_id": "fighter", "costs": {"food": 2.0, "iron": 1.0}}],
		"prerequisites": {"buildings": ["admin"] if requires_admin else [],
			"scenario_flags": [], "admin_capacity": 0},
	}]}

func _trainee(stats := {"str": 13, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}) -> Dictionary:
	return {"id": "trainee_1", "name": "Ari", "race": "humans", "stats": stats, "luck": 0}

func test_training_choices_expose_only_approved_classes() -> void:
	var state := _state()
	var catalog := _building_catalog()
	catalog.buildings[0].training.append({"class_id": "swordsmen", "costs": {"food": 1.0}})
	catalog.buildings[0].training.append({"class_id": "warship", "costs": {"food": 1.0}})
	var options := TrainingService.available_training_actions(state, catalog)
	assert_that(options.size()).is_equal(1)
	assert_that(options[0].class_id).is_equal("fighter")
	assert_that(TrainingService.available_training_actions(_state(5), catalog).is_empty()).is_true()

func test_unlocks_ignore_legacy_city_level() -> void:
	var low_level := _state()
	low_level.city["level"] = 1
	var high_level := _state()
	high_level.city["level"] = 11
	var low_options := TrainingService.available_training_actions(low_level, _building_catalog())
	var high_options := TrainingService.available_training_actions(high_level, _building_catalog())
	assert_that(low_options).is_equal(high_options)
	var result := TrainingService.train(low_level, _building_catalog(), 10, "fighter", _trainee())
	assert_that(result.ok).is_true()

func test_training_adds_approved_character_and_commits_registered_costs() -> void:
	var state := _state()
	var result := TrainingService.train(state, _building_catalog(), 10, "fighter", _trainee())
	assert_that(result.ok).is_true()
	assert_that(state.party.size()).is_equal(1)
	assert_that(state.party[0].class).is_equal("fighter")
	assert_that(state.resources.food).is_equal(8.0)
	assert_that(state.resources.iron).is_equal(4.0)
	assert_that(result.flow.source).is_equal("training:trainee_1/class:fighter")

func test_training_uses_shared_resource_context_when_integrated_with_city() -> void:
	var state := _state()
	var resources := ResourceContext.new()
	resources.setup(Resources.get_campaign_resource_defs(true), true)
	resources.deserialize(state.resources)
	var result := TrainingService.train(
		state, _building_catalog(), 10, "fighter", _trainee(), [], 0,
		TrainingService.PARTY_CAPACITY, resources)
	assert_bool(result.ok).is_true()
	assert_that(state.resources).is_equal(resources.serialize())
	assert_float(resources.amount(&"food")).is_equal_approx(8.0, 0.0001)
	assert_float(resources.amount(&"iron")).is_equal_approx(4.0, 0.0001)
	var ledger := resources.get_ledger()
	assert_that(ledger.size()).is_equal(1)
	assert_that(ledger[0].source).is_equal("training:trainee_1/class:fighter")

func test_training_rejects_missing_class_gate_or_building_prerequisite() -> void:
	var bad_gate := _state()
	var gate_result := TrainingService.train(
		bad_gate, _building_catalog(), 10, "fighter", _trainee({"str": 12, "dex": 10}))
	assert_that(gate_result.ok).is_false()
	assert_that(gate_result.reason.begins_with("class_gate:")).is_true()
	assert_that(bad_gate.party.is_empty()).is_true()

	var missing_admin := _state()
	var prereq_result := TrainingService.train(
		missing_admin, _building_catalog(true), 10, "fighter", _trainee())
	assert_that(prereq_result.ok).is_false()
	assert_that(prereq_result.reason).is_equal("prerequisite_missing")
	assert_that(missing_admin.resources.food).is_equal(10.0)

func test_training_rejects_full_party_and_unapproved_generic_unit() -> void:
	var full := _state(5)
	var capacity_result := TrainingService.train(full, _building_catalog(), 10, "fighter", _trainee())
	assert_that(capacity_result.ok).is_false()
	assert_that(capacity_result.reason).is_equal("party_capacity_reached")
	assert_that(full.resources.food).is_equal(10.0)

	var unsupported := _state()
	var unit_result := TrainingService.train(unsupported, _building_catalog(), 10, "swordsmen", _trainee())
	assert_that(unit_result.ok).is_false()
	assert_that(unit_result.reason).is_equal("unsupported_class:swordsmen")
	assert_that(unsupported.party.is_empty()).is_true()

func test_training_payment_failure_is_atomic() -> void:
	var state := _state(0, {"food": 10.0, "wood": 0.0, "iron": 0.0})
	var before_resources: Dictionary = state.resources.duplicate(true)
	var result := TrainingService.train(state, _building_catalog(), 10, "fighter", _trainee())
	assert_that(result.ok).is_false()
	assert_that(result.reason).is_equal("insufficient_stock")
	assert_that(state.resources).is_equal(before_resources)
	assert_that(state.party.is_empty()).is_true()

func test_training_rejects_inactive_building_and_unknown_resource() -> void:
	var inactive := _state()
	inactive.city.campaign_buildings[0].state = "ruined"
	var inactive_result := TrainingService.train(inactive, _building_catalog(), 10, "fighter", _trainee())
	assert_that(inactive_result.reason).is_equal("training_building_unavailable")
	assert_that(inactive.resources.food).is_equal(10.0)

	var unknown_cost := _state()
	var bad_catalog := _building_catalog()
	bad_catalog.buildings[0].training[0].costs = {"gold": 1.0}
	var resource_result := TrainingService.train(unknown_cost, bad_catalog, 10, "fighter", _trainee())
	assert_that(resource_result.reason).is_equal("unregistered_training_resource:gold")
	assert_that(unknown_cost.party.is_empty()).is_true()

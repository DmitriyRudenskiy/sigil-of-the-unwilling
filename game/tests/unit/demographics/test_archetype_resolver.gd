extends BaseTest

const Resolver = preload("res://scripts/demographics/archetype_resolver.gd")

var catalog: Dictionary = {}
var groups_by_id: Dictionary = {}

func before_test() -> void:
	catalog = Resolver.load_catalog()
	groups_by_id.clear()
	for group in catalog.get("groups", []):
		groups_by_id[group.id] = group

func test_archetype_profiles_and_pair_matrix_are_complete() -> void:
	assert_that(groups_by_id.size()).is_equal(7)
	for group_id in groups_by_id:
		var profile: Dictionary = groups_by_id[group_id]
		assert_that(String(profile.get("signature_need", "")).is_empty()).is_false()
		assert_that(Array(profile.get("preferred_roles", [])).is_empty()).is_false()
		assert_that(int(profile.get("unmet_response_period_turns", 0)) > 0).is_true()

	var expected_pairs := {}
	var ids: Array = groups_by_id.keys()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var expected_a := String(ids[i])
			var expected_b := String(ids[j])
			if expected_a > expected_b:
				var pair_swap := expected_a
				expected_a = expected_b
				expected_b = pair_swap
			expected_pairs[expected_a + "|" + expected_b] = true

	var found_pairs := {}
	for relation in catalog.get("group_relations", []):
		var relation_a := String(relation.a)
		var relation_b := String(relation.b)
		if relation_a > relation_b:
			var relation_swap := relation_a
			relation_a = relation_b
			relation_b = relation_swap
		var key := relation_a + "|" + relation_b
		assert_that(expected_pairs.has(key)).is_true()
		assert_that(found_pairs.has(key)).is_false()
		assert_that(int(relation.value) >= -2 and int(relation.value) <= 2).is_true()
		found_pairs[key] = true
	assert_that(found_pairs.size()).is_equal(expected_pairs.size())

func test_need_coverage_and_satisfaction_are_deterministic() -> void:
	assert_that(Resolver.need_coverage_percent(0, 0)).is_equal(100)
	assert_that(Resolver.need_coverage_percent(3, 2)).is_equal(66)
	assert_that(Resolver.need_coverage_percent(4, 8)).is_equal(100)
	assert_that(Resolver.need_coverage_percent(4, -1)).is_equal(0)

	var rules: Dictionary = catalog.archetype_rules
	var low: Dictionary = Resolver.resolve_need_turn(
		groups_by_id.engineers_builders, 50, 4, 100, rules)
	assert_that(low.satisfaction).is_equal(51)
	assert_that(low.unmet_turns).is_equal(0)
	low = Resolver.resolve_need_turn(groups_by_id.engineers_builders, 50, 0, 0, rules)
	assert_that(low.satisfaction).is_equal(49)
	assert_that(low.unmet_turns).is_equal(1)

	var high: Dictionary = Resolver.resolve_need_turn(
		groups_by_id.alchemists_flame, 50, 0, 0, rules)
	assert_that(high.satisfaction).is_equal(50)
	assert_that(high.unmet_turns).is_equal(1)
	high = Resolver.resolve_need_turn(
		groups_by_id.alchemists_flame, high.satisfaction, high.unmet_turns, 99, rules)
	assert_that(high.satisfaction).is_equal(50)
	assert_that(high.unmet_turns).is_equal(2)
	high = Resolver.resolve_need_turn(
		groups_by_id.alchemists_flame, high.satisfaction, high.unmet_turns, 0, rules)
	assert_that(high.satisfaction).is_equal(49)
	assert_that(high.unmet_turns).is_equal(3)

func test_specialization_is_a_bounded_bonus_not_a_job_lock() -> void:
	assert_that(Resolver.specialization_bonus_bp(
		catalog, "engineering", {"engineers_builders": 2}, 3)).is_equal(2000)
	assert_that(Resolver.specialization_bonus_bp(
		catalog, "agriculture", {"engineers_builders": 2}, 3)).is_equal(0)
	assert_that(Resolver.specialization_bonus_bp(
		catalog, "alchemy", {"alchemists_flame": 2, "weavers_crafters": 2}, 3)).is_equal(3000)
	assert_that(Resolver.specialization_bonus_bp(
		catalog, "alchemy", {"alchemists_flame": 20, "weavers_crafters": 20}, 20)).is_equal(10000)

func test_compatible_tense_neutral_and_mitigated_pairs() -> void:
	var engineers := "engineers_builders"
	var traders := "merchants_diplomats"
	var weavers := "weavers_crafters"
	var alchemists := "alchemists_flame"
	assert_that(Resolver.relation_value(catalog, engineers, traders)).is_equal(2)
	assert_that(Resolver.relation_value(catalog, engineers, weavers)).is_equal(-2)
	assert_that(Resolver.relation_value(catalog, engineers, alchemists)).is_equal(0)

	var compatible := Resolver.resolve_workplace_relations(
		catalog, {engineers: 1, traders: 1})
	assert_that(compatible.deltas[engineers]).is_equal(2)
	assert_that(compatible.deltas[traders]).is_equal(2)

	var tense := Resolver.resolve_workplace_relations(
		catalog, {engineers: 1, weavers: 1})
	assert_that(tense.deltas[engineers]).is_equal(-2)
	assert_that(tense.deltas[weavers]).is_equal(-2)
	var mitigated := Resolver.resolve_workplace_relations(
		catalog, {engineers: 1, weavers: 1}, 1, [engineers, weavers])
	assert_that(mitigated.deltas[engineers]).is_equal(-1)
	assert_that(mitigated.deltas[weavers]).is_equal(-1)
	assert_that(mitigated.mediation_capacity_used).is_equal(1)

	var neutral := Resolver.resolve_workplace_relations(
		catalog, {engineers: 1, alchemists: 1})
	assert_that(neutral.deltas[engineers]).is_equal(0)
	assert_that(neutral.deltas[alchemists]).is_equal(0)

func test_identical_state_resolves_identically() -> void:
	var workers := {
		"engineers_builders": 2,
		"weavers_crafters": 1,
		"merchants_diplomats": 1,
		"hunters_trackers": 1,
	}
	var first := Resolver.resolve_workplace_relations(
		catalog, workers.duplicate(), 1, ["engineers_builders", "weavers_crafters", "merchants_diplomats"])
	var second := Resolver.resolve_workplace_relations(
		catalog, workers.duplicate(), 1, ["engineers_builders", "weavers_crafters", "merchants_diplomats"])
	assert_that(first).is_equal(second)

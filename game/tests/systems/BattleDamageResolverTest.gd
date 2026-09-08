extends GdUnitTestSuite


func _unit(stats: UnitStats, count := 5) -> BattleState.BattleUnit:
	var u := BattleState.BattleUnit.new(UnitStack.new(stats, count))
	u.max_count = count
	return u


func _seeded_rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func test_vampiric_heals_on_kill() -> void:
	var stack := UnitStack.new(UnitStats.new("vam", "Vam", 10, 5, 1, 1, 0, ["vampiric"]), 3)
	stack.count = 2
	var unit := BattleState.BattleUnit.new(stack)
	unit.max_count = 5
	var result := {"kills": 2}
	BattleDamageResolver._apply_vampiric(unit, result)
	assert_int(unit.get_count()).is_equal(4)
	assert_int(result["vampiric"]).is_equal(2)


func test_vampiric_no_heal_without_kills() -> void:
	var unit := _unit(UnitStats.new("vam", "Vam", 10, 5, 1, 1, 0, ["vampiric"]))
	var result := {"kills": 0}
	BattleDamageResolver._apply_vampiric(unit, result)
	assert_int(unit.get_count()).is_equal(5)
	assert_bool(result.has("vampiric")).is_false()


func test_vampiric_capped_at_max_count() -> void:
	var unit := _unit(UnitStats.new("vam", "Vam", 10, 5, 1, 1, 0, ["vampiric"]))
	var result := {"kills": 4}
	BattleDamageResolver._apply_vampiric(unit, result)
	assert_int(unit.get_count()).is_equal(5)


func test_resolve_dead_units_return_empty() -> void:
	var state := BattleState.new()
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 0))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 0))
	def.alive = false
	assert_dict(BattleDamageResolver.resolve(state, atk, def, {"rng": _seeded_rng(1), "is_melee": true})).is_empty()


func test_resolve_basic_shape() -> void:
	var state := BattleState.new()
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 0))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 0))
	atk.cell = Vector2i.ZERO
	def.cell = Vector2i(1, 0)
	state.attacker_units.append(atk)
	state.defender_units.append(def)
	state._rebuild_unit_grid()
	var r := BattleDamageResolver.resolve(state, atk, def, {"rng": _seeded_rng(42), "is_melee": true})
	assert_dict(r).contains_keys(["damage", "kills", "luck"])
	assert_int(r["damage"]).is_greater(0)
	assert_int(r["kills"]).is_greater_equal(1)


func _run_seeded_resolve() -> Dictionary:
	var state := BattleState.new()
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 0))
	var def := _unit(UnitStats.new("d", "D", 0, 0, 10, 1, 0))
	atk.cell = Vector2i.ZERO
	def.cell = Vector2i(1, 0)
	state.attacker_units.append(atk)
	state.defender_units.append(def)
	state._rebuild_unit_grid()
	return BattleDamageResolver.resolve(state, atk, def, {"rng": _seeded_rng(99), "is_melee": true})


func test_resolve_is_deterministic_with_seeded_rng() -> void:
	assert_dict(_run_seeded_resolve()).is_equal(_run_seeded_resolve())


func test_resolve_breath_hits_units_adjacent_to_defender() -> void:
	var state := BattleState.new()
	var atk := _unit(UnitStats.new("dr", "Drake", 10, 5, 1, 1, 0, ["breath"]))
	var def := _unit(UnitStats.new("d1", "D1", 0, 0, 10, 1, 0))
	var ally := _unit(UnitStats.new("d2", "D2", 0, 0, 10, 1, 0))
	atk.cell = Vector2i.ZERO
	def.cell = Vector2i(1, 0)
	ally.cell = Vector2i(0, 1)
	state.attacker_units.append(atk)
	state.defender_units.append(def)
	state.defender_units.append(ally)
	state._rebuild_unit_grid()
	var r := BattleDamageResolver.resolve(state, atk, def, {"rng": _seeded_rng(11), "is_melee": true})
	assert_int(r.get("breath_kills", 0)).is_greater_equal(1)
	assert_int(ally.get_count()).is_less_equal(4)

extends BaseTest
## Phase 6 (tactical-battle-system): фланговые атаки.
##
## Покрывает:
##   * классификацию аспекта (фронт/фланг/тыл) по направлению атаки к facing,
##   * установку facing при размещении (attacker→0 east, defender→3 west),
##   * бонус тыла: -50% защиты (через damage_multiplier) + шанс крита,
##   * крит фланга/тыла (флаг result["crit"], удвоение урона константой),
##   * сквозную интеграцию через BattleDamageResolver.
##
## Геометрия: бит соседства = угол/60° против часовой (0=E,1=NE,2=NW,3=W,4=SW,5=SE).
## Фронт = facing, фланг = ±60° (2 гекса), тыл = ±120°..180° (3 гекса).

const _SR := true  # совпадает с BattleState.hex_shift_right (default)

func _st() -> BattleState:
	return BattleState.new()

func _def_at(cell: Vector2i, facing: int) -> BattleState.BattleUnit:
	var d := TestFactories.make_battle_unit_raw("d", 10, BattleState.Side.DEFENDER)
	d.cell = cell
	d.facing = facing
	return d

func _make_state(atk_key: String, def_key: String, atk_count: int, def_count: int) -> BattleState:
	var state := BattleState.new()
	var atk: Array[UnitStack] = [Units.make_fixed_stack(atk_key, atk_count)]
	var def: Array[UnitStack] = [Units.make_fixed_stack(def_key, def_count)]
	state.place_army(atk, def)
	return state

# --- Facing при размещении ---

func test_facing_set_on_placement() -> void:
	var s := _make_state("swordsmen", "goblins", 20, 20)
	for u in s.get_units_by_side(BattleState.Side.ATTACKER):
		assert_int(u.facing).is_equal(0).override_failure_message("attacker must face east (bit 0)")
	for u in s.get_units_by_side(BattleState.Side.DEFENDER):
		assert_int(u.facing).is_equal(3).override_failure_message("defender must face west (bit 3)")

# --- Классификация аспекта (facing = 0, восток) ---

func test_aspect_front_facing_east() -> void:
	var st := _st()
	var d := _def_at(Vector2i(8, 5), 0)
	assert_int(st.attack_aspect(HexUtils.get_neighbor(d.cell, 0, _SR), d)).is_equal(0)

func test_aspect_flank_facing_east() -> void:
	var st := _st()
	var d := _def_at(Vector2i(8, 5), 0)
	assert_int(st.attack_aspect(HexUtils.get_neighbor(d.cell, 1, _SR), d)).is_equal(1)  # NE
	assert_int(st.attack_aspect(HexUtils.get_neighbor(d.cell, 5, _SR), d)).is_equal(1)  # SE

func test_aspect_rear_facing_east() -> void:
	var st := _st()
	var d := _def_at(Vector2i(8, 5), 0)
	assert_int(st.attack_aspect(HexUtils.get_neighbor(d.cell, 2, _SR), d)).is_equal(2)  # NW
	assert_int(st.attack_aspect(HexUtils.get_neighbor(d.cell, 3, _SR), d)).is_equal(2)  # W
	assert_int(st.attack_aspect(HexUtils.get_neighbor(d.cell, 4, _SR), d)).is_equal(2)  # SW

func test_aspect_not_adjacent() -> void:
	var st := _st()
	var d := _def_at(Vector2i(8, 5), 0)
	assert_int(st.attack_aspect(d.cell, d)).is_equal(-1)  # тот же гекс, не сосед
	assert_int(st.attack_aspect(Vector2i(15, 5), d)).is_equal(-1)  # далеко

func test_aspect_full_arc_facing_west() -> void:
	var st := _st()
	var d := _def_at(Vector2i(8, 5), 3)  # вест (default для defender)
	# Полный круг: фронт=3, фланг={2,4}, тыл={0,1,5}
	assert_int(st.attack_aspect(HexUtils.get_neighbor(d.cell, 3, _SR), d)).is_equal(0)  # W
	assert_int(st.attack_aspect(HexUtils.get_neighbor(d.cell, 2, _SR), d)).is_equal(1)  # NW
	assert_int(st.attack_aspect(HexUtils.get_neighbor(d.cell, 4, _SR), d)).is_equal(1)  # SW
	assert_int(st.attack_aspect(HexUtils.get_neighbor(d.cell, 0, _SR), d)).is_equal(2)  # E
	assert_int(st.attack_aspect(HexUtils.get_neighbor(d.cell, 1, _SR), d)).is_equal(2)  # NE
	assert_int(st.attack_aspect(HexUtils.get_neighbor(d.cell, 5, _SR), d)).is_equal(2)  # SE

## T17/D2: лестница перевеса (02d v1.2). Фланг/тыл = преимущество (+2 к
## перевесу); тыл дополнительно режет защиту ×0.5. Критов/ГСЧ нет —
## Триумф (перевес ≥ 4) = удвоенный урон.

func test_front_has_no_advantage_margin() -> void:
	var atk = TestFactories.make_battle_unit_raw("a", 10, BattleState.Side.ATTACKER)
	var def = TestFactories.make_battle_unit_raw("d", 10, BattleState.Side.DEFENDER)
	var base: int = BattleRules.margin_of(atk, def, 0, 0, 1.0, 1.0, 0)
	assert_int(base).is_equal(atk.get_attack() - def.get_defense())

func test_flank_gives_advantage_margin() -> void:
	var atk = TestFactories.make_battle_unit_raw("a", 10, BattleState.Side.ATTACKER)
	var def = TestFactories.make_battle_unit_raw("d", 10, BattleState.Side.DEFENDER)
	var base: int = BattleRules.margin_of(atk, def, 0, 0, 1.0, 1.0, 0)
	var flank: int = BattleRules.margin_of(atk, def, 0, 0, 1.0, 1.0, 1)
	assert_int(flank).is_equal(base + GameNumbersBattle.ADVANTAGE_MARGIN)

func test_rear_halves_defense_and_gives_advantage() -> void:
	var atk = TestFactories.make_battle_unit_raw("a", 10, BattleState.Side.ATTACKER)
	var def = TestFactories.make_battle_unit_raw("d", 10, BattleState.Side.DEFENDER)
	var base: int = BattleRules.margin_of(atk, def, 0, 0, 1.0, 1.0, 0)
	var rear: int = BattleRules.margin_of(atk, def, 0, 0, 1.0, 1.0, 2)
	var expected: int = int(round(float(atk.get_attack()) - float(def.get_defense()) * GameNumbers.REAR_DEFENSE_MULT)) \
		+ GameNumbersBattle.ADVANTAGE_MARGIN
	assert_int(rear).is_equal(expected)
	assert_int(rear).is_greater(base)

func test_triumph_doubles_damage() -> void:
	var atk = TestFactories.make_battle_unit_raw("a", 10, BattleState.Side.ATTACKER)
	var def = TestFactories.make_battle_unit_raw("d", 10, BattleState.Side.DEFENDER)
	# Фронт: перевес 5−3=2 → Успех (базовый урон).
	var front: Dictionary = BattleRules.calculate_attack(atk, def, true, 0, 0, 1.0, 1.0, 0)
	assert_that(front.get("zone")).is_equal(BattleRules.ZONE_SUCCESS)
	# Фланг: перевес 4 → Триумф (урон ×2).
	var flank: Dictionary = BattleRules.calculate_attack(atk, def, true, 0, 0, 1.0, 1.0, 1)
	assert_that(flank.get("zone")).is_equal(BattleRules.ZONE_TRIUMPH)
	assert_int(int(flank["damage"])).is_equal(int(front["damage"]) * 2)

# --- Сквозная интеграция через resolver ---

func test_resolver_wires_rear_aspect() -> void:
	var s := _make_state("swordsmen", "goblins", 20, 5)
	var a = s.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var d = s.get_units_by_side(BattleState.Side.DEFENDER)[0]
	d.cell = Vector2i(10, 5)
	a.cell = HexUtils.get_neighbor(d.cell, 0, _SR)  # восток = тыл (defender смотрит на запад)
	assert_int(s.attack_aspect(a.cell, d)).is_equal(2)
	var res: Dictionary = BattleDamageResolver.resolve(s, a, d, {"is_melee": true, "atk_bonus": 0, "def_bonus": 0})
	assert_bool(res.has("margin")).is_true().override_failure_message("resolver result must carry the ladder margin")
	assert_int(int(res["margin"])).is_greater(0)

func test_resolver_front_attack_margin() -> void:
	var s := _make_state("swordsmen", "goblins", 20, 5)
	var a = s.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var d = s.get_units_by_side(BattleState.Side.DEFENDER)[0]
	d.cell = Vector2i(10, 5)
	d.facade = d.cell + Vector2i(-1, 0)  # фасад на запад (после переноса клетки)
	a.cell = HexUtils.get_neighbor(d.cell, 3, _SR)  # запад = фронт (defender смотрит на запад)
	assert_int(BattleFlanking.classify(s, a, d)).is_equal(BattleFlanking.Position.FRONT)
	var res: Dictionary = BattleDamageResolver.resolve(s, a, d, {"is_melee": true, "atk_bonus": 0, "def_bonus": 0})
	# Фронт: без преимущества (+2) — перевес равен атаке минус защита.
	assert_int(int(res["margin"])) \
		.is_equal(int(a.get_attack()) - int(d.get_defense()))

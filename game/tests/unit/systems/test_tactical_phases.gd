extends BaseTest
## tactical-combat-implementation, фазы 4–7: дальний бой (LOS/дальность/листва),
## фланги/тыл, ИИ-доктрина, ранения героя.


func _make_unit(key: String, attack: int, hp: int, speed: int, defense: int, side: int, tags: Array = []) -> BattleState.BattleUnit:
	var stats := UnitStats.new(key, key, attack, attack, hp, speed, defense, tags)
	var stack := UnitStack.new(stats, 10)
	var u := BattleState.BattleUnit.new(stack)
	u.side = side
	u.max_count = 10
	return u

# ═══════════════════════════════════════════
#  ФАЗА 4: ДАЛЬНИЙ БОЙ
# ═══════════════════════════════════════════

func test_ranged_max_range() -> void:
	var state := BattleState.new()
	var archer := _make_unit("archer", 4, 30, 6, 2, BattleState.Side.ATTACKER, ["ranged"])
	archer.cell = Vector2i(2, 5)
	var target := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.DEFENDER)
	target.cell = Vector2i(5, 5)  # dist 3
	state.attacker_units.append(archer)
	state.defender_units.append(target)
	state.invalidate_board_cache()

	assert_bool(BattleLineOfSight.can_target_ranged(state, archer.cell, target)).is_true() \
			.override_failure_message("range 3 must be targetable")
	target.cell = Vector2i(6, 5)  # dist 4
	state.invalidate_board_cache()
	assert_bool(BattleLineOfSight.can_target_ranged(state, archer.cell, target)).is_true() \
			.override_failure_message("range 4 (max) must be targetable")
	target.cell = Vector2i(7, 5)  # dist 5
	state.invalidate_board_cache()
	assert_bool(BattleLineOfSight.can_target_ranged(state, archer.cell, target)).is_false() \
			.override_failure_message("range 5 exceeds RANGED_MAX_RANGE")


func test_ranged_forest_canopy_hides_target() -> void:
	var state := BattleState.new()
	var archer := _make_unit("archer", 4, 30, 6, 2, BattleState.Side.ATTACKER, ["ranged"])
	archer.cell = Vector2i(2, 5)
	var target := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.DEFENDER)
	target.cell = Vector2i(5, 5)  # dist 3
	state.attacker_units.append(archer)
	state.defender_units.append(target)
	state.set_battle_terrain({target.cell: BattleTerrain.FOREST})

	assert_bool(BattleLineOfSight.can_target_ranged(state, archer.cell, target)).is_false() \
			.override_failure_message("canopy cover must hide target at dist > 1")


func test_ranged_los_blocked_by_hill() -> void:
	var state := BattleState.new()
	var archer := _make_unit("archer", 4, 30, 6, 2, BattleState.Side.ATTACKER, ["ranged"])
	archer.cell = Vector2i(2, 5)
	var target := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.DEFENDER)
	target.cell = Vector2i(6, 5)  # dist 4
	var hill := Vector2i(4, 5)
	state.attacker_units.append(archer)
	state.defender_units.append(target)
	state.set_battle_terrain({hill: BattleTerrain.HILL})

	assert_bool(BattleLineOfSight.has_line_of_sight(state, archer.cell, target.cell)).is_false() \
			.override_failure_message("hill between shooter and target must block LOS")
	assert_bool(BattleLineOfSight.can_target_ranged(state, archer.cell, target)).is_false() \
			.override_failure_message("no_los must reject the shot")


func test_ranged_los_empty_board_clear() -> void:
	var state := BattleState.new()
	var archer := _make_unit("archer", 4, 30, 6, 2, BattleState.Side.ATTACKER, ["ranged"])
	archer.cell = Vector2i(2, 5)
	var target := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.DEFENDER)
	target.cell = Vector2i(6, 5)
	state.attacker_units.append(archer)
	state.defender_units.append(target)

	assert_bool(BattleLineOfSight.has_line_of_sight(state, archer.cell, target.cell)).is_true() \
			.override_failure_message("empty board must have clear LOS")


func test_distance_penalty_reduces_damage() -> void:
	# Статистика: 200 выстрелов на дистанции 2 vs 4 — средний урон ниже на 4.
	var state := BattleState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var dmg_near := 0
	var dmg_far := 0
	for i in 200:
		var archer := _make_unit("archer", 4, 30, 6, 2, BattleState.Side.ATTACKER, ["ranged"])
		archer.cell = Vector2i(2, 5)
		var target := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.DEFENDER)
		target.cell = Vector2i(4, 5) if i % 2 == 0 else Vector2i(6, 5)
		state.attacker_units = [archer]
		state.defender_units = [target]
		state.invalidate_board_cache()
		var ctx := {"is_melee": false, "rng": rng, "atk_bonus": 0, "def_bonus": 0,
				"range": HexUtils.hex_distance(archer.cell, target.cell, state.hex_shift_right)}
		var res: Dictionary = BattleDamageResolver.resolve(state, archer, target, ctx)
		if i % 2 == 0:
			dmg_near += int(res.get("damage", 0))
		else:
			dmg_far += int(res.get("damage", 0))

	assert_int(dmg_far).is_less(dmg_near) \
			.override_failure_message("distance penalty must reduce average damage")

# ═══════════════════════════════════════════
#  ФАЗА 5: ФЛАНГИ / ТЫЛ
# ═══════════════════════════════════════════

func test_flanking_front() -> void:
	var state := BattleState.new()
	var defender := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.DEFENDER)
	defender.cell = Vector2i(8, 5)
	defender.facade = Vector2i(7, 5)  # смотрит влево
	var attacker := _make_unit("swordsmen", 5, 50, 5, 4, BattleState.Side.ATTACKER)
	attacker.cell = Vector2i(7, 5)  # передняя клетка
	state.attacker_units.append(attacker)
	state.defender_units.append(defender)
	state.invalidate_board_cache()

	assert_int(BattleFlanking.classify(state, attacker, defender)).is_equal(BattleFlanking.Position.FRONT)


func test_flanking_rear() -> void:
	var state := BattleState.new()
	var defender := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.DEFENDER)
	defender.cell = Vector2i(8, 5)
	defender.facade = Vector2i(7, 5)  # смотрит влево
	var attacker := _make_unit("swordsmen", 5, 50, 5, 4, BattleState.Side.ATTACKER)
	attacker.cell = Vector2i(9, 5)  # тыльная клетка
	state.attacker_units.append(attacker)
	state.defender_units.append(defender)
	state.invalidate_board_cache()

	assert_int(BattleFlanking.classify(state, attacker, defender)).is_equal(BattleFlanking.Position.REAR)


func test_flanking_flank() -> void:
	var state := BattleState.new()
	var defender := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.DEFENDER)
	defender.cell = Vector2i(8, 5)
	defender.facade = Vector2i(7, 5)  # смотрит влево
	var attacker := _make_unit("swordsmen", 5, 50, 5, 4, BattleState.Side.ATTACKER)
	attacker.cell = Vector2i(8, 4)  # боковая клетка
	state.attacker_units.append(attacker)
	state.defender_units.append(defender)
	state.invalidate_board_cache()

	assert_int(BattleFlanking.classify(state, attacker, defender)).is_equal(BattleFlanking.Position.FLANK)


func test_flanking_uninit_facing_is_front() -> void:
	var state := BattleState.new()
	var defender := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.DEFENDER)
	defender.cell = Vector2i(8, 5)
	# facing = (-1,-1) — тестовый юнит без инициализации
	var attacker := _make_unit("swordsmen", 5, 50, 5, 4, BattleState.Side.ATTACKER)
	attacker.cell = Vector2i(9, 5)
	state.attacker_units.append(attacker)
	state.defender_units.append(defender)
	state.invalidate_board_cache()

	assert_int(BattleFlanking.classify(state, attacker, defender)).is_equal(BattleFlanking.Position.FRONT) \
			.override_failure_message("uninitialized facing must classify as FRONT (no phantom rear)")


func test_flanking_bonus_tables() -> void:
	assert_float(BattleFlanking.luck_bonus(BattleFlanking.Position.FLANK)).is_equal(GameNumbersBattle.FLANK_CRIT_BONUS)
	assert_float(BattleFlanking.luck_bonus(BattleFlanking.Position.REAR)).is_equal(GameNumbersBattle.REAR_CRIT_BONUS)
	assert_float(BattleFlanking.luck_bonus(BattleFlanking.Position.FRONT)).is_equal(0.0)
	assert_float(BattleFlanking.defense_ignore(BattleFlanking.Position.REAR)).is_equal(GameNumbersBattle.REAR_DEF_IGNORE)
	assert_float(BattleFlanking.defense_ignore(BattleFlanking.Position.FLANK)).is_equal(0.0)


func test_rear_attack_ignores_half_defense() -> void:
	# Тыл: игнор 50% защиты. Сравниваем урон фронт/тыл на одном seed.
	var rng_front := RandomNumberGenerator.new()
	rng_front.seed = 7
	var rng_rear := RandomNumberGenerator.new()
	rng_rear.seed = 7

	var state := BattleState.new()
	var defender := _make_unit("militia", 4, 40, 5, 10, BattleState.Side.DEFENDER)
	defender.cell = Vector2i(8, 5)
	defender.facade = Vector2i(7, 5)
	var attacker_front := _make_unit("swordsmen", 8, 50, 5, 4, BattleState.Side.ATTACKER)
	attacker_front.cell = Vector2i(7, 5)
	state.attacker_units = [attacker_front]
	state.defender_units = [defender]
	state.invalidate_board_cache()
	var ctx_front := {"is_melee": true, "rng": rng_front, "atk_bonus": 0, "def_bonus": 0, "range": 1}
	var res_front: Dictionary = BattleDamageResolver.resolve(state, attacker_front, defender, ctx_front)

	var attacker_rear := _make_unit("swordsmen", 8, 50, 5, 4, BattleState.Side.ATTACKER)
	attacker_rear.cell = Vector2i(9, 5)
	state.attacker_units = [attacker_rear]
	state.defender_units = [defender]
	state.invalidate_board_cache()
	var ctx_rear := {"is_melee": true, "rng": rng_rear, "atk_bonus": 0, "def_bonus": 0, "range": 1}
	var res_rear: Dictionary = BattleDamageResolver.resolve(state, attacker_rear, defender, ctx_rear)

	assert_int(int(res_rear.get("flank", 0))).is_equal(BattleFlanking.Position.REAR)
	assert_int(int(res_rear.get("damage", 0))).is_greater(int(res_front.get("damage", 0))) \
			.override_failure_message("rear attack must deal more damage (50% defense ignored)")


func test_facing_updated_on_move() -> void:
	var state := BattleState.new()
	var u := _make_unit("militia", 4, 40, 5, 3, BattleState.Side.ATTACKER)
	u.cell = Vector2i(2, 5)
	u.facade = Vector2i(3, 5)
	state.attacker_units.append(u)
	state.invalidate_board_cache()

	BattleActionResolver.do_move(state, u, Vector2i(4, 5))
	assert_that(u.facade).is_equal(Vector2i(5, 5)) \
			.override_failure_message("do_move must update facing along the movement direction")

# ═══════════════════════════════════════════
#  ФАЗА 6: ИИ-ДОКТРИНА
# ═══════════════════════════════════════════

func test_ai_targets_threat_first() -> void:
	# Дальнобойный враг, способный выстрелить (угроза), приоритетнее раненого.
	var state := BattleState.new()
	var me := _make_unit("swordsmen", 5, 50, 5, 4, BattleState.Side.ATTACKER)
	me.cell = Vector2i(8, 5)
	var archer := _make_unit("archer", 4, 30, 6, 2, BattleState.Side.DEFENDER, ["ranged"])
	archer.cell = Vector2i(11, 5)  # dist 3 — может выстрелить
	var wounded := _make_unit("goblins", 3, 20, 4, 1, BattleState.Side.DEFENDER)
	wounded.cell = Vector2i(10, 5)
	wounded.set_count(2)  # 20% стека — ранен
	state.attacker_units.append(me)
	state.defender_units.append(archer)
	state.defender_units.append(wounded)
	state.invalidate_board_cache()

	var ai := BattleAI.new()
	var blocked: Dictionary = state.build_all_blocked(me, {})
	var decision := ai.decide_turn(me, state, blocked)

	assert_that(decision.attack_target == archer or decision.move_victim == archer or \
			(decision.action == BattleAI.Action.MOVE and _moves_toward(decision, archer, state))) \
			.is_true().override_failure_message("AI must prioritize the ranged threat over the wounded goblin")


func test_ai_targets_wounded_before_full() -> void:
	# Без угроз: раненый (<30%) приоритетнее полного стека.
	var state := BattleState.new()
	var me := _make_unit("swordsmen", 5, 50, 5, 4, BattleState.Side.ATTACKER)
	me.cell = Vector2i(8, 5)
	var wounded := _make_unit("goblins", 3, 20, 4, 1, BattleState.Side.DEFENDER)
	wounded.cell = Vector2i(12, 5)
	wounded.set_count(2)  # 20%
	var full := _make_unit("orcs", 4, 30, 5, 2, BattleState.Side.DEFENDER)
	full.cell = Vector2i(10, 5)
	state.attacker_units.append(me)
	state.defender_units.append(wounded)
	state.defender_units.append(full)
	state.invalidate_board_cache()

	var ai := BattleAI.new()
	var blocked: Dictionary = state.build_all_blocked(me, {})
	var decision := ai.decide_turn(me, state, blocked)

	assert_that(decision.attack_target == wounded or decision.move_victim == wounded or \
			(decision.action == BattleAI.Action.MOVE and _moves_toward(decision, wounded, state))) \
			.is_true().override_failure_message("AI must focus the wounded (<30%) before the full stack")


func test_ai_animal_targets_nearest() -> void:
	# Животные: всегда ближайший, без приоритетов.
	var state := BattleState.new()
	var wolf := _make_unit("wolves", 4, 30, 6, 2, BattleState.Side.ATTACKER)
	wolf.cell = Vector2i(8, 5)
	var far_wounded := _make_unit("goblins", 3, 20, 4, 1, BattleState.Side.DEFENDER)
	far_wounded.cell = Vector2i(14, 5)
	far_wounded.set_count(1)  # 10% — ранен
	var near_full := _make_unit("orcs", 4, 30, 5, 2, BattleState.Side.DEFENDER)
	near_full.cell = Vector2i(12, 5)
	state.attacker_units.append(wolf)
	state.defender_units.append(far_wounded)
	state.defender_units.append(near_full)
	state.invalidate_board_cache()

	var ai := BattleAI.new()
	var blocked: Dictionary = state.build_all_blocked(wolf, {})
	var decision := ai.decide_turn(wolf, state, blocked)

	assert_that(decision.attack_target == near_full or decision.move_victim == near_full or \
			(decision.action == BattleAI.Action.MOVE and _moves_toward(decision, near_full, state))) \
			.is_true().override_failure_message("animal AI must chase the nearest enemy, not the wounded")


func test_ai_tactical_retreats_at_70_percent_losses() -> void:
	var state := BattleState.new()
	var me := _make_unit("swordsmen", 5, 50, 5, 4, BattleState.Side.ATTACKER)
	me.cell = Vector2i(8, 5)
	me.max_count = 10
	me.set_count(2)  # 80% потерь
	var enemy := _make_unit("orcs", 4, 30, 5, 2, BattleState.Side.DEFENDER)
	enemy.cell = Vector2i(12, 5)
	state.attacker_units.append(me)
	state.defender_units.append(enemy)
	state.invalidate_board_cache()

	var ai := BattleAI.new()
	var blocked: Dictionary = state.build_all_blocked(me, {})
	var decision := ai.decide_turn(me, state, blocked)

	assert_int(decision.action).is_equal(BattleAI.Action.RETREAT) \
			.override_failure_message("tactical unit must retreat at >70% losses")


func test_ai_monster_does_not_retreat() -> void:
	var state := BattleState.new()
	var troll := _make_unit("troll", 6, 80, 4, 4, BattleState.Side.ATTACKER)
	troll.cell = Vector2i(8, 5)
	troll.max_count = 10
	troll.set_count(1)  # 90% потерь
	var enemy := _make_unit("orcs", 4, 30, 5, 2, BattleState.Side.DEFENDER)
	enemy.cell = Vector2i(12, 5)
	state.attacker_units.append(troll)
	state.defender_units.append(enemy)
	state.invalidate_board_cache()

	var ai := BattleAI.new()
	var blocked: Dictionary = state.build_all_blocked(troll, {})
	var decision := ai.decide_turn(troll, state, blocked)

	assert_int(decision.action).is_not_equal(BattleAI.Action.RETREAT) \
			.override_failure_message("monster AI must ignore losses and keep fighting")


func test_ai_animal_does_not_retreat() -> void:
	var state := BattleState.new()
	var wolf := _make_unit("wolves", 4, 30, 6, 2, BattleState.Side.ATTACKER)
	wolf.cell = Vector2i(8, 5)
	wolf.max_count = 10
	wolf.set_count(1)  # 90% потерь
	var enemy := _make_unit("orcs", 4, 30, 5, 2, BattleState.Side.DEFENDER)
	enemy.cell = Vector2i(12, 5)
	state.attacker_units.append(wolf)
	state.defender_units.append(enemy)
	state.invalidate_board_cache()

	var ai := BattleAI.new()
	var blocked: Dictionary = state.build_all_blocked(wolf, {})
	var decision := ai.decide_turn(wolf, state, blocked)

	assert_int(decision.action).is_not_equal(BattleAI.Action.RETREAT) \
			.override_failure_message("animal AI must not retreat")


func _moves_toward(decision, target: BattleState.BattleUnit, state: BattleState) -> bool:
	if decision.target_cell == Vector2i(-1, -1) or decision.move_path.is_empty():
		return false
	var start: Vector2i = decision.move_path[0]
	return HexUtils.hex_distance(decision.target_cell, target.cell, state.hex_shift_right) \
			< HexUtils.hex_distance(start, target.cell, state.hex_shift_right)

func test_emulator_retaliation_once_per_battle() -> void:
	# Эмулятор повторяет игровую контратаку: выживший мяской защитник
	# контратакует один раз за бой (has_retaliated). Состав как в
	# winrate_baseline (высокий HP — бои длятся несколько ходов).
	var emu: RefCounted = load("res://scripts/autoload/battle_emulator.gd").new()
	var spec: Array = [
		{"id": "militia", "name": "Militia", "attack": 4, "base_damage": 4, "hp": 40, "speed": 5, "defense": 3, "count": 12},
		{"id": "heavy", "name": "Heavy", "attack": 5, "base_damage": 6, "hp": 70, "speed": 4, "defense": 5, "count": 4},
	]
	var atk: Array[UnitStack] = []
	var def: Array[UnitStack] = []
	for s in spec:
		atk.append(emu.army_stack(s.duplicate(true)) as UnitStack)
		def.append(emu.army_stack(s.duplicate(true)) as UnitStack)
	var state := BattleState.new()
	state.place_army(atk, def)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var report: Dictionary = emu.run_auto_battle(state)
	var retaliations := 0
	for e in report.get("events", []):
		if str(e.get("action", "")) == "retaliation":
			retaliations += 1
	assert_int(retaliations).is_greater_equal(1) \
		.override_failure_message("melee mirror must produce at least one retaliation")
	# Контратака не более чем у каждого юнита один раз (2 юнита на сторону).
	assert_int(retaliations).is_less_equal(4) \
		.override_failure_message("retaliation must be at most once per unit per battle")


# ═══════════════════════════════════════════
#  ФАЗА 7.2: РАНЕНИЯ ГЕРОЯ
# ═══════════════════════════════════════════

var _hero: HeroController

func _before_wound_tests() -> void:
	_hero = HeroController.new()
	_hero.name = "WoundTestHero"
	add_child(_hero)

func _after_wound_tests() -> void:
	if is_instance_valid(_hero):
		_hero.free()
	_hero = null

func test_wounded_apply_sets_scar_and_turns() -> void:
	_before_wound_tests()
	_hero.combat_comp.max_combat_hp = 100
	_hero.apply_wounded(5, 30)
	assert_int(_hero.combat_comp.hp_scar).is_equal(30)
	assert_int(_hero.combat_comp.wounded_turns).is_equal(5)
	assert_bool(_hero.combat_comp.is_wounded()).is_true()
	_after_wound_tests()


func test_wounded_tick_and_heal() -> void:
	_before_wound_tests()
	_hero.combat_comp.max_combat_hp = 100
	_hero.apply_wounded(2, 40)
	assert_int(_hero.combat_comp.max_combat_hp).is_equal(60)
	_hero.end_turn()  # тик 2→1
	assert_int(_hero.combat_comp.wounded_turns).is_equal(1)
	_hero.end_turn()  # тик 1→0, лечение
	assert_int(_hero.combat_comp.wounded_turns).is_equal(0)
	assert_bool(_hero.combat_comp.is_wounded()).is_false()
	assert_int(_hero.combat_comp.max_combat_hp).is_equal(100) \
		.override_failure_message("healing must restore max HP after wound ends")
	assert_int(_hero.combat_comp.hp_scar).is_equal(0)
	_after_wound_tests()


func test_wounded_battle_bonus_penalty() -> void:
	_before_wound_tests()
	_hero.combat_comp.max_combat_hp = 100
	_hero.apply_wounded(3, 20)
	var bonus: Dictionary = _hero.get_battle_bonus()
	var base_attack: int = _hero.stats_comp.stats.get("attack", 0)
	var expected: int = int(round(float(base_attack) * (1.0 - GameNumbersHero.WOUNDED_STAT_PENALTY)))
	assert_int(int(bonus.get("attack", -1))).is_equal(expected) \
		.override_failure_message("wounded hero must have -25% attack")
	_after_wound_tests()


func test_wounded_serialize_roundtrip() -> void:
	_before_wound_tests()
	_hero.combat_comp.max_combat_hp = 100
	_hero.apply_wounded(4, 25)
	var data: Dictionary = _hero.serialize()
	assert_int(int(data.get("wounded_turns", -1))).is_equal(4)
	assert_int(int(data.get("hp_scar", -1))).is_equal(25)

	var hero2 := HeroController.new()
	add_child(hero2)
	hero2.deserialize(data)
	assert_int(hero2.combat_comp.wounded_turns).is_equal(4)
	assert_int(hero2.combat_comp.hp_scar).is_equal(25)
	hero2.free()
	_after_wound_tests()


func test_wounded_legacy_save_not_wounded() -> void:
	_before_wound_tests()
	_hero.combat_comp.max_combat_hp = 100
	var data: Dictionary = _hero.serialize()
	data.erase("wounded_turns")
	data.erase("hp_scar")

	var hero2 := HeroController.new()
	add_child(hero2)
	hero2.deserialize(data)
	assert_bool(hero2.combat_comp.is_wounded()).is_false() \
		.override_failure_message("legacy save without wound keys must load as not wounded")
	assert_int(hero2.combat_comp.max_combat_hp).is_equal(100)
	hero2.free()
	_after_wound_tests()

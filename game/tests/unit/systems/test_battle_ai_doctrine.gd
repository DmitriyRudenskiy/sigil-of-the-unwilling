extends BaseTest

# Фаза 7 — доктрина ИИ (tactical-battle-system).
# Проверяет сценарии spec «Поведение ИИ в автобитвах»:
#   приоритет угроз (сильные/близкие → раненые <30%), укрытия под огнём,
#   отступление гуманоидов при потере >70%, монстры/животные не отступают.
# С одним врагом поведение не меняется — это покрывает test_battle_ai.gd.

const ACTION_SKIP := 0
const ACTION_MOVE := 1
const ACTION_ATTACK := 2

const T := preload("res://scripts/systems/BattleTerrain.gd")


func _mk_state(attacker_key: String, defender_keys: Array) -> BattleState:
	var state := BattleState.new()
	var atk: Array[UnitStack] = []
	atk.append(Units.make_fixed_stack(attacker_key, 10))
	var def: Array[UnitStack] = []
	for k in defender_keys:
		def.append(Units.make_fixed_stack(k, 10))
	state.place_army(atk, def)
	state.build_queue()
	return state


# --- Приоритет угроз: при равной дистанции/здоровье бьём по сильнейшему ---

func test_target_priority_threat() -> void:
	var state := _mk_state("swordsmen", ["champions", "goblins"])
	var ai: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defs: Array[BattleState.BattleUnit] = state.get_units_by_side(BattleState.Side.DEFENDER)
	var champions: BattleState.BattleUnit = null
	var goblins: BattleState.BattleUnit = null
	for d in defs:
		if d.get_key() == "champions":
			champions = d
		elif d.get_key() == "goblins":
			goblins = d
	assert_bool(champions != null and goblins != null).is_true().override_failure_message("setup: both enemy types must exist")

	ai.cell = Vector2i(5, 5)
	champions.cell = Vector2i(5, 8)  # снизу
	goblins.cell = Vector2i(5, 2)    # сверху
	state._rebuild_unit_grid()

	# обе цели на одной дистанции — приоритет только по силе атаки
	assert_int(HexUtils.hex_distance(ai.cell, champions.cell, true)).is_equal(HexUtils.hex_distance(ai.cell, goblins.cell, true))

	var blocked: Dictionary = state.build_all_blocked(ai, {})
	var decision := BattleAI.new().decide_turn(ai, state, blocked)

	assert_int(decision.action).is_equal(ACTION_MOVE)
	# цель — champions (сильнее), снизу → движемся вниз (y растёт)
	assert_int(decision.target_cell.y).is_greater(ai.cell.y).override_failure_message("AI should move toward the higher-attack enemy (champions, below)")


# --- Приоритет раненых + концентрация огня: добиваем цель <30% ---

func test_target_priority_wounded() -> void:
	var state := _mk_state("swordsmen", ["goblins", "goblins"])
	var ai: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var defs: Array[BattleState.BattleUnit] = state.get_units_by_side(BattleState.Side.DEFENDER)
	var g_wounded: BattleState.BattleUnit = defs[0]
	var g_healthy: BattleState.BattleUnit = defs[1]

	g_wounded.set_count(2)  # 2/10 = 20% < 30%
	ai.cell = Vector2i(5, 5)
	g_wounded.cell = Vector2i(5, 2)   # сверху
	g_healthy.cell = Vector2i(5, 8)   # снизу
	state._rebuild_unit_grid()

	assert_int(g_wounded.get_count()).is_equal(2).override_failure_message("setup: wounded count")
	var blocked: Dictionary = state.build_all_blocked(ai, {})
	var decision := BattleAI.new().decide_turn(ai, state, blocked)

	assert_int(decision.action).is_equal(ACTION_MOVE)
	# цель — раненый (сверху) → движемся вверх (y убывает)
	assert_int(decision.target_cell.y).is_less(ai.cell.y).override_failure_message("AI should focus fire on the wounded (<30%) enemy (above)")


# --- Укрытия: под огнём (есть дальний враг) предпочитаем клетку с бонусом защиты ---

func test_cover_prefers_fort_under_fire() -> void:
	var state := _mk_state("swordsmen", ["archers"])
	var ai: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var archer: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	ai.cell = Vector2i(5, 5)
	archer.cell = Vector2i(10, 5)
	state._rebuild_unit_grid()

	var path: Array[Vector2i] = [
		Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5),
		Vector2i(8, 5), Vector2i(9, 5), Vector2i(10, 5),
	]
	var logic := BattleAI.new()

	# Контроль: без укрытий — по умолчанию ближайшая к цели (steps=2 → path[2])
	assert_int(logic._pick_landing_cell(ai, state, BattleState.Side.DEFENDER, path, 2)).is_equal(2)

	# FORT на path[1]; под огнём (ranged archer) → откатываемся на FORT
	state.set_terrain(Vector2i(6, 5), T.TerrainType.FORT)
	var idx: int = logic._pick_landing_cell(ai, state, BattleState.Side.DEFENDER, path, 2)
	assert_int(idx).is_equal(1).override_failure_message("under fire AI should stop on the FORT hex, not the open one")
	assert_int(state.get_hex_terrain(path[idx])).is_equal(T.TerrainType.FORT)


# --- Отступление: гуманоид при потере >70% уходит к краю (от врага) ---

func test_retreat_humanoid_when_losing() -> void:
	var state := _mk_state("swordsmen", ["goblins"])
	var ai: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var goblin: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	ai.cell = Vector2i(13, 5)
	goblin.cell = Vector2i(1, 5)   # враг слева
	ai.set_count(2)                # 20% армии
	state._rebuild_unit_grid()

	var blocked: Dictionary = state.build_all_blocked(ai, {})
	var decision := BattleAI.new().decide_turn(ai, state, blocked)

	assert_int(decision.action).is_equal(ACTION_MOVE)
	# ближайший край — (16,5) справа; отступаем вправо, ОТ врага (x растёт)
	assert_int(decision.target_cell.x).is_greater(ai.cell.x).override_failure_message("humanoid should retreat toward the far edge, away from the enemy")


# --- Монстры игнорируют потери: при том же 20% НЕ отступают, идут в атаку ---

func test_no_retreat_monster_keeps_fighting() -> void:
	var state := _mk_state("zombie", ["goblins"])  # zombie = undead → монстр
	var ai: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.ATTACKER)[0]
	var goblin: BattleState.BattleUnit = state.get_units_by_side(BattleState.Side.DEFENDER)[0]
	ai.cell = Vector2i(13, 5)
	goblin.cell = Vector2i(1, 5)   # враг слева
	ai.set_count(2)                # 20% — для гуманоида было бы отступление
	state._rebuild_unit_grid()

	var blocked: Dictionary = state.build_all_blocked(ai, {})
	var decision := BattleAI.new().decide_turn(ai, state, blocked)

	assert_int(decision.action).is_equal(ACTION_MOVE)
	# монстр не отступает → идёт к врагу (влево, x убывает)
	assert_int(decision.target_cell.x).is_less(ai.cell.x).override_failure_message("monster should keep advancing toward the enemy instead of retreating")

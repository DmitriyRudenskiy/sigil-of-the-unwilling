extends BaseTest
## pregame-flow 4.1/4.2/4.3/4.4/4.5: GdUnit4 — headless-логика предыгрового
## потока. 4.1 поток 6 шагов до хода 1 (порядок Q18); 4.2 playable slice 3
## (C-15); 4.3 штраф оккупации; 4.4 стартовая партия ≤5; 4.5 тренировка как
## база (попутчики тренируются, не нанимаются).

const Model = preload("res://scripts/ui/pregame_flow_model.gd")


## === 4.1: предыгровой поток (6 шагов до хода 1; порядок Q18) ===

func test_flow_steps_canon_order() -> void:
	# Q18 (00-overview [КАНОН]): конструктор → знак → земной шар → города →
	# партия → тренировка. Точный порядок, 6 шагов.
	assert_int(Model.FLOW_STEPS.size()).is_equal(6)
	assert_str(str(Model.FLOW_STEPS[0])).is_equal("constructor")
	assert_str(str(Model.FLOW_STEPS[1])).is_equal("sign")
	assert_str(str(Model.FLOW_STEPS[2])).is_equal("globe")
	assert_str(str(Model.FLOW_STEPS[3])).is_equal("cities")
	assert_str(str(Model.FLOW_STEPS[4])).is_equal("party")
	assert_str(str(Model.FLOW_STEPS[5])).is_equal("training")


func test_flow_starts_at_constructor() -> void:
	var flow: Model.PregameFlow = Model.PregameFlow.new()
	assert_str(str(flow.current_step())).is_equal("constructor")
	assert_int(flow.completed_steps()).is_equal(0)
	assert_int(flow.step_count()).is_equal(6)
	assert_bool(flow.is_complete()).is_false()
	assert_bool(flow.can_start_turn_1()).is_false() \
		.override_failure_message("ход 1 не начинается до завершения всех 6 шагов")


func test_flow_advances_in_canon_order() -> void:
	var flow: Model.PregameFlow = Model.PregameFlow.new()
	var expected: Array = ["sign", "globe", "cities", "party", "training", ""]
	for i in range(6):
		assert_bool(flow.advance()).is_true() \
			.override_failure_message("advance %d: шаг должен завершиться" % (i + 1))
		assert_int(flow.completed_steps()).is_equal(i + 1)
		# После завершения шага N текущий — шаг N+1 (последний → "").
		assert_str(str(flow.current_step())).is_equal(expected[i])


func test_flow_turn1_gated_on_all_steps() -> void:
	var flow: Model.PregameFlow = Model.PregameFlow.new()
	# 0–5 завершённых шагов → ход 1 заблокирован; ровно 6 → разрешён.
	for done in range(0, 6):
		assert_bool(flow.can_start_turn_1()).is_false() \
			.override_failure_message("%d/6 шагов: ход 1 ещё не начался" % done)
		flow.advance()
	assert_bool(flow.can_start_turn_1()).is_true() \
		.override_failure_message("6/6 шагов: ход 1 разрешён")


func test_flow_advance_after_complete_is_noop() -> void:
	var flow: Model.PregameFlow = Model.PregameFlow.new()
	for i in range(6):
		flow.advance()
	assert_bool(flow.advance()).is_false() \
		.override_failure_message("advance после завершения — no-op (false)")
	assert_int(flow.completed_steps()).is_equal(6)
	assert_str(str(flow.current_step())).is_equal("")
	assert_bool(flow.is_complete()).is_true()


func test_flow_steps_snapshot_isolated() -> void:
	var flow: Model.PregameFlow = Model.PregameFlow.new()
	var snap: Array = flow.steps()
	snap.append("injected")
	snap.clear()
	assert_int(flow.step_count()).is_equal(6) \
		.override_failure_message("steps() — снимок: мутация не затрагивает модель")
	assert_str(str(flow.current_step())).is_equal("constructor")


## === 4.2: playable slice 3 (C-15: люди/полуорки/эльфы) ===

func test_playable_mask_three_races() -> void:
	assert_int(Model.PLAYABLE_RACES.size()).is_equal(3)
	assert_bool(Model.is_playable_race("humans")).is_true()
	assert_bool(Model.is_playable_race("half_orcs")).is_true()
	assert_bool(Model.is_playable_race("elves")).is_true()


func test_non_playable_races_excluded() -> void:
	# Остальные 4 расы каталога (gnomes/halflings/tieflings/dwarves) — вне slice.
	assert_bool(Model.is_playable_race("gnomes")).is_false()
	assert_bool(Model.is_playable_race("halflings")).is_false()
	assert_bool(Model.is_playable_race("tieflings")).is_false()
	assert_bool(Model.is_playable_race("dwarves")).is_false()
	assert_bool(Model.is_playable_race("unknown")).is_false()


## === 4.3: штраф оккупации (V-4/D-219: ступенчатая кривая по времени) ===

func test_occupation_penalty_zero_turns() -> void:
	assert_int(Model.occupation_penalty(0)).is_equal(0)


func test_occupation_penalty_step_curve() -> void:
	# 0 → 0; 1–2 → −1; 3–4 → −2; 5+ → −3 (кап).
	assert_int(Model.occupation_penalty(0)).is_equal(0)
	assert_int(Model.occupation_penalty(1)).is_equal(-1)
	assert_int(Model.occupation_penalty(2)).is_equal(-1)
	assert_int(Model.occupation_penalty(3)).is_equal(-2)
	assert_int(Model.occupation_penalty(4)).is_equal(-2)
	assert_int(Model.occupation_penalty(5)).is_equal(-3)


func test_occupation_penalty_capped() -> void:
	# Кап −3: 5+ ходов все дают −3 (не экспонента, не каскад).
	for t in [5, 6, 10, 50, 1000]:
		assert_int(Model.occupation_penalty(t)).is_equal(-3)


func test_occupation_penalty_negative_input_clamped() -> void:
	# Отрицательное время → 0 (clamp, детерминированно).
	assert_int(Model.occupation_penalty(-1)).is_equal(0)
	assert_int(Model.occupation_penalty(-100)).is_equal(0)


func test_occupation_penalty_after_liberation_recovers() -> void:
	# После освобождения −1 за полный ход до 0: −3 → −2 → −1 → 0.
	assert_int(Model.occupation_penalty_after_liberation(0, -3)).is_equal(-3)
	assert_int(Model.occupation_penalty_after_liberation(1, -3)).is_equal(-2)
	assert_int(Model.occupation_penalty_after_liberation(2, -3)).is_equal(-1)
	assert_int(Model.occupation_penalty_after_liberation(3, -3)).is_equal(0)


func test_occupation_penalty_after_liberation_capped_at_zero() -> void:
	# Восстановление не уходит в плюс (кап 0).
	assert_int(Model.occupation_penalty_after_liberation(4, -3)).is_equal(0)
	assert_int(Model.occupation_penalty_after_liberation(100, -3)).is_equal(0)
	assert_int(Model.occupation_penalty_after_liberation(0, -1)).is_equal(-1)
	assert_int(Model.occupation_penalty_after_liberation(1, -1)).is_equal(0)


func test_occupation_penalty_after_liberation_positive_input_clamped() -> void:
	# Положительный penalty_at_liberation → clamp к 0 (штраф ≤ 0).
	assert_int(Model.occupation_penalty_after_liberation(0, 5)).is_equal(0)
	assert_int(Model.occupation_penalty_after_liberation(2, 5)).is_equal(0)


## === 4.4: стартовая партия (≤5 попутчиков; у каждого класс/раса/внешний вид) ===

func _companion(class_id: String, race: String, appearance: String) -> Dictionary:
	return {"class": class_id, "race": race, "appearance": appearance}


func test_starting_party_empty_valid() -> void:
	var r: Dictionary = Model.validate_starting_party([])
	assert_bool(r["valid"]).is_true()
	assert_int(r["errors"].size()).is_equal(0)


func test_starting_party_five_valid() -> void:
	var companions: Array = [
		_companion("fighter", "humans", "a1"),
		_companion("ranger", "elves", "a2"),
		_companion("cleric", "half_orcs", "a3"),
		_companion("rogue", "humans", "a4"),
		_companion("wizard", "elves", "a5"),
	]
	var r: Dictionary = Model.validate_starting_party(companions)
	assert_bool(r["valid"]).is_true()


func test_starting_party_six_invalid() -> void:
	var companions: Array = [
		_companion("fighter", "humans", "a1"),
		_companion("ranger", "elves", "a2"),
		_companion("cleric", "half_orcs", "a3"),
		_companion("rogue", "humans", "a4"),
		_companion("wizard", "elves", "a5"),
		_companion("paladin", "humans", "a6"),
	]
	var r: Dictionary = Model.validate_starting_party(companions)
	assert_bool(r["valid"]).is_false()
	assert_bool(r["errors"].has("party_exceeds_5")).is_true()


func test_starting_party_missing_fields_invalid() -> void:
	var companions: Array = [
		{"class": "fighter", "race": "humans"},  # нет appearance
		{"class": "", "race": "elves", "appearance": "a2"},  # нет class
	]
	var r: Dictionary = Model.validate_starting_party(companions)
	assert_bool(r["valid"]).is_false()
	assert_bool(r["errors"].has("companion_0_no_appearance")).is_true()
	assert_bool(r["errors"].has("companion_1_no_class")).is_true()


## === 4.5: тренировка как база (попутчики тренируются, не нанимаются) ===

func test_training_sources_canon() -> void:
	var src: Array = Model.training_sources()
	assert_int(src.size()).is_equal(3)
	assert_bool(src.has("city_resident")).is_true()
	assert_bool(src.has("companion")).is_true()
	assert_bool(src.has("event_npc")).is_true()


func test_trainable_sources() -> void:
	assert_bool(Model.is_trainable_source("city_resident")).is_true()
	assert_bool(Model.is_trainable_source("companion")).is_true()
	assert_bool(Model.is_trainable_source("event_npc")).is_true()
	# Наём (вытесненная модель §3.3) — не источник тренировки.
	assert_bool(Model.is_trainable_source("hire")).is_false()
	assert_bool(Model.is_trainable_source("mercenary_market")).is_false()

extends BaseTest
## signs-prestige 2.1/2.2 (T-129): SM знака + фракционные действия.
## Канон: 02-mechanics §3.7, 02c; K-M16; Q-M32.

const SignSystem = preload("res://scripts/campaign/sign_system.gd")


func _new_sign() -> SignSystem:
	return SignSystem.new()


## === 2.1: SM знака (DORMANT→ACTIVE→SLEEPING) ===

## DORMANT → ACTIVE (выбор знака).
func test_select_sign_dormant_to_active() -> void:
	var s := _new_sign()
	assert_that(s.sign_state).is_equal("DORMANT")
	assert_that(s.sign_id).is_equal("")
	s.select_sign("spark")
	assert_that(s.sign_state).is_equal("ACTIVE")
	assert_that(s.sign_id).is_equal("spark")


## Один знак на носителя (инвариант): повторный выбор — no-op.
func test_one_sign_per_bearer() -> void:
	var s := _new_sign()
	s.select_sign("spark")
	s.select_sign("time")  # повторный выбор — no-op
	assert_that(s.sign_id).is_equal("spark")
	assert_that(s.sign_state).is_equal("ACTIVE")


## ACTIVE → SLEEPING (Престиж ≤ 0).
func test_active_to_sleeping() -> void:
	var s := _new_sign()
	s.select_sign("spark")
	s.on_prestige_changed(100)  # > 0 — остаётся ACTIVE
	assert_that(s.sign_state).is_equal("ACTIVE")
	s.on_prestige_changed(0)  # ≤ 0 — SLEEPING
	assert_that(s.sign_state).is_equal("SLEEPING")
	s.on_prestige_changed(-50)  # < 0 — SLEEPING
	assert_that(s.sign_state).is_equal("SLEEPING")


## SLEEPING → ACTIVE (Престиж > 0).
func test_sleeping_to_active() -> void:
	var s := _new_sign()
	s.select_sign("spark")
	s.on_prestige_changed(0)  # SLEEPING
	assert_that(s.sign_state).is_equal("SLEEPING")
	s.on_prestige_changed(1)  # > 0 — ACTIVE
	assert_that(s.sign_state).is_equal("ACTIVE")


## SLEEPING ≠ game over (кампания продолжается: SM не блокирует).
func test_sleeping_not_game_over() -> void:
	var s := _new_sign()
	s.select_sign("spark")
	s.on_prestige_changed(0)
	assert_that(s.sign_state).is_equal("SLEEPING")
	# SLEEPING — не терминальное состояние: можно вернуться в ACTIVE.
	s.on_prestige_changed(100)
	assert_that(s.sign_state).is_equal("ACTIVE")


## DORMANT (знак не выбран) — SM не реагирует на Престиж.
func test_dormant_no_prestige_reaction() -> void:
	var s := _new_sign()
	# DORMANT — знак не выбран.
	s.on_prestige_changed(0)
	assert_that(s.sign_state).is_equal("DORMANT")
	s.on_prestige_changed(100)
	assert_that(s.sign_state).is_equal("DORMANT")


## Смерть носителя: знак потерян (MVP: передача нет), SM → DORMANT.
func test_bearer_died() -> void:
	var s := _new_sign()
	s.select_sign("spark")
	s.bearer_died()
	assert_that(s.sign_state).is_equal("DORMANT")
	# sign_id сохраняется (знак потерян, но id известен для аудита).
	assert_that(s.sign_id).is_equal("spark")


## === 2.2: Фракционные действия (≤12, штраф стиля за повтор) ===

## Фракционное действие: ≤12 за кампанию, начисление.
func test_faction_action_grant() -> void:
	var s := _new_sign()
	s.select_sign("spark")
	var granted := s.perform_faction_action("council", 30, 1)
	assert_that(granted).is_equal(30)
	assert_that(s.faction_actions_used).is_equal(1)
	assert_that(s.faction_actions_remaining()).is_equal(11)


## Штраф стиля — только за повтор (то же id): без начисления.
func test_faction_action_repeat_penalty() -> void:
	var s := _new_sign()
	s.select_sign("spark")
	var first := s.perform_faction_action("council", 30, 1)
	assert_that(first).is_equal(30)
	var second := s.perform_faction_action("council", 30, 2)  # повтор
	assert_that(second).is_equal(0)  # штраф: без начисления
	assert_that(s.faction_actions_used).is_equal(2)


## Разные id — не повтор: начисление.
func test_faction_action_different_id_no_penalty() -> void:
	var s := _new_sign()
	s.select_sign("spark")
	var first := s.perform_faction_action("council", 30, 1)
	assert_that(first).is_equal(30)
	var second := s.perform_faction_action("monument", 100, 2)  # другой id
	assert_that(second).is_equal(100)
	assert_that(s.faction_actions_used).is_equal(2)


## 13-е действие → без начисления (лимит исчерпан).
func test_faction_action_limit() -> void:
	var s := _new_sign()
	s.select_sign("spark")
	s.faction_actions_max = 12
	var total := 0
	for i in 12:
		total += s.perform_faction_action("action_%d" % i, 10, i + 1)
	assert_that(total).is_equal(120)  # 12 × 10
	assert_that(s.faction_actions_used).is_equal(12)
	assert_that(s.faction_actions_remaining()).is_equal(0)
	# 13-е → без начисления.
	var thirteenth := s.perform_faction_action("action_13", 10, 13)
	assert_that(thirteenth).is_equal(0)
	assert_that(s.faction_actions_used).is_equal(12)  # счётчик не растёт


## SLEEPING — действия недоступны.
func test_faction_action_sleeping_blocked() -> void:
	var s := _new_sign()
	s.select_sign("spark")
	s.on_prestige_changed(0)  # SLEEPING
	var granted := s.perform_faction_action("council", 30, 1)
	assert_that(granted).is_equal(0)
	assert_that(s.faction_actions_used).is_equal(0)


## DORMANT (знак не выбран) — действия недоступны.
func test_faction_action_dormant_blocked() -> void:
	var s := _new_sign()
	# DORMANT — знак не выбран.
	var granted := s.perform_faction_action("council", 30, 1)
	assert_that(granted).is_equal(0)
	assert_that(s.faction_actions_used).is_equal(0)


## === Сериализация ===

## to_dict / from_dict — round-trip.
func test_serialization_roundtrip() -> void:
	var s := _new_sign()
	s.select_sign("time")
	s.perform_faction_action("council", 30, 1)
	s.perform_faction_action("council", 30, 2)  # повтор (штраф)
	s.on_prestige_changed(0)  # SLEEPING
	var data := s.to_dict()
	var restored := SignSystem.from_dict(data)
	assert_that(restored.sign_id).is_equal("time")
	assert_that(restored.sign_state).is_equal("SLEEPING")
	assert_that(restored.faction_actions_used).is_equal(2)
	assert_that(restored.faction_actions_max).is_equal(12)
	# Повторный id сохранён (для детекции повтора после загрузки).
	var after := restored.perform_faction_action("council", 30, 3)
	assert_that(after).is_equal(0)  # повтор (council → council)


## from_dict({}) — свежий SignSystem (DORMANT).
func test_from_dict_empty() -> void:
	var s := SignSystem.from_dict({})
	assert_that(s.sign_id).is_equal("")
	assert_that(s.sign_state).is_equal("DORMANT")
	assert_that(s.faction_actions_used).is_equal(0)


## from_dict со старым форматом (только {id}) — дефолты.
func test_from_dict_legacy() -> void:
	var s := SignSystem.from_dict({"id": "spark"})
	# Старый формат: "id" вместо "sign_id" — sign_id пустой (дефолт).
	# Это ожидаемо: миграция старого сейва обрабатывается в CampaignComposition.
	assert_that(s.sign_id).is_equal("")
	assert_that(s.sign_state).is_equal("DORMANT")

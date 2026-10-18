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


## === 4.3: Ранги (пороги 0/200/500/1000/2000; понижение при падении) ===

## Все 5 порогов: 0/200/500/1000/2000 → Безымянный/Знаемый/Почитаемый/Славный/Легендарный.
func test_rank_thresholds() -> void:
	var c := _composition()
	# balance 0 → ранг 0 (Безымянный).
	assert_that(c.prestige_rank()).is_equal(0)
	assert_that(c.prestige_rank_name()).is_equal("Безымянный")
	# balance 200 → ранг 1 (Знаемый).
	c.prestige_ledger.append({"turn": 1, "source_type": "battle_victory", "id": "t", "amount": 200.0})
	assert_that(c.prestige_rank()).is_equal(1)
	assert_that(c.prestige_rank_name()).is_equal("Знаемый")
	# balance 500 → ранг 2 (Почитаемый).
	c.prestige_ledger.append({"turn": 2, "source_type": "battle_victory", "id": "t", "amount": 300.0})
	assert_that(c.prestige_rank()).is_equal(2)
	assert_that(c.prestige_rank_name()).is_equal("Почитаемый")
	# balance 1000 → ранг 3 (Славный).
	c.prestige_ledger.append({"turn": 3, "source_type": "battle_victory", "id": "t", "amount": 500.0})
	assert_that(c.prestige_rank()).is_equal(3)
	assert_that(c.prestige_rank_name()).is_equal("Славный")
	# balance 2000 → ранг 4 (Легендарный).
	c.prestige_ledger.append({"turn": 4, "source_type": "battle_victory", "id": "t", "amount": 1000.0})
	assert_that(c.prestige_rank()).is_equal(4)
	assert_that(c.prestige_rank_name()).is_equal("Легендарный")


## Понижение: падение ниже порога = понижение ранга (K-M16).
func test_rank_demotion() -> void:
	var c := _composition()
	c.prestige_ledger.append({"turn": 1, "source_type": "battle_victory", "id": "t", "amount": 500.0})
	assert_that(c.prestige_rank()).is_equal(2)
	# Отрицательная запись (штраф) → баланс 200 → ранг 1.
	c.prestige_ledger.append({"turn": 2, "source_type": "penalty", "id": "t", "amount": -300.0})
	assert_that(c.prestige_rank()).is_equal(1)
	assert_that(c.prestige_rank_name()).is_equal("Знаемый")
	# Ещё ниже → ранг 0.
	c.prestige_ledger.append({"turn": 3, "source_type": "penalty", "id": "t", "amount": -250.0})
	assert_that(c.prestige_rank()).is_equal(0)
	assert_that(c.prestige_rank_name()).is_equal("Безымянный")


## === 4.4: Косметика (S2: притока населения нет) ===

## Престиж чисто косметический (S2): достижение ранга не добавляет население.
## process_turn детерминирован и не принимает Престиж → два состава с одним
## seed, но разным Престижем, дают идентичный прирост населения.
func test_prestige_no_population_inflow() -> void:
	var c_low := _composition()
	var c_high := _composition()
	# c_high: Престиж → «Славный» (1000, ранг 3).
	c_high.prestige_ledger.append({"turn": 1, "source_type": "battle_victory", "id": "t", "amount": 1000.0})
	assert_that(c_high.prestige_rank()).is_equal(3)
	assert_that(c_low.prestige_rank()).is_equal(0)
	# Оба: одинаковый seed → одинаковое население на старте.
	assert_that(c_low.population_system.size()).is_equal(c_high.population_system.size())
	# process_turn с одинаковой Репутацией.
	var rep := 50.0
	c_low.population_system.process_turn(7, rep)
	c_high.population_system.process_turn(7, rep)
	# Прирост населения идентичен (ранг не даёт притока, S2).
	assert_that(c_low.population_system.size()).is_equal(c_high.population_system.size())


## === 4.5: Смерть носителя → «утрата» (−2 к спасам), кампания продолжается ===

## Sмерть носителя: знак потерян (MVP: передача нет), SM → DORMANT.
func test_bearer_death_sign_lost() -> void:
	var c := _composition()
	c.set_sign("spark")
	assert_that(c.sign_system.sign_state).is_equal("ACTIVE")
	c.sign_system.bearer_died()
	assert_that(c.sign_system.sign_state).is_equal("DORMANT")


## «Утрата» партии: штраф 2 на спасброски (loss_stage 1) — модификатор боя (K-M11).
func test_bearer_death_loss_stage() -> void:
	# Живой герой → утраты нет (stage 0).
	assert_that(PartySystem.loss_stage(true)).is_equal(0)
	# Мёртвый герой → утрата (stage 1) → −2 к спасброскам.
	assert_that(PartySystem.loss_stage(false)).is_equal(1)


## Смерть носителя не заканчивает кампанию (R1, K-M11): TurnDriver не в DONE.
func test_bearer_death_campaign_continues() -> void:
	var c := _composition()
	c.set_sign("spark")
	c.sign_system.bearer_died()
	# Кампания продолжается: TurnDriver не в DONE, статус ongoing.
	assert_that(c.campaign.is_done()).is_false()
	assert_that(c.campaign.campaign_status).is_equal("ongoing")


func _composition() -> CampaignComposition:
	return CampaignComposition.from_campaign_config(424242)

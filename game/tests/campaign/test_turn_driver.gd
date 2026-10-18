extends BaseTest
## T-010: Цикл хода — машина фаз (T-122: 6 фаз, GDD-мандат §1, Q-M31),
## 21 ход, ход = сезон, K-M9 бит-каркас (ходы 1/7/14/17/21), I1-детерминизм,
## сериализуемое состояние + миграция по версиям (пост-условие T-110, v0→v1→v2),
## каркас вызова боёв. Логика фаз — T-040/T-070 (тут только каркас).

const TurnDriver = preload("res://scripts/campaign/turn_driver.gd")
const MvpSaveSchema = preload("res://scripts/campaign/save/mvp_save_schema.gd")


var _battles: Array = []


func _new_driver(seed := 12345) -> TurnDriver:
	var driver := TurnDriver.new()
	driver.seed = seed
	return driver


func _on_battle(context: Dictionary) -> void:
	_battles.append(context)


func before_test() -> void:
	_battles = []


func test_initial_state() -> void:
	var driver := _new_driver()
	assert_that(driver.current_turn).is_equal(1)
	assert_that(driver.phase_name()).is_equal("settlement")
	assert_that(driver.is_done()).is_equal(false)


## T-122: порядок фаз — GDD-мандат §1 (дословно): «городские и популяционные
## события → движение героя и армии → караваны и торговля → дипломатия
## и совет → разрешение боёв и рейдов → расчёт производства».
## MVP-срез (Q-M31 §1.3): settlement → player → caravans (no-op) →
## diplomacy (no-op) → threats → production → settlement (следующий ход).
func test_phase_order_mandate() -> void:
	var driver := _new_driver()
	driver.advance_auto_phase()
	assert_that(driver.phase_name()).is_equal("player") \
		.override_failure_message("settlement (авто) должна вести в player")
	driver.end_player_phase()
	assert_that(driver.phase_name()).is_equal("caravans") \
		.override_failure_message("end_player_phase должна вести в caravans")
	driver.advance_auto_phase()
	assert_that(driver.phase_name()).is_equal("diplomacy") \
		.override_failure_message("caravans (авто) должна вести в diplomacy")
	driver.advance_auto_phase()
	assert_that(driver.phase_name()).is_equal("threats") \
		.override_failure_message("diplomacy (авто) должна вести в threats")
	driver.advance_auto_phase()
	assert_that(driver.phase_name()).is_equal("production") \
		.override_failure_message("threats (авто) должна вести в production (T-122: production ПОСЛЕ threats)")
	driver.advance_auto_phase()
	assert_that(driver.current_turn).is_equal(2)
	assert_that(driver.phase_name()).is_equal("settlement") \
		.override_failure_message("production (авто) должна вести в settlement следующего хода")


func test_campaign_ends_at_turn_21() -> void:
	var driver := _new_driver()
	while not driver.is_done():
		match driver.phase_name():
			"settlement", "caravans", "diplomacy", "threats", "production":
				driver.advance_auto_phase()
			"player":
				driver.end_player_phase()
	assert_that(driver.current_turn).is_equal(21) \
		.override_failure_message("кампания должна завершиться на ходу 21")
	assert_that(driver.phase_name()).is_equal("done")


func test_bit_turns_k_m9() -> void:
	for t in [1, 7, 14, 17, 21]:
		assert_that(TurnDriver.is_bit_turn(t)).is_equal(true) \
			.override_failure_message("K-M9: ход %d должен быть бит-ходом" % t)
	for t in [2, 3, 6, 13, 15, 20]:
		assert_that(TurnDriver.is_bit_turn(t)).is_equal(false) \
			.override_failure_message("K-M9: ход %d не бит-ход" % t)


func test_serialization_roundtrip() -> void:
	var driver := _new_driver(777)
	driver.advance_auto_phase()
	var data := driver.to_dict()
	assert_that(data["turn"]).is_equal(1)
	assert_that(data["seed"]).is_equal(777)
	assert_that(data["phase"]).is_equal("player")
	assert_that(data["schema_version"]).is_equal(TurnDriver.SCHEMA_VERSION)
	var restored := TurnDriver.from_dict(data)
	assert_that(restored.current_turn).is_equal(1)
	assert_that(restored.seed).is_equal(777)
	assert_that(restored.phase_name()).is_equal("player")


func test_migration_v0_to_v1() -> void:
	var v0 := {"turn": 5, "seed": 42}
	var migrated := TurnDriver.migrate(v0)
	assert_that(migrated["schema_version"]).is_equal(TurnDriver.SCHEMA_VERSION)
	assert_that(migrated["phase"]).is_equal("player") \
		.override_failure_message("v0 без фазы → дефолт player")
	assert_that(v0.has("schema_version")).is_equal(false) \
		.override_failure_message("migrate не должен изменять исходный словарь")
	var driver := TurnDriver.from_dict(v0)
	assert_that(driver.current_turn).is_equal(5)
	assert_that(driver.seed).is_equal(42)
	assert_that(driver.phase_name()).is_equal("player")


## T-122: v1-сохранение (3 фазы) → v2 (6 фаз): имена v1 сохраняются,
## версия поднимается, состояние не теряется.
func test_migration_v1_to_v2() -> void:
	var v1 := {"turn": 9, "seed": 7, "phase": "threats", "schema_version": 1}
	var migrated := TurnDriver.migrate(v1)
	assert_that(migrated["schema_version"]).is_equal(TurnDriver.SCHEMA_VERSION)
	assert_that(migrated["phase"]).is_equal("threats") \
		.override_failure_message("v1-фаза threats сохраняется в v2")
	var driver := TurnDriver.from_dict(v1)
	assert_that(driver.current_turn).is_equal(9)
	assert_that(driver.phase_name()).is_equal("threats")
	# Новые v2-фазы валидны при сериализации.
	driver.phase = TurnDriver.Phase.PRODUCTION
	var data := driver.to_dict()
	assert_that(data["phase"]).is_equal("production")
	var restored := TurnDriver.from_dict(data)
	assert_that(restored.phase_name()).is_equal("production")


func test_campaign_section_passes_save_schema() -> void:
	# Состояние драйвера в секции "campaign" проходит валидацию схемы T-110.
	var driver := _new_driver()
	driver.advance_auto_phase()
	var state := {
		"campaign": driver.to_dict(),
		"resources": {"food": 30, "wood": 20, "iron": 10},
		"population": {"count": 20, "housing": 20},
		"party": [],
		"city": {},
		"map": {},
		"prestige": {"ledger": []},
		"sign": {"id": "R1", "progress": 0},
	}
	assert_that(MvpSaveSchema.validate(state)).is_equal("") \
		.override_failure_message("to_dict драйвера должна валидироваться схемой T-110")


func test_i1_determinism_same_inputs_same_events() -> void:
	var a := _run_sequence(12345)
	var b := _run_sequence(12345)
	assert_that(a.event_log()).is_equal(b.event_log()) \
		.override_failure_message("I1: одинаковые вводные → одинаковая последовательность событий")


## 4.2: 100 повторов seed+actions → byte-identical state (I1-детерминизм).
func test_i1_determinism_100_repeats_byte_identical() -> void:
	var reference := _run_sequence(424242)
	var ref_events: Array = reference.event_log()
	var ref_state: Dictionary = reference.to_dict()
	for i in 100:
		var run := _run_sequence(424242)
		assert_that(run.event_log()).is_equal(ref_events) \
			.override_failure_message("I1: повтор %d/100 — события отличаются" % (i + 1))
		assert_that(run.to_dict()).is_equal(ref_state) \
			.override_failure_message("I1: повтор %d/100 — состояние отличается" % (i + 1))


func _run_sequence(seed: int) -> TurnDriver:
	var driver := _new_driver(seed)
	for i in 3:
		if driver.is_done():
			break
		driver.advance_auto_phase()  # settlement → player
		driver.end_player_phase()    # player → caravans
		driver.advance_auto_phase()  # caravans → diplomacy
		driver.advance_auto_phase()  # diplomacy → threats
		driver.advance_auto_phase()  # threats → production
		driver.advance_auto_phase()  # production → finish (следующий settlement)
	driver.request_battle({"cause": "raid"})
	return driver


func test_battle_request_frame() -> void:
	var driver := _new_driver()
	driver.battle_request_handler = _on_battle
	driver.request_battle({"cause": "raid", "turn": 1})
	assert_that(_battles.size()).is_equal(1) \
		.override_failure_message("обработчик вызова боя должен получить контекст")
	assert_that(_battles[0]["cause"]).is_equal("raid")
	var log := driver.event_log()
	assert_that(log[log.size() - 1]).is_equal("battle_request:turn=1")


func test_phase_hooks_called() -> void:
	var driver := _new_driver()
	var calls: Array = []
	driver.settlement_hook = func() -> void:
		calls.append("settlement")
	driver.caravans_hook = func() -> void:
		calls.append("caravans")
	driver.diplomacy_hook = func() -> void:
		calls.append("diplomacy")
	driver.threats_hook = func() -> void:
		calls.append("threats")
	driver.production_hook = func() -> void:
		calls.append("production")
	driver.advance_auto_phase()
	driver.end_player_phase()
	driver.advance_auto_phase()
	driver.advance_auto_phase()
	driver.advance_auto_phase()
	driver.advance_auto_phase()
	assert_that(calls).is_equal(["settlement", "caravans", "diplomacy", "threats", "production"]) \
		.override_failure_message("хуки фаз должны вызываться в фиксированном порядке мандата (T-122)")


## T-122: post-MVP-слоты (caravans/diplomacy) — no-op в MVP: без хуков
## фазы проходят, порядок не ломается (Q-M31 §1.3: каркас существует).
func test_post_mvp_slots_noop() -> void:
	var driver := _new_driver()
	driver.advance_auto_phase()
	driver.end_player_phase()
	driver.advance_auto_phase()  # caravans — хук не задан
	driver.advance_auto_phase()  # diplomacy — хук не задан
	assert_that(driver.phase_name()).is_equal("threats") \
		.override_failure_message("no-op-слоты caravans/diplomacy должны вести в threats")


## === 4.3: статус кампании (wipe → defeat; голод сам по себе не defeat) ===

## T-060 (R1): wipe всей партии = конец кампании (DEFEAT).
func test_wipe_defeat() -> void:
	var driver := _new_driver()
	assert_that(driver.campaign_status).is_equal("ongoing")
	assert_that(driver.is_done()).is_equal(false)
	driver.defeat("party_wiped")
	assert_that(driver.campaign_status).is_equal("defeat") \
		.override_failure_message("wipe должен установить статус defeat")
	assert_that(driver.is_done()).is_equal(true) \
		.override_failure_message("defeat должен завершить кампанию")


## Повторный вызов defeat — no-op (флаг, не таймер; D-152-семья).
func test_defeat_idempotent() -> void:
	var driver := _new_driver()
	driver.defeat("party_wiped")
	var status_after_first := driver.campaign_status
	var events_after_first := driver.event_log().size()
	driver.defeat("party_wiped_again")
	assert_that(driver.campaign_status).is_equal(status_after_first) \
		.override_failure_message("повторный defeat не должен менять статус")
	assert_that(driver.event_log().size()).is_equal(events_after_first) \
		.override_failure_message("повторный defeat не должен дублировать событие")


## Голод сам по себе не defeat (02-mechanics §3.2: голод — штраф, не конец).
func test_hunger_alone_not_defeat() -> void:
	var driver := _new_driver()
	# Проходим несколько ходов без вызова defeat — статус остаётся ongoing.
	for i in 3:
		if driver.is_done():
			break
		driver.advance_auto_phase()
		driver.end_player_phase()
		driver.advance_auto_phase()
		driver.advance_auto_phase()
		driver.advance_auto_phase()
		driver.advance_auto_phase()
	assert_that(driver.campaign_status).is_equal("ongoing") \
		.override_failure_message("голод/прохождение ходов без wipe не должны давать defeat")
	assert_that(driver.is_done()).is_equal(false)


## Статус кампании сериализуется (в сейве).
func test_defeat_status_serialized() -> void:
	var driver := _new_driver(555)
	driver.defeat("party_wiped")
	var data := driver.to_dict()
	assert_that(data["status"]).is_equal("defeat")
	var restored := TurnDriver.from_dict(data)
	assert_that(restored.campaign_status).is_equal("defeat") \
		.override_failure_message("статус defeat должен сохраняться в сейве")
	assert_that(restored.is_done()).is_equal(true)

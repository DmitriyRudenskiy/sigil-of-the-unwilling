extends BaseTest
## T-071 (R5): campaign victory — верхний конец кампании.
##
## Канон: R5 (гриль v3, MVP-scope §Решения): «ход 21 = босс-бой при герое
## в городе, победа = пережить рейд»; спека campaign-core-loop «Campaign
## victory»: survive turn-21 raid + any stock > 0 → victory. Defeat не
## тронут: wipe — единственный defeat-путь (D-190).
##
## Механика: TurnDriver.victory() (идемпотентен, DONE-лок, как defeat());
## предикат «любой запас > 0» инжестится хуком (TurnDriver не знает про
## сток); проверка — в конце хода 21 при статусе ongoing (defeat/wipe
## блокирует раньше, в threats-фазе). Сток — после production-фазы хода 21
## (рейды бьют pre-production запасы, T-122).
##
## Edge (условие спеки): пережил рейд, но все запасы ≤ 0 → victory не
## даётся; кампания завершается со статусом ongoing (журнал —
## campaign_end_without_victory).

const TurnDriver = preload("res://scripts/campaign/turn_driver.gd")
const MvpSaveSchema = preload("res://scripts/campaign/save/mvp_save_schema.gd")
const MvpSaveManager = preload("res://scripts/campaign/save/mvp_save_manager.gd")
const PartySystem = preload("res://scripts/campaign/party_system.gd")

const SAVE_SLOT := 3  # слот 3 — конвенция full-run сейвов (тот же cutover-композит);
# GdUnit-прогоны последовательные, каждый сьют чистит слот в after_test


func after_test() -> void:
	MvpSaveManager.delete_slot(SAVE_SLOT)


func _new_driver(seed: int = 12345) -> TurnDriver:
	var driver := TurnDriver.new()
	driver.seed = seed
	return driver


## Полный цикл до конца кампании (каркас: player-фаза — end_player_phase).
func _run_driver_to_end(driver: TurnDriver) -> void:
	while not driver.is_done():
		match driver.phase_name():
			"settlement", "caravans", "diplomacy", "threats", "production":
				driver.advance_auto_phase()
			"player":
				driver.end_player_phase()


func _log_contains(log: Array, prefix: String) -> bool:
	for e in log:
		if str(e).begins_with(prefix):
			return true
	return false


# ── TurnDriver: victory() — статусная машина ───────────────────────────────

func test_victory_sets_status_and_done() -> void:
	var driver := _new_driver()
	assert_str(driver.campaign_status).is_equal("ongoing")
	driver.victory("survived_final_raid")
	assert_str(driver.campaign_status).is_equal("victory") \
		.override_failure_message("victory должен установить статус victory")
	assert_bool(driver.is_done()).is_true() \
		.override_failure_message("victory должен завершить кампанию")


## Повторный вызов victory — no-op (флаг, не таймер; как defeat, D-152-семья).
func test_victory_idempotent() -> void:
	var driver := _new_driver()
	driver.victory("survived_final_raid")
	var status_after_first := driver.campaign_status
	var events_after_first := driver.event_log().size()
	driver.victory("again")
	assert_str(driver.campaign_status).is_equal(status_after_first) \
		.override_failure_message("повторный victory не должен менять статус")
	assert_int(driver.event_log().size()).is_equal(events_after_first) \
		.override_failure_message("повторный victory не должен дублировать событие")


## DONE-лок в обе стороны: defeat → victory no-op (wipe приоритетен, D-190);
## victory → defeat no-op (конец уже зафиксирован).
func test_done_locks_both_terminal_states() -> void:
	var a := _new_driver()
	a.defeat("party_wiped")
	a.victory("late")
	assert_str(a.campaign_status).is_equal("defeat") \
		.override_failure_message("defeat не должен перезаписываться victory")
	var b := _new_driver()
	b.victory("survived_final_raid")
	b.defeat("late")
	assert_str(b.campaign_status).is_equal("victory") \
		.override_failure_message("victory не должен перезаписываться defeat")


# ── TurnDriver: проверка в конце хода 21 ───────────────────────────────────

## Ход 21, пережил (ongoing) + запас > 0 → victory.
func test_victory_at_turn21_with_stock() -> void:
	var driver := _new_driver()
	driver.victory_check_hook = func() -> bool:
		return true
	_run_driver_to_end(driver)
	assert_int(driver.current_turn).is_equal(21)
	assert_str(driver.campaign_status).is_equal("victory") \
		.override_failure_message("конец хода 21 при ongoing + запас > 0 → victory")
	assert_bool(driver.is_done()).is_true()


## Edge спеки: пережил рейд, но все запасы ≤ 0 → victory не даётся;
## кампания завершается со статусом ongoing (журнал — наблюдаемость).
func test_turn21_survived_no_stock_stays_ongoing() -> void:
	var driver := _new_driver()
	driver.victory_check_hook = func() -> bool:
		return false
	_run_driver_to_end(driver)
	assert_str(driver.campaign_status).is_equal("ongoing") \
		.override_failure_message("без запаса victory не даётся (условие спеки)")
	assert_bool(driver.is_done()).is_true()
	assert_bool(_log_contains(driver.event_log(), "campaign_end_without_victory:turn=21")) \
		.override_failure_message("журнал: конец кампании без victory")


## До хода 21 victory не проверяется: ход 20 завершён → ongoing, не done,
## хук не вызывался. (Счётчик — по ссылке: Array; lambda GDScript захватывает
## локальные по значению.)
func test_no_victory_before_turn21() -> void:
	var driver := _new_driver()
	var calls := [0]
	driver.victory_check_hook = func() -> bool:
		calls[0] += 1
		return true
	while not driver.is_done() and driver.current_turn < 21:
		match driver.phase_name():
			"settlement", "caravans", "diplomacy", "threats", "production":
				driver.advance_auto_phase()
			"player":
				driver.end_player_phase()
	assert_int(driver.current_turn).is_equal(21)
	assert_str(driver.campaign_status).is_equal("ongoing")
	assert_bool(driver.is_done()).is_false()
	assert_int(calls[0]).is_equal(0) \
		.override_failure_message("предикат victory не должен вызываться до конца хода 21")


## Хук вызывается ровно один раз — в конце хода 21. (Счётчик — по ссылке,
## см. test_no_victory_before_turn21.)
func test_victory_hook_called_once() -> void:
	var driver := _new_driver()
	var calls := [0]
	driver.victory_check_hook = func() -> bool:
		calls[0] += 1
		return true
	_run_driver_to_end(driver)
	assert_int(calls[0]).is_equal(1) \
		.override_failure_message("предикат victory вызывается ровно один раз (конец хода 21)")


## Wipe в ходу 21 (defeat в threats-фазе) блокирует victory.
func test_defeat_at_turn21_blocks_victory() -> void:
	var driver := _new_driver()
	driver.victory_check_hook = func() -> bool:
		return true
	# До threats-фазы хода 21 (wipe в threats-фазе: defeat → DONE, finish не идёт).
	while not driver.is_done():
		if driver.current_turn == 21 and driver.phase_name() == "threats":
			break
		match driver.phase_name():
			"settlement", "caravans", "diplomacy", "threats", "production":
				driver.advance_auto_phase()
			"player":
				driver.end_player_phase()
	assert_int(driver.current_turn).is_equal(21)
	assert_str(driver.phase_name()).is_equal("threats")
	driver.defeat("party_wiped")  # wipe в threats-фазе хода 21
	assert_str(driver.campaign_status).is_equal("defeat") \
		.override_failure_message("wipe в ходу 21 → defeat, не victory")
	assert_bool(driver.is_done()).is_true()


# ── TurnDriver: сериализация ───────────────────────────────────────────────

## Статус victory сериализуется и восстанавливается (схема не тронута:
## поле "status" — строка; миграция не нужна).
func test_victory_status_serialized() -> void:
	var driver := _new_driver(555)
	driver.victory_check_hook = func() -> bool:
		return true
	_run_driver_to_end(driver)
	var data := driver.to_dict()
	assert_str(str(data["status"])).is_equal("victory")
	var restored := TurnDriver.from_dict(data)
	assert_str(restored.campaign_status).is_equal("victory") \
		.override_failure_message("статус victory должен сохраняться в сейве")
	assert_bool(restored.is_done()).is_true()


## Секция кампании со статусом victory проходит схему T-110.
func test_victory_campaign_section_passes_save_schema() -> void:
	var driver := _new_driver()
	driver.victory_check_hook = func() -> bool:
		return true
	_run_driver_to_end(driver)
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
	assert_str(MvpSaveSchema.validate(state)).is_equal("") \
		.override_failure_message("статус victory должен валидироваться схемой T-110")


# ── CampaignComposition: полный прогон ─────────────────────────────────────

## Полный MVP-цикл (seed 12345, T-041-якорь: герой выигрывает босс-бой) →
## кампания завершается victory (пережил рейд хода 21, запасы > 0).
func test_full_campaign_ends_victory() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	while not comp.campaign.is_done():
		comp.advance_turn()
	assert_int(comp.campaign.current_turn).is_equal(21)
	assert_str(str(comp.campaign.campaign_status)).is_equal("victory") \
		.override_failure_message("полный прогон: пережил финальный рейд → victory")
	assert_bool(comp.final_battle_seen).is_true()
	assert_bool(comp.final_raid_repelled).is_true()
	# Спека «AND the final prestige rank is reported»: ранг — read-only
	# аксессор (T-129); UI-отчёт — deferred (mvp-ui-flow).
	assert_int(comp.prestige_rank()).is_not_negative()
	assert_str(str(comp.prestige_rank_name())).is_not_empty()


## Сейв/загрузка: victory сохраняется и восстанавливается; пересборка после
## загрузки байтово идентична (контракт T-110).
func test_full_campaign_victory_save_roundtrip() -> void:
	var comp := CampaignComposition.from_campaign_config(12345)
	while not comp.campaign.is_done():
		comp.advance_turn()
	var state: Dictionary = comp.build_save_state()
	assert_str(str((state["campaign"] as Dictionary).get("status", ""))).is_equal("victory")
	var res: Dictionary = MvpSaveManager.save_slot(SAVE_SLOT, state)
	assert_bool(bool(res["ok"])).is_true()
	var loaded: Dictionary = MvpSaveManager.load_slot(SAVE_SLOT)
	assert_bool(bool(loaded["ok"])).is_true()
	# Байтовый контракт (T-110) — до load_save_state: load мутирует sign-секцию
	# на месте (backward-compat sign_id, паттерн test_cutover_composite).
	var s_loaded: String = MvpSaveManager.serialize(loaded["state"])
	var revived := CampaignComposition.from_campaign_config(12345)
	revived.load_save_state(loaded["state"])
	assert_str(str(revived.campaign.campaign_status)).is_equal("victory") \
		.override_failure_message("victory должен восстанавливаться из сейва")
	assert_bool(revived.campaign.is_done()).is_true()
	# Повторная проверка после load не ломает state machine (идемпотентность).
	revived.campaign.victory("after_load")
	assert_str(str(revived.campaign.campaign_status)).is_equal("victory")
	assert_str(MvpSaveManager.serialize(revived.build_save_state())) \
		.is_equal(s_loaded) \
		.override_failure_message("пересборка после load — байтово идентична")


## Edge (реальный предикат): пережил рейд хода 21, но все запасы ≤ 0
## (тест-настройка: без зданий — production 0; сток 0) → victory не даётся,
## кампания завершается ongoing.
func test_turn21_survived_no_stock_not_victory() -> void:
	var comp := _run_to_start_of_turn_21()
	comp.settlement.buildings = []
	comp.settlement.stocks = {"food": 0.0, "wood": 0.0, "iron": 0.0}
	comp.advance_turn()
	assert_bool(comp.campaign.is_done()).is_true()
	assert_str(str(comp.campaign.campaign_status)).is_equal("ongoing") \
		.override_failure_message("без запаса victory не даётся (условие спеки)")
	assert_bool(_log_contains(comp.campaign.event_log(), "campaign_end_without_victory:turn=21")) \
		.override_failure_message("журнал: конец кампании без victory")


## Wipe в финальном бою (ход 21) → defeat, не victory (D-190: wipe —
## единственный defeat-путь). Тест-настройка: партия из 1, герой 1 HP +
## con −3 (паттерн test_party_hp_rest: ослабленный герой гибнет в босс-бою).
func test_turn21_wipe_ends_defeat_not_victory() -> void:
	var comp := _run_to_start_of_turn_21()
	# Партия из 1 (второй член — DEAD в тест-настройке).
	var m2: Dictionary = comp.party[1]
	m2["state"] = PartySystem.STATE_DEAD
	m2.erase("current_hp")
	var m: Dictionary = comp.party[0]
	var w: Dictionary = comp._statblocks["warrior"]
	var saved_con: int = int(w.get("con", 0))
	# settlement-фаза хода 21 (REST) → затем ослабляем героя до боя.
	comp.campaign.advance_auto_phase()
	m["current_hp"] = 1
	w["con"] = -3
	comp.campaign.end_player_phase()
	comp.campaign.advance_auto_phase()  # caravans
	comp.campaign.advance_auto_phase()  # diplomacy
	comp.campaign.advance_auto_phase()  # threats → финальный рейд → босс-бой
	w["con"] = saved_con
	assert_bool(comp.final_battle_seen).is_true()
	assert_bool(comp.final_raid_repelled).is_false()
	assert_str(str(comp.campaign.campaign_status)).is_equal("defeat") \
		.override_failure_message("wipe в финальном бою → defeat, не victory")
	# defeat() в threats-хуке не останавливает фазу-машину мгновенно (существующая
	# семантика: драйвер доводит ход до production, _finish_turn → DONE).
	comp.campaign.advance_auto_phase()  # production → finish
	assert_bool(comp.campaign.is_done()).is_true()


## Прогон кампании до начала хода 21 (фаза settlement).
func _run_to_start_of_turn_21() -> CampaignComposition:
	var comp := CampaignComposition.from_campaign_config(12345)
	while comp.campaign.current_turn < 21:
		comp.advance_turn()
	return comp

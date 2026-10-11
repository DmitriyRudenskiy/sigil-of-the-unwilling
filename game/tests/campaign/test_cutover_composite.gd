extends BaseTest

## Cutover-композит D-157 (14-я итерация, раунд 4 §2.2): T-117-раннер,
## расширенный до полного гейта. Прогонит тот же composition root, что и
## main.gd (CampaignComposition — единая проводка, анти-дубль):
##   1) полный MVP-цикл 21 хода от campaign.json (seed = CAMPAIGN_SEED);
##   2) победная оценка по бит-таблице (финальный рейд отражён/нет +
##      Престиж-якорь по ledger);
##   3) сейв/загрузка roundtrip (сборка секций T-110 — второй шов здесь же);
##   4) двойной прогон → байт-идентичные сейвы (I1 на уровне всей кампании —
##      вершинная форма инварианта).
## Зелёный композит = исполнение D-157 дословно (полный MVP-цикл на
## K-канон-линии; петля Резонанс→Репутация — Ф4, вне критерия).

const COMPOSITE_SLOT := 3  # отдельный слот: не трогать 1/2 (test_mvp_save)


func _run_campaign() -> CampaignComposition:
	return CampaignComposition.from_campaign_config(12345)


func _run_to_done() -> CampaignComposition:
	var comp := _run_campaign()
	while not comp.campaign.is_done():
		comp.advance_turn()
	return comp


func _serialize(state: Dictionary) -> String:
	return MvpSaveManager.serialize({"version": MvpSaveSchema.current_version(),
		"state": state})


func after_test() -> void:
	MvpSaveManager.delete_slot(COMPOSITE_SLOT)


## — 1. Полный MVP-цикл 21 хода —

func test_full_21_turn_run() -> void:
	var comp := _run_to_done()
	assert_bool(comp.campaign.is_done()).is_true()
	assert_int(comp.campaign.current_turn).is_equal(21)
	assert_bool(comp.population_system.size() > 0).is_true()
	# Угрозы жили: рейды были (директивы 7/14/17/21 — T-115).
	assert_bool(comp.threats.raids_count >= 3).is_true()


## — 2. Победная оценка по бит-таблице —

func test_victory_assessment_shape_and_final_anchor() -> void:
	var comp := _run_to_done()
	var v: Dictionary = comp.victory_assessment()
	assert_bool(comp.final_battle_seen).is_true()  # ход 21: герой в городе → бой был
	for key in ["campaign_done", "final_battle_seen", "final_raid_repelled",
		"prestige_balance", "prestige_anchor_met", "victory"]:
		assert_bool(v.has(key)).is_true()
	assert_bool(bool(v["campaign_done"])).is_true()
	assert_bool(bool(v["victory"])).is_equal(comp.final_raid_repelled)
	# Якорь «ход 21 = финальный рейд отражён/нет» — бинарный, без третьего.
	assert_bool(typeof(v["final_raid_repelled"]) == TYPE_BOOL).is_true()


## — Престиж = ledger (K-M16), не переменная —

func test_prestige_ledger_shape_and_balance() -> void:
	var comp := _run_to_done()
	assert_bool(comp.prestige_ledger.size() > 0).is_true()
	var balance := 0.0
	for e in comp.prestige_ledger:
		for field in ["turn", "source_type", "id", "amount"]:
			assert_bool((e as Dictionary).has(field)).is_true()
		assert_str(str(e["source_type"])).is_equal("battle_victory")  # MVP-источник
		balance += float(e["amount"])
	var v: Dictionary = comp.victory_assessment()
	assert_float(float(v["prestige_balance"])).is_equal(balance)
	# Сальдо — производная ledger (в сейве не хранится — T-110).
	assert_bool(not (comp.build_save_state()["prestige"] as Dictionary).has("balance")).is_true()


## — 3. Сейв/загрузка roundtrip (сборка секций T-110) —

func test_save_state_passes_schema() -> void:
	var comp := _run_to_done()
	assert_str(MvpSaveSchema.validate(comp.build_save_state())).is_equal("")


func test_save_load_roundtrip() -> void:
	var comp := _run_to_done()
	var state: Dictionary = comp.build_save_state()
	var res: Dictionary = MvpSaveManager.save_slot(COMPOSITE_SLOT, state)
	assert_bool(bool(res["ok"])).is_true()
	var loaded: Dictionary = MvpSaveManager.load_slot(COMPOSITE_SLOT)
	assert_bool(bool(loaded["ok"])).is_true()
	# Контракт roundtrip — байтовый (T-110 «байтовая детерминизм»), НЕ битовый:
	# JSON-сериализация float теряет последний знак (stringify→parse→stringify —
	# фиксированная точка), значения совпадают с точностью записи.
	var s_orig := MvpSaveManager.serialize(state)
	var s_loaded := MvpSaveManager.serialize(loaded["state"])
	assert_str(s_loaded).is_equal(s_orig)
	# Загрузка в свежую композицию → пересборка секций байтово совпадает.
	var revived := _run_campaign()
	revived.load_save_state(loaded["state"])
	assert_str(MvpSaveManager.serialize(revived.build_save_state())).is_equal(s_loaded)
	# Скаляр population — производная ростери (T-110): восстановлен из roster.
	assert_int(revived.settlement.population).is_equal(revived.population_system.size())


## — 4. Двойной прогон: I1 на уровне всей кампании (вершина инварианта) —

func test_double_run_byte_identical() -> void:
	var s1 := _serialize(_run_to_done().build_save_state())
	var s2 := _serialize(_run_to_done().build_save_state())
	assert_int(s1.length()).is_greater(0)
	assert_str(s1).is_equal(s2)
	# И победные оценки идентичны (тот же прогон — то же решение).
	var a: Dictionary = _run_to_done().victory_assessment()
	var b: Dictionary = _run_to_done().victory_assessment()
	assert_str(MvpSaveManager.serialize(a)).is_equal(MvpSaveManager.serialize(b))

"""city-construction-districts 2.2 (D-235): распад района — гистерезис на проекции.

Канон: 02-mechanics §3.5 (Y6) — «если теги ниже порога 3 дня подряд — район снят».
Носитель (Q-M99 → (б), D-235): район остаётся проекцией города, мерой «теги
собраны» служит наличие у группы ≥1 здания, счётчик ходов живёт в
`DistrictSystem.district_state` и персистится тем же `to_dict()`. Ценa гистерезиса
измерима: здание вернули за 3 хода — настроение района (а значит и множитель
производства) сохранено; дольше — запись уничтожена, настроение сброшено.
"""
extends BaseTest

const SettlementProcessorScript := preload("res://scripts/campaign/settlement_processor.gd")
const ENGINEERS := "Инженеры и Строители"


func _config() -> Dictionary:
	return MvpInvariants.load_config("districts")


func _system() -> DistrictSystem:
	return DistrictSystem.new(_config(), {"farm": 2, "sawmill": 2, "mine": 2})


func _sawmill() -> Array:
	return [{"id": "sawmill", "group": ENGINEERS, "output_day": {"wood": 0.5}, "efficiency": 1.0}]


func _tick(sys: DistrictSystem, buildings: Array) -> Dictionary:
	return sys.process_turn(buildings, 20, 5, "OK")


func _present(sys: DistrictSystem) -> bool:
	return bool((sys.district_state.get(ENGINEERS, {}) as Dictionary).get("present", false))


func _below(sys: DistrictSystem) -> int:
	return int((sys.district_state.get(ENGINEERS, {}) as Dictionary).get("below_days", 0))


## Район появляется тем же ходом, как у группы появляется здание (спека: «appears
## when the required tags are gathered»), и до порога о распаде речи нет.
func test_district_appears_with_first_building() -> void:
	var sys := _system()
	var report := _tick(sys, _sawmill())
	assert_bool(bool((report["districts"] as Dictionary)[ENGINEERS]["present"])) \
		.override_failure_message("район не появился с первым зданием группы").is_true()
	assert_int(_below(sys)).is_equal(0)
	assert_int((report.get("disbanded", []) as Array).size()).is_equal(0)


## Дни 1–2 без зданий: район ещё жив, его настроение (унаследованное от сезона со
## сдвигом) не тронуто — это и есть смысл льготного окна.
func test_grace_period_keeps_district_and_its_mood() -> void:
	var sys := _system()
	var first: Dictionary = _tick(sys, _sawmill())
	var drifted: float = float((first["districts"] as Dictionary)[ENGINEERS]["mood"])
	assert_float(drifted).override_failure_message(
		"ожидался сдвиг настроения за сезон (нужда не покрыта), иначе тест ничего не мерит"
		).is_not_equal(float(_config().get("mood_start", 70.0)))
	for day in [1, 2]:
		var report := _tick(sys, [])
		assert_bool(bool((report["districts"] as Dictionary)[ENGINEERS]["present"])) \
			.override_failure_message("район снят раньше порога (день %d)" % day).is_true()
		assert_int(_below(sys)).is_equal(day)
		assert_float(float((report["districts"] as Dictionary)[ENGINEERS]["mood"])) \
			.override_failure_message("льготное окно тронуло настроение района").is_equal(drifted)
		assert_int((report.get("disbanded", []) as Array).size()).is_equal(0)


## День 3 без зданий: район снят, событие в отчёт (оттуда — в хронику), запись о
## районе уничтожена — настроение возвращается к стартовому.
func test_third_consecutive_day_disbands() -> void:
	var sys := _system()
	_tick(sys, _sawmill())
	_tick(sys, [])
	_tick(sys, [])
	var report := _tick(sys, [])
	var row: Dictionary = (report["districts"] as Dictionary)[ENGINEERS]
	assert_bool(bool(row["present"])) \
		.override_failure_message("район не снят на 3-й день подряд").is_false()
	assert_bool((report.get("disbanded", []) as Array).has(ENGINEERS)) \
		.override_failure_message("снятие района не попало в отчёт (в хронику идёт отсюда)").is_true()
	assert_float(float(row["mood"])).override_failure_message(
		"настроение мёртвого района не сброшено — район пережил собственное расписание"
		).is_equal(float(_config().get("mood_start", 70.0)))
	assert_int(_below(sys)).is_equal(0)
	assert_bool(_present(sys)).is_false()


## Возврат здания внутри льготного окна обнуляет счётчик и сохраняет настроение:
## распад меряет не «было ли здание вообще», а «три хода подряд ли не было».
func test_rebuild_inside_grace_clears_counter_and_keeps_mood() -> void:
	var sys := _system()
	var first: Dictionary = _tick(sys, _sawmill())
	var drifted: float = float((first["districts"] as Dictionary)[ENGINEERS]["mood"])
	_tick(sys, [])
	_tick(sys, [])
	var back := _tick(sys, _sawmill())
	assert_bool(bool((back["districts"] as Dictionary)[ENGINEERS]["present"])) \
		.is_true()
	assert_int(_below(sys)).override_failure_message(
		"возврат здания не обнулил счётчик простоя").is_equal(0)
	# Не сброшено к старту и продолжено с того же значения: сезон с вернувшимся
	# зданием даёт свой −1 (нужда не покрыта), то есть 69 → 68, а не 70.
	assert_float(float((back["districts"] as Dictionary)[ENGINEERS]["mood"])) \
		.override_failure_message(
			"настроение живого района потеряно за 2 хода простоя (ожидалось %s)" % str(drifted - 1.0)
			).is_equal(drifted - 1.0)
	# Счётчик продолжен с нуля: снятие — всё ещё через 3 хода подряд.
	_tick(sys, [])
	_tick(sys, [])
	assert_bool(_present(sys)).is_true()
	assert_bool((_tick(sys, []).get("disbanded", []) as Array).has(ENGINEERS)).is_true()


## Сейв не имеет права обнулять «3 хода подряд»: состояние читается из JSON
## (int → float на round-trip), и счётчик продолжается, а не стартует заново.
func test_grace_counter_survives_save_roundtrip() -> void:
	var sys := _system()
	_tick(sys, _sawmill())
	_tick(sys, [])
	_tick(sys, [])
	assert_int(_below(sys)).is_equal(2)
	var restored := DistrictSystem.from_dict(
		JSON.parse_string(JSON.stringify(sys.to_dict())), _config(),
		{"farm": 2, "sawmill": 2, "mine": 2})
	assert_int(_below(restored)).override_failure_message(
		"счётчик простоя не пережил сейв/загрузку").is_equal(2)
	assert_bool(_present(restored)).is_true()
	assert_bool((_tick(restored, []).get("disbanded", []) as Array).has(ENGINEERS)) \
		.override_failure_message("после загрузки район не добился до порога").is_true()


## Строка «Без группы» — не район (это отсутствие района), поэтому распад к ней
## не применяется; группа, у которой зданий не было никогда, не может и распасться.
func test_ungrouped_row_and_empty_group_never_disband() -> void:
	var sys := _system()
	var report := {}
	for i in 10:
		report = _tick(sys, [{"id": "farm", "group": SettlementProcessorScript.UNGROUPED,
			"output_day": {"food": 1.0}, "efficiency": 1.0}])
	var ungrouped: Dictionary = (report["districts"] as Dictionary)[SettlementProcessorScript.UNGROUPED]
	assert_bool(bool(ungrouped["present"])) \
		.override_failure_message("строка «Без группы» поехала в распад").is_true()
	assert_int((report.get("disbanded", []) as Array).size()) \
		.override_failure_message("несуществовавший район записан в распавшиеся").is_equal(0)
	assert_int(sys.district_state.size()) \
		.override_failure_message("состояние заводилось не только для 7 канонических групп"
			).is_equal(SettlementProcessorScript.GROUPS.size())

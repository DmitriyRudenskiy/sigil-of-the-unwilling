"""D-240 (T-175): рождение района — писатель хроники «район создан».

Канон: 02-mechanics §3.5 и спека city-construction-districts (район «appears
when the required tags are gathered»), 04-narrative (бит «район» — ключевое
событие, «запись с причиной»). Хроника обязана отличать постройку района от
старта кампании: иначе ход 1 выдал бы игроку три записи о том, чего он не делал
(запись = событие, а не снимок состояния).
"""
extends BaseTest

const SettlementProcessorScript := preload("res://scripts/campaign/settlement_processor.gd")
const FARMERS := "Земледельцы и Пивовары"
const WEAVERS := "Ткачи и Ремесленники"


func _config() -> Dictionary:
	return MvpInvariants.load_config("districts")


func _system() -> DistrictSystem:
	return DistrictSystem.new(_config(), {"farm": 2, "sawmill": 2, "mine": 2})


func _building(id: String, group: String) -> Dictionary:
	return {"id": id, "group": group, "output_day": {"food": 1.0}, "efficiency": 1.0}


func _created(report: Dictionary) -> Array:
	return report.get("created", []) as Array


## Стартовые здания — не «созданные районы»: базовая линия берётся молча.
func test_first_tick_establishes_baseline_without_birth_records() -> void:
	var sys := _system()
	var report := sys.process_turn(
			[_building("farm", FARMERS), _building("loom", WEAVERS)], 20, 5, "OK")
	assert_int((report["districts"] as Dictionary).size()).is_greater(0)
	assert_int(_created(report).size()) \
		.override_failure_message("стартовые районы записаны как созданные").is_equal(0)


## Район появляется тем же ходом, как у группы появилось первое здание.
func test_first_building_of_a_group_reports_birth_once() -> void:
	var sys := _system()
	var first := sys.process_turn([_building("farm", FARMERS)], 20, 5, "OK")
	assert_int(_created(first).size()).is_equal(0)
	var second := sys.process_turn(
			[_building("farm", FARMERS), _building("loom", WEAVERS)], 20, 5, "OK")
	assert_array(_created(second)).contains_exactly([WEAVERS])
	# Третий ход с тем же составом — нового района нет (иначе лента росла бы
	# от присутствия, а не от события).
	var third := sys.process_turn(
			[_building("farm", FARMERS), _building("loom", WEAVERS)], 20, 5, "OK")
	assert_int(_created(third).size()) \
		.override_failure_message("район переписывается каждый ход").is_equal(0)


## Отстроенный район при возврате зданий создаётся заново — это новое событие.
func test_rebuild_after_disband_is_a_new_birth() -> void:
	var sys := _system()
	var farms: Array = [_building("farm", FARMERS)]
	var looms: Array = [_building("loom", WEAVERS)]
	sys.process_turn(farms + looms, 20, 5, "OK")
	# Окно гистерезиса (disband_below_days = 3) — район снят на четвёртый ход.
	var disbanded_turn := 0
	for turn in range(2, 8):
		var report := sys.process_turn(farms, 20, 5, "OK")
		if not (report["disbanded"] as Array).is_empty():
			disbanded_turn = turn
			break
	assert_int(disbanded_turn).is_greater(0)
	var rebuild := sys.process_turn(farms + looms, 20, 5, "OK")
	assert_array(_created(rebuild)).contains_exactly([WEAVERS])


## Сейв/загрузка: восстановленный `district_state` — уже взятая базовая линия,
## иначе после каждой загрузки игрок получал бы «район создан» на первый ход.
func test_load_does_not_replay_births() -> void:
	var sys := _system()
	sys.process_turn([_building("farm", FARMERS), _building("loom", WEAVERS)], 20, 5, "OK")
	var restored := DistrictSystem.from_dict(
			sys.to_dict(), _config(), {"farm": 2, "sawmill": 2, "mine": 2})
	var report := restored.process_turn(
			[_building("farm", FARMERS), _building("loom", WEAVERS)], 20, 5, "OK")
	assert_int(_created(report).size()) \
		.override_failure_message("загрузка сыграла рождение районов").is_equal(0)

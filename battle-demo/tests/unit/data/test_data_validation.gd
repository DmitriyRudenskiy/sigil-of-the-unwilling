extends GdUnitTestSuite

# [AI]: сгенерировано по задаче 5.6 tasks.md.
#
# Каждое правило загрузчика проверяется на испорченной копии данных: assert,
# что нарушение прорезается, а не только что настоящие данные хороши. Портим
# ровно одно место и ищем ровно его — сопутствующие нарушения допустимы,
# проверять их нечего (для этого есть отдельные тесты).


func _units() -> Dictionary:
	# load() кэширует ресурсы, а тесты их портят — поэтому глубокие копии.
	var copies := {}
	for id in DataLibrary.load_units():
		copies[id] = DataLibrary.load_units()[id].duplicate(true)
	return copies


func _roster(id: String) -> RosterData:
	return DataLibrary.load_roster(id).duplicate(true) as RosterData


func test_missing_unit_is_reported() -> void:
	var units := _units()
	units.erase(&"priest")
	assert_bool(_fires(DataLibrary.validate(units, DataLibrary.load_rosters()), "priest")).is_true()


func test_dead_unit_stats_are_reported() -> void:
	var units := _units()
	units[&"knight"].max_hp = 0
	assert_bool(_fires(_units_problems(units), "hp/attack/initiative")).is_true()


func test_unit_without_ability_is_reported() -> void:
	var units := _units()
	units[&"knight"].abilities.clear()
	assert_bool(_fires(_units_problems(units), "нужна ровно одна способность")).is_true()


func test_unknown_status_is_reported() -> void:
	var units := _units()
	var status_ids: Array[StringName] = units[&"sorcerer"].abilities[0].applies
	status_ids.clear()
	status_ids.append(&"petrify")
	assert_bool(_fires(_units_problems(units), "неизвестный статус petrify")).is_true()


func test_ability_cost_above_focus_cap_is_reported() -> void:
	var units := _units()
	units[&"wizard"].abilities[0].cost = 9
	assert_bool(_fires(_units_problems(units), "стоимость 9 вне 0..5")).is_true()


func test_duplicate_unit_in_roster_is_reported() -> void:
	var roster := _roster("a")
	roster.units[1] = roster.units[0]
	assert_bool(_fires(_roster_problems(roster), "knight встречается дважды")).is_true()


func test_unknown_unit_in_roster_is_reported() -> void:
	var roster := _roster("a")
	var ghost := UnitStats.new()
	ghost.id = &"nobody"
	roster.units[0] = ghost
	assert_bool(_fires(_roster_problems(roster), "юнит nobody нет в каталоге")).is_true()


func test_enemy_in_roster_is_reported() -> void:
	var roster := _roster("a")
	roster.units[0] = _units()[DataLibrary.ENEMY_ID]
	assert_bool(_fires(_roster_problems(roster),
		"враг %s в наборе игрока" % DataLibrary.ENEMY_ID)).is_true()


func test_roster_of_wrong_size_is_reported() -> void:
	var roster := _roster("a")
	var shorter: Array[UnitStats] = []
	for index in range(1, roster.units.size()):
		shorter.append(roster.units[index])
	roster.units = shorter
	assert_bool(_fires(_roster_problems(roster), "юнитов 6, ожидалось 7")).is_true()


func test_roster_without_title_is_reported() -> void:
	var roster := _roster("a")
	roster.title = ""
	assert_bool(_fires(_roster_problems(roster), "пустое имя")).is_true()


func test_identical_rosters_are_reported() -> void:
	var second := _roster("a")
	second.id = &"b"
	# Имя меняем, иначе сначала сработало бы правило «имя набора повторяется».
	second.title = "Другое"
	var problems := DataLibrary.validate(_units(), [_roster("a"), second])
	assert_bool(_fires(problems, "различаются на 0 и 0 юнитов")).is_true()


## Жреца меняем на рыцаря, чтобы размер набора и правило отличий не сработали
## раньше: проверять хотим ровно покрытие пула.
func test_pool_unit_outside_every_roster_is_reported() -> void:
	var second := _roster("b")
	var swapped: Array[UnitStats] = []
	for stats in second.units:
		swapped.append(
			_units()[&"knight"] if stats.id == &"priest" else stats
		)
	second.units = swapped
	var problems := DataLibrary.validate(_units(), [_roster("a"), second])
	assert_bool(_fires(problems, "не входит ни в один набор")).is_true()


func _units_problems(units: Dictionary) -> Array[String]:
	return DataLibrary.validate(units, DataLibrary.load_rosters())


## Проверяет одно нарушение: подменяет только набор, остальное оставляет живым.
func _roster_problems(roster: RosterData) -> Array[String]:
	return DataLibrary.validate(_units(), [roster, DataLibrary.load_roster("b")])


func _fires(problems: Array[String], needle: String) -> bool:
	for problem in problems:
		if problem.contains(needle):
			return true
	return false

extends GdUnitTestSuite

# [AI]: сгенерировано по задаче 5.5 tasks.md.
#
# Данные проходят загрузчик и валидатор. Это тот тест, который краснеет, когда
# .tres рассинхронизирован с design-brief.md или с tools/author_data.gd.

const EXPECTED_IDS := [
	&"knight",
	&"spearman",
	&"archer",
	&"wizard",
	&"sorcerer",
	&"barbarian",
	&"cutthroat",
	&"priest",
	&"stormmage",
	&"wolf",
]


func test_all_units_load() -> void:
	var units := DataLibrary.load_units()
	assert_int(units.size()).is_equal(DataLibrary.UNIT_COUNT)
	for id in EXPECTED_IDS:
		assert_bool(units.has(id)).is_true()


func test_real_data_passes_validation() -> void:
	var problems := DataLibrary.validate(DataLibrary.load_units(), DataLibrary.load_rosters())
	assert_str("\n".join(problems)).is_equal("")


func test_rosters_are_the_designed_pair() -> void:
	var a := DataLibrary.load_roster("a")
	var b := DataLibrary.load_roster("b")
	assert_int(a.units.size()).is_equal(DataLibrary.ROSTER_SIZE)
	assert_int(b.units.size()).is_equal(DataLibrary.ROSTER_SIZE)
	# A = позиции 1–7 (тяжёлая линия), B = позиции 3–9 (урон и лечение).
	assert_bool(_has(a, &"knight")).is_true()
	assert_bool(_has(a, &"stormmage")).is_false()
	assert_bool(_has(b, &"knight")).is_false()
	assert_bool(_has(b, &"stormmage")).is_true()
	assert_str(a.title).is_not_equal(b.title)
	assert_str(a.difference).is_not_equal(b.difference)


func test_rosters_differ_symmetrically() -> void:
	var a := _ids(DataLibrary.load_roster("a"))
	var b := _ids(DataLibrary.load_roster("b"))
	var only_a := _difference(a, b).size()
	assert_int(only_a).is_greater(0)
	assert_int(_difference(b, a).size()).is_equal(only_a)


## Юнит пула, которого нет ни в одном наборе, — мёртвый груз: он генерится,
## валидируется и никогда не выходит на поле.
func test_every_pool_unit_plays() -> void:
	var covered := {}
	for roster in DataLibrary.load_rosters():
		for stats in roster.units:
			covered[stats.id] = true
	var missing: Array[String] = []
	for id in DataLibrary.load_units():
		if id != DataLibrary.ENEMY_ID and not covered.has(id):
			missing.append(String(id))
	assert_str(", ".join(missing)).is_empty()


func test_enemy_is_not_in_the_pool() -> void:
	var units := DataLibrary.load_units()
	for roster in DataLibrary.load_rosters():
		for stats in roster.units:
			assert_str(String(stats.id)).is_not_equal(String(DataLibrary.ENEMY_ID))
	assert_bool(units.has(DataLibrary.ENEMY_ID)).is_true()


func _has(roster: RosterData, id: StringName) -> bool:
	for stats in roster.units:
		if stats.id == id:
			return true
	return false


func _ids(roster: RosterData) -> Array:
	var ids: Array = []
	for stats in roster.units:
		ids.append(stats.id)
	return ids


func _difference(left: Array, right: Array) -> Array:
	var kept: Array = []
	for id in left:
		if not right.has(id):
			kept.append(id)
	return kept

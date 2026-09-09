extends GdUnitTestSuite

func _city(faction: City.Faction, population: int) -> City:
	var c := City.new()
	c.faction = faction
	for i in population:
		c.add_migrant(PopUnit.State.WORKER, 0)
	return c

func test_max_boroughs_default_ratio() -> void:
	var c := _city(City.Faction.DEFAULT, 5)
	assert_int(BoroughRules.max_boroughs(c)).is_equal(2)

func test_max_boroughs_necrophage_wide_ratio() -> void:
	var c := _city(City.Faction.NECROPHAGE, 5)
	assert_int(BoroughRules.max_boroughs(c)).is_equal(5)

func test_cost_grows_with_existing_boroughs() -> void:
	var c := _city(City.Faction.DEFAULT, 0)
	var first := BoroughRules.cost(c)
	var b := Borough.new()
	c.boroughs.append(b)
	assert_float(BoroughRules.cost(c)).is_greater(first)

func test_can_level_up_requires_neighbors() -> void:
	var c := _city(City.Faction.DEFAULT, 0)
	var b := Borough.new()
	b.level = 1
	c.boroughs.append(b)
	assert_bool(BoroughRules.can_level_up(c, b)).is_false()

func test_can_level_up_with_four_same_level_neighbors() -> void:
	var c := _city(City.Faction.DEFAULT, 0)
	var center := Vector2i(5, 5)
	var b := Borough.new()
	b.cell = center
	b.level = 1
	c.boroughs.append(b)
	for nb in HexUtils.get_all_neighbors(center):
		var n := Borough.new()
		n.cell = nb
		n.level = 1
		c.boroughs.append(n)
	assert_int(BoroughRules.same_level_neighbors(c, b)).is_equal(6)
	assert_bool(BoroughRules.can_level_up(c, b)).is_true()

func test_can_level_up_blocked_at_max_level() -> void:
	var c := _city(City.Faction.DEFAULT, 0)
	var b := Borough.new()
	b.level = GameNumbers.BOROUGH_MAX_LEVEL
	c.boroughs.append(b)
	assert_bool(BoroughRules.can_level_up(c, b)).is_false()

func test_process_level_ups_cascades() -> void:
	var c := _city(City.Faction.CULTISTS, 0)
	var center := Vector2i(5, 5)
	var b := Borough.new()
	b.cell = center
	b.level = 1
	c.boroughs.append(b)
	for nb in HexUtils.get_all_neighbors(center):
		var n := Borough.new()
		n.cell = nb
		n.level = 1
		c.boroughs.append(n)
	var raised := BoroughRules.process_level_ups(c)
	assert_int(raised).is_greater(0)
	assert_int(b.level).is_greater(1)

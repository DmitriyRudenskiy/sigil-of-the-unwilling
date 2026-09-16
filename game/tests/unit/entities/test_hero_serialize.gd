extends BaseTest



func test_army_serialize() -> void:
	var army = auto_free( HeroArmyController.new())
	var data = army.serialize()

	assert_int(data.size()).is_equal(army.army.size()).override_failure_message("serialize: entry count mismatch")

	var army2 = auto_free( HeroArmyController.new())
	army2.deserialize(data)

	assert_int(army2.army.size()).is_equal(army.army.size()).override_failure_message("deserialize: stack count mismatch")

	for i in army.army.size():
		assert_int(army2.army[i].count).is_equal(army.army[i].count).override_failure_message("count mismatch at index %d" % i)

	army.free()
	army2.free()

func test_resources_roundtrip() -> void:
	var res = auto_free( HeroResources.new())
	res.resources = {
		ResourceType.ID.WOOD: 100,
		ResourceType.ID.GOLD: 999,
		ResourceType.ID.GEMS: 42,
	}

	var data = res.serialize()
	assert_int(data["wood"]).is_equal(100).override_failure_message("serialize: wood should be 100")
	assert_int(data["gold"]).is_equal(999).override_failure_message("serialize: gold should be 999")

	var res2 = auto_free( HeroResources.new())
	res2.deserialize(data)

	assert_int(res2.resources[ResourceType.ID.WOOD]).is_equal(100).override_failure_message("deserialize: wood should be 100")
	assert_int(res2.resources[ResourceType.ID.GEMS]).is_equal(42).override_failure_message("deserialize: gems should be 42")

	res.free()
	res2.free()

func test_army_empty() -> void:
	var army = auto_free( HeroArmyController.new())
	army.army = [] as Array[UnitStack]  # duck-typed through Variant: no auto-convert

	var data = army.serialize()
	assert_int(data.size()).is_zero().override_failure_message("empty army should serialize to empty array")

	var army2 = auto_free( HeroArmyController.new())
	army2.deserialize(data)
	assert_int(army2.army.size()).is_zero().override_failure_message("empty deserialize should result in empty army")

	army.free()
	army2.free()

func test_army_cap() -> void:
	var army = auto_free( HeroArmyController.new())
	for i in 12:
		army.army.append(Units.make_fixed_stack("swordsmen", 10))

	var for_battle = army.get_army_for_battle()
	assert_int(for_battle.size()).is_equal(7).override_failure_message("get_army_for_battle should cap at 7")

	army.free()

func test_default_army_cap() -> void:
	var army = auto_free( HeroArmyController.new())
	var for_battle = army.get_army_for_battle()
	assert_int(for_battle.size()).is_less_equal(7).override_failure_message("default army should not exceed 7 units")

	army.free()

# --- social-stats-weapon-tech: миграция старого сейва (4 стата -> 8) ---

func test_stats_migration_old_save_gets_social_stats() -> void:
	var comp := HeroStatsComponent.new()
	comp.hero_race = "elf"
	comp.hero_class = "wizard"
	# старый формат: только 4 боевых стата
	var data := {
		"hero_name": "Old",
		"stats": {"attack": 5, "defense": 2, "spell_power": 8, "knowledge": 4},
		"hero_race": "elf", "hero_class": "wizard",
		"hero_culture": "aedyr", "hero_background": "scholar",
	}
	comp.deserialize(data)
	# elf +wis 1, wizard +wis 1 +int 1, scholar +int 1, aedyr +cha 1 -> от base 2
	assert_int(comp.stats["attack"]).is_equal(5)
	assert_int(comp.stats["wis"]).is_equal(4)
	assert_int(comp.stats["int"]).is_equal(4)
	assert_int(comp.stats["cha"]).is_equal(3)
	assert_int(comp.stats["luk"]).is_equal(2)

func test_stats_migration_new_save_untouched() -> void:
	var comp := HeroStatsComponent.new()
	var data := {
		"hero_name": "New",
		"stats": {"attack": 5, "defense": 2, "spell_power": 8, "knowledge": 4,
			"int": 7, "wis": 9, "cha": 3, "luk": 6},
		"hero_race": "elf", "hero_class": "wizard",
		"hero_culture": "aedyr", "hero_background": "scholar",
	}
	comp.deserialize(data)
	assert_int(comp.stats["int"]).is_equal(7)
	assert_int(comp.stats["wis"]).is_equal(9)
	assert_int(comp.stats["cha"]).is_equal(3)
	assert_int(comp.stats["luk"]).is_equal(6)

func test_stats_roundtrip_8_stats() -> void:
	var comp := HeroStatsComponent.new()
	comp.apply_build((func() -> HeroBuildProfile:
		var p := HeroBuildProfile.new()
		p.name = "X"; p.race = "dwarf"; p.character_class = "barbarian"
		p.culture = "aedyr"; p.background = "soldier"
		return p
	).call())
	var data := comp.serialize()
	var comp2 := HeroStatsComponent.new()
	comp2.deserialize(data)
	assert_dict(comp2.stats).is_equal(comp.stats)

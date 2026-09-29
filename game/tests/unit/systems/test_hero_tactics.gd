extends BaseTest

# Phase 9: тактические проявления классов и расы героя (HeroTactics).
# Чистые функции бонусов + glue: боец-герой несёт тег класса И расы.

func _unit(tags: Array) -> BattleState.BattleUnit:
	var stats := UnitStats.new("hero", "Герой", 5, 5, 1, 3, 3, tags)
	var u := BattleState.BattleUnit.new(UnitStack.new(stats, 10))
	u.side = BattleState.Side.ATTACKER
	u.max_count = 10
	return u

func _hero() -> HeroController:
	var h := TestFactories.make_hero(&"rebel")
	h.max_combat_hp = 20
	h.set_combat_hp(20)
	return h

# 9.1 Следопыт: +движение в лесу.
func test_ranger_forest_movement_bonus() -> void:
	var ranger := _unit(["ranger"])
	assert_int(HeroTactics.movement_bonus(ranger, HexTerrain.TerrainType.FOREST)).is_equal(HeroTactics.RANGER_FOREST_SPEED)
	assert_int(HeroTactics.movement_bonus(ranger, HexTerrain.TerrainType.PLAIN)).is_equal(0)
	# Не-следопыт бонуса не получает.
	assert_int(HeroTactics.movement_bonus(_unit(["goblin"]), HexTerrain.TerrainType.FOREST)).is_equal(0)

# 9.1 Воин: +атака с фронта.
func test_fighter_front_attack_bonus() -> void:
	var fighter := _unit(["fighter"])
	assert_int(HeroTactics.front_attack_bonus(fighter, HeroTactics.ASPECT_FRONT)).is_equal(HeroTactics.FIGHTER_FRONT_BONUS)
	assert_int(HeroTactics.front_attack_bonus(fighter, 1)).is_equal(0)   # фланг
	assert_int(HeroTactics.front_attack_bonus(fighter, -1)).is_equal(0)  # дальнобой
	# Не-воин бонуса не получает.
	assert_int(HeroTactics.front_attack_bonus(_unit(["ranger"]), HeroTactics.ASPECT_FRONT)).is_equal(0)

# 9.2 Дварф: +защита на холмах.
func test_dwarf_hill_defense_mult() -> void:
	var dwarf := _unit(["dwarf"])
	assert_float(HeroTactics.hill_defense_mult(dwarf, HexTerrain.TerrainType.HILL)).is_equal_approx(HeroTactics.DWARF_HILL_DEF_MULT, 0.0001)
	assert_float(HeroTactics.hill_defense_mult(dwarf, HexTerrain.TerrainType.PLAIN)).is_equal_approx(1.0, 0.0001)
	# Не-дварф множителя не получает.
	assert_float(HeroTactics.hill_defense_mult(_unit(["elf"]), HexTerrain.TerrainType.HILL)).is_equal_approx(1.0, 0.0001)

# 9.2 Эльф: +крит в лесу.
func test_elf_forest_crit_bonus() -> void:
	var elf := _unit(["elf"])
	assert_float(HeroTactics.forest_crit_bonus(elf, HexTerrain.TerrainType.FOREST)).is_equal_approx(HeroTactics.ELF_FOREST_CRIT, 0.0001)
	assert_float(HeroTactics.forest_crit_bonus(elf, HexTerrain.TerrainType.PLAIN)).is_equal_approx(0.0, 0.0001)
	# Не-эльф бонуса не получает.
	assert_float(HeroTactics.forest_crit_bonus(_unit(["dwarf"]), HexTerrain.TerrainType.FOREST)).is_equal_approx(0.0, 0.0001)

# Null-безопасность: все бонусы нулевые/нейтральные.
func test_null_unit_no_bonus() -> void:
	assert_int(HeroTactics.movement_bonus(null, HexTerrain.TerrainType.FOREST)).is_equal(0)
	assert_int(HeroTactics.front_attack_bonus(null, HeroTactics.ASPECT_FRONT)).is_equal(0)
	assert_float(HeroTactics.hill_defense_mult(null, HexTerrain.TerrainType.HILL)).is_equal_approx(1.0, 0.0001)
	assert_float(HeroTactics.forest_crit_bonus(null, HexTerrain.TerrainType.FOREST)).is_equal_approx(0.0, 0.0001)

# Glue: боец-герой несёт тег класса И расы (HeroController -> HeroTactics).
func test_hero_stack_carries_race_tag() -> void:
	var h := _hero()
	h.hero_class = "fighter"
	h.hero_race = "dwarf"
	var stack: UnitStack = h.get_hero_battle_stack()
	assert_bool(stack.stats.has_tag("fighter")).is_true()
	assert_bool(stack.stats.has_tag("dwarf")).is_true()
	h.free()

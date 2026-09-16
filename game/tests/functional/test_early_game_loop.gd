extends BaseTest

# Ранняя игра: E2E цикл «соло-старт → ресурсы → выгрузка → казармы →
# рекрутка → бой с волками» (early-game-foundation, фаза 5).


func _main_root() -> Node:
	return Engine.get_main_loop().root


func _city_with_barracks() -> City:
	var c := City.new()
	c.display_name = "Стартовый город"
	c.center = Vector2i(10, 10)
	c.level = 2
	c.storage[&"industry"] = 100.0
	c.storage[&"silver"] = 100.0
	var bld := UniqueBuilding.new()
	bld.def = BuildingDefs.def_by_id(&"barracks")
	bld.level = 1
	bld.cell = Vector2i(11, 10)
	c.buildings.append(bld)
	return c


func _solo_hero() -> HeroController:
	var hero := TestFactories.make_hero()
	_main_root().add_child(hero)
	hero.get_army().setup(Services.resolve(&"units"), true)
	return hero


func test_full_early_game_loop() -> void:
	# 1. Соло-старт: армия пуста, герой дерется лично
	var hero := _solo_hero()
	assert_int(hero.get_army().army.size()).is_equal(0)
	var fighter := hero.get_hero_battle_stack()
	assert_bool(fighter != null and fighter.count >= 1).is_true()

	# 2. Сбор ресурсов: рюкзак с общим лимитом
	var collected := hero.add_strategic_resource(&"oak", 6)
	assert_int(collected).is_equal(6)
	assert_int(hero.strategic_resources.total()).is_equal(6)
	assert_int(hero.add_strategic_resource(&"silver", 6)).is_equal(6)
	assert_int(hero.strategic_resources.total()).is_equal(12)

	# 3. Город: выгрузка рюкзака в хранилище
	var city := _city_with_barracks()
	var screen: CityScreen = load("res://scenes/ui/CityScreen.tscn").instantiate() as CityScreen
	_main_root().add_child(screen)
	screen.setup(city, hero, Vector2i(10, 10), TestFactories.seeded(1))
	var unload: CityCheck = screen.unload_pressed()
	assert_bool(unload.ok).is_true()
	assert_int(hero.strategic_resources.total()).is_equal(0)
	assert_float(float(city.storage.get(&"oak", 0.0))).is_equal(6.0)

	# 4. Рекрутка: казармы + серебро из хранилища → отряд в армии
	var barracks: UniqueBuilding = city.buildings[0]
	CityService.set_rng(TestFactories.seeded(1))
	var recruit: CityCheck = CityService.recruit_military(city, barracks, hero)
	assert_bool(recruit.ok).is_true()
	assert_int(hero.get_army().army.size()).is_equal(1)
	var sword: UnitStack = hero.get_army().army[0]
	assert_that(sword.get_key()).is_equal("swordsmen")

	# 5. Бой с волками из 1-го кольца: герой + рекруты побеждают
	var reg: Node = Services.resolve(&"units")
	var wolf_rng := TestFactories.seeded(3)
	var wolves: UnitStack = reg.make_stack("wolves", wolf_rng)
	assert_bool(wolves != null and wolves.is_alive()).is_true()
	var result: Dictionary = BattleEmulator.new().emulate_battle({
		"attacker_army": [
			{"id": "hero", "attack": fighter.stats.attack, "base_damage": fighter.stats.base_damage,
			 "hp": fighter.stats.hp, "speed": fighter.stats.speed, "defense": fighter.stats.defense,
			 "count": fighter.count},
			{"id": sword.get_key(), "attack": sword.stats.attack, "base_damage": sword.stats.base_damage,
			 "hp": sword.stats.hp, "speed": sword.stats.speed, "defense": sword.stats.defense,
			 "count": sword.count},
		],
		"defender_army": [
			{"id": "wolves", "attack": wolves.stats.attack, "base_damage": wolves.stats.base_damage,
			 "hp": wolves.stats.hp, "speed": wolves.stats.speed, "defense": wolves.stats.defense,
			 "count": wolves.count},
		],
	})
	assert_bool(result.has("winner")).is_true()
	assert_that(result.get("winner")).is_equal("attacker")

	screen.free()
	hero.free()

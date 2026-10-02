extends BaseTest
## scarce-crafting-system 3.2/4.2: прогресс крафта переживает save/load
## через SaveData.hero.crafting (v8). Плюс трофей боя → сырьё.

var _mock_nodes: Array[Node] = []


func before_test() -> void:
	_mock_nodes.clear()


func after_test() -> void:
	for n in _mock_nodes:
		if is_instance_valid(n):
			n.free()
	_mock_nodes.clear()


func _make_hero() -> HeroController:
	var host := Node.new()
	add_child(host)
	_mock_nodes.append(host)
	var hero := HeroController.new()
	host.add_child(hero)
	# В игре компоненты инициализируются в setup(map); в тесте — явно
	# (без MapGenerator). Strategic-ресурсы — из реестра.
	hero.get_component("StrategicResources").initialize()
	hero.get_component("Inventory").initialize()
	hero.crafting_comp.initialize()
	return hero


func test_craft_progress_roundtrip_through_hero() -> void:
	var hero := _make_hero()
	# Сырьё для железного меча (tech 2, workshop).
	var strategic: HeroStrategicResourcesComponent = hero.get_component("StrategicResources")
	strategic.add(&"bog_iron", 3)
	strategic.add(&"coal", 1)

	# Город с кузницей и tech 2.
	var city := _make_city_with_smithy(2)

	var res: Dictionary = hero.crafting_comp.craft(&"iron_sword_crafted", city)
	assert_that(bool(res["ok"])).is_true()
	assert_that(hero.crafting_comp.is_unlocked(&"iron_sword_crafted")).is_true()
	assert_that(hero.inventory_comp.inventory.backpack.size()).is_equal(1)

	# SAVE: герой сериализует компонент Crafting.
	var saved: Dictionary = hero.serialize()
	assert_that(saved.has("crafting")).is_true()
	var unlocked: Array = saved["crafting"]["unlocked"]
	assert_that(unlocked.has("iron_sword_crafted")).is_true()

	# LOAD: новый герой, десериализация.
	var hero2 := _make_hero()
	hero2.deserialize(saved)
	assert_that(hero2.crafting_comp.is_unlocked(&"iron_sword_crafted")).is_true()
	# Инвентарь с предметом тоже сохранён (через Inventory-компонент).
	assert_that(hero2.inventory_comp.inventory.backpack.size()).is_equal(1)
	var art: Artifact = hero2.inventory_comp.inventory.backpack[0]
	assert_that(str(art.id)).is_equal("iron_sword_crafted")
	assert_that(art.weight).is_equal(2.0)


func test_legacy_hero_save_without_crafting_key() -> void:
	var hero := _make_hero()
	var saved: Dictionary = hero.serialize()
	saved.erase("crafting")  # эмуляция v7-сейва

	var hero2 := _make_hero()
	hero2.deserialize(saved)
	# Без ключа — пустой unlocked, крафт доступен с нуля.
	assert_that(hero2.crafting_comp.is_unlocked(&"wooden_shield")).is_false()
	var strategic: HeroStrategicResourcesComponent = hero2.get_component("StrategicResources")
	strategic.add(&"wood", 4)
	strategic.add(&"oak", 2)
	var res: Dictionary = hero2.crafting_comp.craft(&"wooden_shield")
	assert_that(bool(res["ok"])).is_true()


func test_save_data_v7_to_v8_migration() -> void:
	# v7-сейв: hero без crafting-ключа.
	var data := SaveData.new()
	data.version = 7
	data.run_seed = 42
	data.hero = {"cell": {"x": 1, "y": 2}, "move_points": 5}
	var dict := data.to_dict()
	dict["version"] = 7

	var loaded := SaveData.new()
	loaded.from_dict(dict)
	assert_that(loaded.version).is_equal(SaveData.CURRENT_VERSION)
	assert_that(loaded.version).is_equal(8)
	# Миграция добавила пустой crafting.
	assert_that(loaded.hero.has("crafting")).is_true()
	assert_that(loaded.hero["crafting"]).is_equal({})


func test_battle_trophy_grants_strategic_resource() -> void:
	var hero := _make_hero()
	var strategic: HeroStrategicResourcesComponent = hero.get_component("StrategicResources")
	var before: Dictionary = strategic.get_all()

	var trophy: Dictionary = BattleTrophyService.roll_trophy()
	strategic.add(trophy["resource"], int(trophy["amount"]))

	var after: Dictionary = strategic.get_all()
	var res_id: StringName = trophy["resource"]
	assert_that(int(after[res_id]) - int(before.get(res_id, 0))).is_equal(int(trophy["amount"]))
	assert_that(BattleTrophyService.TROPHY_RESOURCES.has(res_id)).is_true()


## T17/D2: трофеи детерминированы (последовательность от счётчика).
func test_battle_trophy_deterministic_sequence() -> void:
	BattleTrophyService.reset_for_tests()
	var t1: Dictionary = BattleTrophyService.roll_trophy()
	BattleTrophyService.reset_for_tests()
	var t2: Dictionary = BattleTrophyService.roll_trophy()
	assert_that(t1).is_equal(t2)


func _make_city_with_smithy(smithy_level: int) -> City:
	var city := City.new()
	city.level = 3  # fallback tech 1
	# tech 2: smithy + bog_iron/coal в хранилище (WeaponTechService).
	city.storage[&"bog_iron"] = 1.0
	city.storage[&"coal"] = 1.0
	var b := UniqueBuilding.new()
	b.def = UniqueBuilding.Def.new()
	b.def.id = &"smithy"
	b.level = smithy_level
	city.buildings.append(b)
	return city

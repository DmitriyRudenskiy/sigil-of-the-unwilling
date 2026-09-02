extends "res://tests/test_base.gd"
## succession-sigil: смерть героя → выбор преемника → наследование легенды.
## Чистые unit-тесты SuccessionController / City.can_resurrect / SaveData v4.

const _Succession = preload("res://scripts/world/SuccessionController.gd")
const _City = preload("res://scripts/world/City.gd")
const _CityManager = preload("res://scripts/world/CityManager.gd")
const _Follower = preload("res://scripts/entities/Follower.gd")
const _Hero = preload("res://scripts/entities/HeroController.gd")
const _Artifact = preload("res://scripts/data/Artifact.gd")
const _SaveData = preload("res://scripts/core/SaveData.gd")

func _make_follower(uid: int, path: StringName) -> Follower:
	var f := _Follower.new()
	f.uid = uid
	f.name = "F%d" % uid
	f.path = path
	return f


func _make_hero(path := &"archivist") -> HeroController:
	var h := _Hero.new()
	h.path_id = path
	h.magic.spellbook = [&"firebolt", &"heal"]
	h.magic.schools = {&"air": 1, &"fire": 2}
	h.magic.mana_current = 10
	h.magic.mana_max = 20
	# Инвентарь: артефакт в рюкзаке + надетое оружие.
	var ring := _Artifact.new(&"ring_of_might", &"Ring of Might", _Artifact.Slot.RING_L,
		_Artifact.Rarity.MINOR, {}, &"mana_regen", false, 100, "")
	h.inventory.backpack.append(ring)
	var blade := _Artifact.new(&"blade_of_light", &"Blade of Light", _Artifact.Slot.WEAPON,
		_Artifact.Rarity.MAJOR, {}, &"", false, 250, "")
	h.inventory.equipped[_Artifact.Slot.WEAPON] = blade
	# Стратегические ресурсы.
	h.strategic_resources.add(&"wood", 100)
	h.strategic_resources.add(&"stone", 50)
	return h


func _make_city(uid: int, name: StringName, is_capital: bool) -> City:
	var c := _City.new()
	c.uid = uid
	c.display_name = name
	c.is_capital = is_capital
	# Boroughs / buildings / roads / pop / food / storage.
	c.boroughs.append({"name": name, "buildings": []})
	var ub := UniqueBuilding.new()
	ub.def = UniqueBuilding.Def.new()
	ub.def.id = &"great_temple"
	ub.level = 2
	c.buildings.append(ub)
	c.food_stockpile = 80.0
	c.storage = {"industry": 600.0, "gold": 150.0}
	return c


# ==================== ВЫБОР ПРЕЕМНИКА ====================

func test_select_returns_same_path_follower() -> void:
	var h := _make_hero(&"archivist")
	var f1 := _make_follower(1, &"archivist")
	var f2 := _make_follower(2, &"archivist")
	h.followers = [f1, f2]

	var succ := _Succession.new().select_successor(h)
	assert_not_null(succ, "selected a same-path follower")
	assert_eq(succ.path, &"archivist", "successor shares the path")
	h.free()


func test_select_never_different_path() -> void:
	var h := _make_hero(&"archivist")
	var same := _make_follower(1, &"archivist")
	var other := _make_follower(2, &"warrior")
	h.followers = [same, other]

	var succ := _Succession.new().select_successor(h)
	assert_not_null(succ, "ignored different-path followers")
	assert_eq(succ.path, &"archivist", "never picks a different-path follower")
	h.free()


func test_select_null_when_no_eligible() -> void:
	var h := _make_hero(&"archivist")
	var other := _make_follower(3, &"warrior")
	h.followers = [other]

	var succ := _Succession.new().select_successor(h)
	assert_null(succ, "no eligible follower → null")
	h.free()


func test_select_null_when_no_followers() -> void:
	var h := _make_hero(&"archivist")
	h.followers = []
	var succ := _Succession.new().select_successor(h)
	assert_null(succ, "no followers → null")
	h.free()


# ==================== ПОСТРОЕНИЕ ПРЕЕМНИКА ====================

func test_build_copies_path_magic_inventory() -> void:
	var h := _make_hero(&"archivist")
	var succ := _Succession.new().build_successor(h)
	assert_not_null(succ, "successor built")
	assert_eq(succ.path_id, &"archivist", "path_id inherited")
	assert_eq(succ.magic.spellbook, [&"firebolt", &"heal"], "spellbook inherited")
	assert_eq(succ.magic.schools, {&"air": 1, &"fire": 2}, "magic schools inherited")
	assert_eq(succ.magic.mana_current, 10, "mana inherited")
	# Инвентарь: глубокая копия (не тот же объект).
	assert_true(succ.inventory.backpack.size() == 1, "backpack item inherited")
	assert_true(succ.inventory.backpack[0] != h.inventory.backpack[0], "artifact deep-copied")
	assert_true(succ.inventory.equipped[_Artifact.Slot.WEAPON] != h.inventory.equipped[_Artifact.Slot.WEAPON],
		"equipped artifact deep-copied")
	assert_eq(succ.strategic_resources.get_all(), h.strategic_resources.get_all(), "strategic resources inherited")
	h.free(); succ.free()


# ==================== ПЕРЕНОС ГОРОДОВ ====================

func test_transfer_preserves_cities_identical() -> void:
	var src := _make_city(1, &"Riverport", false)
	var cap := _make_city(2, &"Highhold", true)
	var other := _make_city(3, &"Gravewater", false)
	var cities: Array[City] = [src, cap, other]

	var h := _make_hero(&"archivist")
	var succ := _Succession.new().build_successor(h)

	var mgr := _CityManager.new()
	mgr.set_capital(cap)
	mgr.current_turn = 12
	mgr.add_glory(40.0, &"victory")
	for c in cities:
		mgr.register_city(c)

	# Перенос на тот же менеджер (тот же мир) — города остаются, capital/glory/turn intact.
	_Succession.new().transfer_legend(h, succ, cities, mgr)

	assert_eq(mgr.cities.size(), 3, "cities preserved after succession")
	var cap_after: City = mgr.get("capital")
	assert_not_null(cap_after, "capital preserved")
	assert_eq(cap_after.is_capital, true, "capital is_capital flag intact")
	assert_eq(mgr.current_turn, 12, "current_turn preserved")

	var total_storage := 0.0
	for c in mgr.cities:
		total_storage += float(c.storage.get("industry", 0.0))
	assert_approx(total_storage, 1800.0, 0.01, "storage preserved across succession")
	h.free(); succ.free(); mgr.free()


func test_transfer_reregisters_fresh_manager() -> void:
	var cap := _make_city(2, &"Highhold", true)
	var cities: Array[City] = [cap]
	var h := _make_hero(&"archivist")
	var succ := _Succession.new().build_successor(h)

	var dest := _CityManager.new()
	_Succession.new().transfer_legend(h, succ, cities, dest)

	assert_eq(dest.cities.size(), 1, "city re-registered on new manager")
	var re_cap: City = dest.get("capital")
	assert_not_null(re_cap, "capital set on new manager")
	assert_true(re_cap != cap, "re-registered as a fresh copy (not same object)")
	h.free(); succ.free(); dest.free()


# ==================== ВОСКРЕШЕНИЕ ====================

func test_resurrect_requires_temple_and_resources() -> void:
	# Без великого храма — нельзя.
	var no_temple := _make_city(1, &"Village", false)
	no_temple.buildings = []
	no_temple.storage = {"industry": 999.0, "gold": 999.0}
	assert_false(_Succession.new().resurrect_hero(no_temple), "no temple → cannot resurrect")

	# Храм уровня 2, ресурсов хватает.
	var temple := _make_city(2, &"TempleTown", true)
	assert_true(_Succession.new().resurrect_hero(temple), "temple + resources → resurrect")
	# Респисаны (industry 500, gold 100).
	assert_approx(temple.storage.get("industry", 0.0), 100.0, 0.01, "industry spent")
	assert_approx(temple.storage.get("gold", 0.0), 50.0, 0.01, "gold spent")

	# Ресурсов мало — нельзя.
	var poor := _make_city(3, &"PoorTown", true)
	poor.storage = {"industry": 100.0, "gold": 10.0}
	assert_false(_Succession.new().resurrect_hero(poor), "insufficient resources → cannot resurrect")


# ==================== ОРКЕСТРАЦИЯ СМЕРТИ ====================

func test_on_hero_died_returns_successor() -> void:
	var h := _make_hero(&"archivist")
	var f := _make_follower(1, &"archivist")
	h.followers = [f]

	var cap := _make_city(2, &"Highhold", true)
	var cities: Array[City] = [cap]
	var mgr := _CityManager.new()
	mgr.register_city(cap)

	var controller := _Succession.new()
	var succ := controller.on_hero_died(h, null, cities, mgr)
	assert_not_null(succ, "successor produced on death")
	assert_eq(succ.path_id, &"archivist", "successor path matches")
	assert_eq(mgr.cities.size(), 1, "cities still owned after succession")
	h.free(); succ.free(); mgr.free()


func test_on_hero_died_null_when_no_follower() -> void:
	var h := _make_hero(&"archivist")
	h.followers = []
	var empty_cities: Array[City] = []
	var controller := _Succession.new()
	var succ := controller.on_hero_died(h, null, empty_cities, null)
	assert_null(succ, "no follower → no successor (run ends)")
	h.free()


# ==================== СЕРИАЛИЗАЦИЯ: SAVE v4 ====================

func test_save_roundtrip_v4() -> void:
	var d := _SaveData.new()
	d.run_seed = 12345
	d.hero = {"cell": {"x": 3, "y": 4}, "path_id": "archivist"}
	d.successor = {"path": "archivist", "name": "Lyra"}
	d.legend = {"path_id": "archivist", "level": 3, "glory": 120.0}

	var data := d.to_dict()
	assert_eq(data["version"], 5, "save version is 5")

	var d2 := _SaveData.new()
	d2.from_dict(data)
	assert_eq(d2.version, 5, "loaded version 5")
	assert_eq(d2.hero.get("path_id"), "archivist", "hero path_id preserved")
	assert_eq(d2.successor.get("path"), "archivist", "successor preserved")
	assert_eq(d2.legend.get("level"), 3, "legend level preserved")


func test_migrate_v3_to_v4_defaults() -> void:
	# v3-сейв без successor/legend.
	var v3 := {"version": 3, "run_seed": 99,
		"hero": {"cell": {"x": 1, "y": 1}, "path_id": "archivist"},
		"world": {}, "cities": [], "characters": []}
	var d := _SaveData.new()
	d.from_dict(v3)
	assert_eq(d.version, 5, "v3 migrated to current (v5)")
	assert_true(d.successor is Dictionary, "successor defaulted to dict")
	assert_true(d.legend is Dictionary, "legend defaulted to dict")
	assert_eq(d.run_seed, 99, "run_seed preserved through migration")

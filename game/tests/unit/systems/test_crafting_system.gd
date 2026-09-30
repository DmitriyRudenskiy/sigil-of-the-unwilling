extends BaseTest

## scarce-crafting-system: CraftingSystem — схема, валидация, отказы крафта,
## вес результата, roundtrip. Headless (RefCounted, без сцены).

var _sys: CraftingSystem = null


func before_test() -> void:
	_sys = CraftingSystem.new()


func after_test() -> void:
	_sys = null


func _strategic(res: Dictionary = {}) -> HeroStrategicResources:
	var s := HeroStrategicResources.new()
	s._resources = {}
	for k in res:
		s._resources[StringName(k)] = int(res[k])
	return s


func _ctx(s: HeroStrategicResources, inv: HeroInventory,
		tech: int = 1, workshop: bool = false) -> CraftingSystem.CraftingContext:
	var ctx := CraftingSystem.CraftingContext.new()
	ctx.strategic = s
	ctx.inventory = inv
	ctx.tech_tier = tech
	ctx.has_workshop = workshop
	return ctx


# ─── Загрузка и валидация ───────────────────────────────

func test_loads_ten_recipes_from_json() -> void:
	var n := _sys.load_recipes()
	assert_int(n).is_equal(10)
	assert_int(_sys.get_recipes().size()).is_equal(10)


func test_recipes_cover_all_strategic_resources() -> void:
	_sys.load_recipes()
	var covered: Dictionary = {}
	for r in _sys.get_recipes():
		var recipe: CraftingSystem.CraftingRecipe = r
		for res_id in recipe.resources:
			covered[res_id] = true
	# Все 13 стратегических ресурсов используются хотя бы в одном рецепте.
	for id in [&"oak", &"silver", &"quartz", &"saltpeter", &"turquoise", &"limonite",
			&"coal", &"gold_ore", &"coal_swamp", &"bog_iron", &"cinnabar", &"wood", &"stone"]:
		assert_bool(covered.has(id)).is_true()


func test_missing_file_returns_zero() -> void:
	var n := _sys.load_recipes("res://data/config/does_not_exist.json")
	assert_int(n).is_equal(0)


func test_invalid_resource_skipped_with_error() -> void:
	var path := "res://user/test_crafting_bad_resource.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://user"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"recipes": [
		{"id": "good", "display_name": "OK", "slot": "MISC_A", "weight": 1.0,
		 "resources": {"wood": 1}},
		{"id": "bad", "display_name": "Bad", "slot": "MISC_A", "weight": 1.0,
		 "resources": {"unobtainium": 1}},
	]}))
	f.close()
	var n := _sys.load_recipes(path)
	assert_int(n).is_equal(1)
	assert_bool(_sys.get_recipe(&"bad") == null).is_true()
	assert_bool(_sys.get_recipe(&"good") != null).is_true()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_duplicate_id_skipped() -> void:
	var path := "res://user/test_crafting_dup.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://user"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"recipes": [
		{"id": "x", "display_name": "A", "slot": "MISC_A", "weight": 1.0,
		 "resources": {"wood": 1}},
		{"id": "x", "display_name": "B", "slot": "MISC_A", "weight": 1.0,
		 "resources": {"stone": 1}},
	]}))
	f.close()
	var n := _sys.load_recipes(path)
	assert_int(n).is_equal(1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_bad_slot_and_weight_rejected() -> void:
	var path := "res://user/test_crafting_bad_fields.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://user"))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"recipes": [
		{"id": "s", "display_name": "S", "slot": "GARGARATH", "weight": 1.0,
		 "resources": {"wood": 1}},
		{"id": "w", "display_name": "W", "slot": "MISC_A", "weight": 0.0,
		 "resources": {"wood": 1}},
	]}))
	f.close()
	var n := _sys.load_recipes(path)
	assert_int(n).is_equal(0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# ─── Отказы крафта ──────────────────────────────────────

func test_cannot_craft_without_resources() -> void:
	_sys.load_recipes()
	var ctx := _ctx(_strategic({}), HeroInventory.new(), 5, true)
	var check := _sys.can_craft(&"rune_sword_crafted", ctx)
	assert_bool(bool(check["ok"])).is_false()
	assert_str(str(check["reason"])).is_equal("missing_resources")
	var missing: Array = check["missing"]
	assert_bool(missing.has(&"cinnabar")).is_true()
	assert_bool(missing.has(&"bog_iron")).is_true()


func test_cannot_craft_without_tech() -> void:
	_sys.load_recipes()
	var s := _strategic({&"bog_iron": 10, &"quartz": 10, &"cinnabar": 10, &"gold_ore": 10})
	var ctx := _ctx(s, HeroInventory.new(), 4, true)
	var check := _sys.can_craft(&"rune_sword_crafted", ctx)
	assert_bool(bool(check["ok"])).is_false()
	assert_str(str(check["reason"])).is_equal("tech_required")


func test_cannot_craft_without_workshop() -> void:
	_sys.load_recipes()
	var s := _strategic({&"bog_iron": 10, &"coal": 10})
	var ctx := _ctx(s, HeroInventory.new(), 5, false)
	var check := _sys.can_craft(&"iron_sword_crafted", ctx)
	assert_bool(bool(check["ok"])).is_false()
	assert_str(str(check["reason"])).is_equal("workshop_required")


func test_field_recipe_no_workshop_needed() -> void:
	_sys.load_recipes()
	var s := _strategic({&"wood": 4, &"oak": 2})
	var ctx := _ctx(s, HeroInventory.new(), 1, false)
	var check := _sys.can_craft(&"wooden_shield", ctx)
	assert_bool(bool(check["ok"])).is_true()


func test_unknown_recipe_rejected() -> void:
	_sys.load_recipes()
	var ctx := _ctx(_strategic({}), HeroInventory.new())
	var check := _sys.can_craft(&"nonexistent", ctx)
	assert_bool(bool(check["ok"])).is_false()
	assert_str(str(check["reason"])).is_equal("unknown_recipe")


func test_failed_craft_does_not_consume_resources() -> void:
	_sys.load_recipes()
	var s := _strategic({&"bog_iron": 1})  # нужно 3
	var ctx := _ctx(s, HeroInventory.new(), 5, true)
	var res := _sys.craft(&"iron_sword_crafted", ctx)
	assert_bool(bool(res["ok"])).is_false()
	assert_int(int(s.get_all()[&"bog_iron"])).is_equal(1)


# ─── Успех крафта ───────────────────────────────────────

func test_craft_success_consumes_and_adds_item() -> void:
	_sys.load_recipes()
	var s := _strategic({&"bog_iron": 5, &"coal": 2})
	var inv := HeroInventory.new()
	var ctx := _ctx(s, inv, 2, true)
	var res := _sys.craft(&"iron_sword_crafted", ctx)
	assert_bool(bool(res["ok"])).is_true()
	var art: Artifact = res["artifact"]
	assert_bool(art != null).is_true()
	assert_int(int(s.get_all()[&"bog_iron"])).is_equal(2)  # 5 - 3
	assert_int(int(s.get_all()[&"coal"])).is_equal(1)      # 2 - 1
	assert_int(inv.backpack.size()).is_equal(1)
	assert_bool(_sys.is_unlocked(&"iron_sword_crafted")).is_true()


func test_craft_result_weight_matches_recipe() -> void:
	_sys.load_recipes()
	var s := _strategic({&"wood": 4, &"oak": 2})
	var inv := HeroInventory.new()
	var ctx := _ctx(s, inv, 1, false)
	var res := _sys.craft(&"wooden_shield", ctx)
	var art: Artifact = res["artifact"]
	assert_float(art.weight).is_equal(2.0)
	# Вес учтён в LoadCalculator.
	assert_float(LoadCalculator.equipment_weight(inv)).is_equal(2.0)


func test_craft_result_slot_and_tier() -> void:
	_sys.load_recipes()
	var s := _strategic({&"bog_iron": 6, &"quartz": 4, &"cinnabar": 3, &"gold_ore": 2})
	var inv := HeroInventory.new()
	var ctx := _ctx(s, inv, 5, true)
	var res := _sys.craft(&"rune_sword_crafted", ctx)
	var art: Artifact = res["artifact"]
	assert_int(int(art.slot)).is_equal(int(Artifact.Slot.WEAPON))
	assert_int(art.tier).is_equal(5)
	assert_int(int(art.rarity)).is_equal(int(Artifact.Rarity.RELIC))


func test_backpack_full_rolls_back_resources() -> void:
	_sys.load_recipes()
	var s := _strategic({&"wood": 4, &"oak": 2})
	var inv := HeroInventory.new()
	inv.backpack.resize(HeroInventory.MAX_BACKPACK)
	for i in HeroInventory.MAX_BACKPACK:
		inv.backpack[i] = Artifact.new(&"filler_%d" % i)
	var ctx := _ctx(s, inv, 1, false)
	var res := _sys.craft(&"wooden_shield", ctx)
	assert_bool(bool(res["ok"])).is_false()
	assert_str(str(res["reason"])).is_equal("backpack_full")
	# Откат: ресурсы на месте.
	assert_int(int(s.get_all()[&"wood"])).is_equal(4)
	assert_int(int(s.get_all()[&"oak"])).is_equal(2)
	assert_int(inv.backpack.size()).is_equal(HeroInventory.MAX_BACKPACK)


func test_item_crafted_signal_emitted() -> void:
	_sys.load_recipes()
	var emitted: Array = []
	_sys.item_crafted.connect(func(rid: StringName, _a: Artifact) -> void:
		emitted.append(rid))
	var s := _strategic({&"wood": 4, &"oak": 2})
	var ctx := _ctx(s, HeroInventory.new(), 1, false)
	_sys.craft(&"wooden_shield", ctx)
	assert_int(emitted.size()).is_equal(1)
	assert_str(str(emitted[0])).is_equal("wooden_shield")


# ─── Сейв/лоад ──────────────────────────────────────────

func test_serialize_deserialize_roundtrip() -> void:
	_sys.load_recipes()
	_sys.unlocked[&"wooden_shield"] = true
	_sys.unlocked[&"iron_sword_crafted"] = true
	var data: Dictionary = _sys.serialize()
	var sys2 := CraftingSystem.new()
	sys2.load_recipes()
	sys2.deserialize(data)
	assert_bool(sys2.is_unlocked(&"wooden_shield")).is_true()
	assert_bool(sys2.is_unlocked(&"iron_sword_crafted")).is_true()
	assert_bool(sys2.is_unlocked(&"rune_sword_crafted")).is_false()


func test_deserialize_old_save_empty() -> void:
	_sys.load_recipes()
	_sys.deserialize({})  # v7-сейв без ключа crafting → default
	assert_int(_sys.unlocked.size()).is_equal(0)


func test_deserialize_unknown_id_ignored() -> void:
	_sys.load_recipes()
	_sys.deserialize({"unlocked": ["wooden_shield", "not_a_recipe"]})
	assert_bool(_sys.is_unlocked(&"wooden_shield")).is_true()
	assert_int(_sys.unlocked.size()).is_equal(1)

extends BaseTest

# social-stats-weapon-tech: WeaponCatalog + WeaponTechService (D4)

const WeaponTechService = preload("res://scripts/systems/weapon_tech_service.gd")
const WeaponCatalog = preload("res://scripts/systems/weapon_catalog.gd")

func _city(level: int, storage: Dictionary = {}) -> City:
	var c := City.new()
	c.level = level
	for k in storage:
		c.storage[k] = storage[k]
	return c

func _with_smithy(c: City, level: int = 1) -> City:
	var b := UniqueBuilding.new()
	b.def = BuildingDefs.smithy()
	b.level = level
	c.buildings.append(b)
	return c

func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

# --- tier ladder ---

func test_fallback_by_city_level() -> void:
	assert_int(WeaponTechService.city_weapon_tier(_city(1))).is_equal(1)
	assert_int(WeaponTechService.city_weapon_tier(_city(5))).is_equal(2)
	assert_int(WeaponTechService.city_weapon_tier(_city(9))).is_equal(3)

func test_no_smithy_no_iron_even_at_level_9() -> void:
	# lvl 9 без технологий: fallback 3, железо не дается
	var c := _city(9, {"bog_iron": 5.0, "coal": 5.0, "gold_ore": 5.0, "quartz": 5.0, "cinnabar": 5.0})
	assert_int(WeaponTechService.city_weapon_tier(c, -1)).is_equal(3)

func test_smithy_iron_coal_gives_tier_2() -> void:
	var c := _city(1, {"bog_iron": 1.0, "coal": 1.0})
	_with_smithy(c)
	assert_int(WeaponTechService.city_weapon_tier(c)).is_equal(2)

func test_no_coal_no_iron() -> void:
	var c := _city(1, {"bog_iron": 5.0})
	_with_smithy(c)
	assert_int(WeaponTechService.city_weapon_tier(c)).is_equal(1)

func test_steel_gold_quartz_cinnabar_ladder() -> void:
	var c := _city(1, {"bog_iron": 1.0, "coal": 1.0, "gold_ore": 1.0})
	_with_smithy(c)
	assert_int(WeaponTechService.city_weapon_tier(c)).is_equal(3)
	c.storage["quartz"] = 1.0
	assert_int(WeaponTechService.city_weapon_tier(c)).is_equal(4)
	c.storage["cinnabar"] = 1.0
	assert_int(WeaponTechService.city_weapon_tier(c)).is_equal(5)

func test_tech_cannot_go_below_fallback() -> void:
	# lvl 9 (fallback 3) + только железо -> 3, не 2
	var c := _city(9, {"bog_iron": 1.0, "coal": 1.0})
	_with_smithy(c)
	assert_int(WeaponTechService.city_weapon_tier(c)).is_equal(3)

func test_hired_smithy_at_level_5() -> void:
	# без здания, lvl 5, cha 20, rep 20: найм кузнеца (DC 14) почти всегда успех
	WeaponTechService.set_rng(_rng(1))
	var c := _city(5, {"bog_iron": 1.0, "coal": 1.0})
	var hi: int = WeaponTechService.city_weapon_tier(c, 20)
	assert_bool(hi >= 2)
	# cha 2, rep -20: отказ -> fallback
	WeaponTechService.set_rng(_rng(1))
	var c2 := _city(5, {"bog_iron": 1.0, "coal": 1.0})
	var lo: int = WeaponTechService.city_weapon_tier(c2, 2)
	assert_int(lo).is_equal(2)

# --- catalog ---

func test_catalog_weights_per_tier() -> void:
	assert_float(WeaponCatalog.item_weight("club")).is_equal(1.0)
	assert_float(WeaponCatalog.item_weight("iron_sword")).is_equal(2.0)
	assert_float(WeaponCatalog.item_weight("steel_longsword")).is_equal(1.8)
	assert_float(WeaponCatalog.item_weight("runic_blade")).is_equal(2.5)
	assert_float(WeaponCatalog.item_weight("rune_sword")).is_equal(2.5)

func test_catalog_damage_ladder() -> void:
	assert_int(WeaponCatalog.item_damage("club")).is_equal(4)
	assert_int(WeaponCatalog.item_damage("iron_sword")).is_equal(6)
	assert_int(WeaponCatalog.item_damage("steel_longsword")).is_equal(8)
	assert_int(WeaponCatalog.item_damage("runic_blade")).is_equal(10)
	assert_int(WeaponCatalog.item_damage("rune_sword")).is_equal(13)

func test_best_item_per_tier() -> void:
	assert_bool(WeaponCatalog.best_item(1) == "club" or WeaponCatalog.best_item(1) == "stone_axe")
	assert_that(WeaponCatalog.best_item(2)).is_equal("iron_sword")
	assert_that(WeaponCatalog.best_item(5)).is_equal("rune_sword")

# --- forge ---

func test_forge_unknown_item() -> void:
	var out := WeaponTechService.forge("nonexistent", {})
	assert_bool(bool(out.get("ok", false)) == false)

func test_forge_produces_artifact_with_tier_and_weight() -> void:
	WeaponTechService.set_rng(_rng(7))
	var out := WeaponTechService.forge("iron_sword", {"int": 10, "wis": 10, "cha": 10, "luk": 10})
	assert_bool(bool(out.get("ok", true)))
	var art: Artifact = out["artifact"]
	assert_int(art.tier).is_equal(2)
	assert_bool(art.weight >= 1.0)
	assert_bool(art.weight <= 3.0)
	assert_that(art.display_name).is_equal("Железный меч")

func test_forge_wis_guarantees_quality() -> void:
	# wis 20: 50% notice; прогон — качество никогда не падает ниже 1.0 чаще, чем без wis
	var min_q_wis: float = 99.0
	for seed in 30:
		WeaponTechService.set_rng(_rng(seed))
		var out := WeaponTechService.forge("club", {"int": 2, "wis": 20, "cha": 2, "luk": 2})
		min_q_wis = minf(min_q_wis, float(out["quality"]))
	assert_bool(min_q_wis >= 0.8)

func test_forge_luk_boosts_quality() -> void:
	var boosted: int = 0
	for seed in 40:
		WeaponTechService.set_rng(_rng(seed))
		var out := WeaponTechService.forge("club", {"int": 10, "wis": 2, "cha": 2, "luk": 20})
		if float(out["quality"]) > 1.2:
			boosted += 1
	assert_bool(boosted >= 1)

func test_forge_cha_discount() -> void:
	WeaponTechService.set_rng(_rng(3))
	var hi := WeaponTechService.forge("club", {"int": 10, "wis": 2, "cha": 16, "luk": 2})
	assert_float(float(hi["discount"])).is_equal(0.1)
	var lo := WeaponTechService.forge("club", {"int": 10, "wis": 2, "cha": 10, "luk": 2})
	assert_float(float(lo["discount"])).is_equal(0.0)

func test_forge_determinism() -> void:
	WeaponTechService.set_rng(_rng(42))
	var a := WeaponTechService.forge("runic_blade", {"int": 12, "wis": 14, "cha": 16, "luk": 10})
	WeaponTechService.set_rng(_rng(42))
	var b := WeaponTechService.forge("runic_blade", {"int": 12, "wis": 14, "cha": 16, "luk": 10})
	assert_float(float(a["quality"])).is_equal(float(b["quality"]))
	assert_bool(a["notes"].size() == b["notes"].size())

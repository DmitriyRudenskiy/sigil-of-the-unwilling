extends BaseTest

# social-stats-weapon-tech: WeaponCatalog + WeaponTechService (D4)

const WeaponTechService = preload("res://scripts/systems/WeaponTechService.gd")
const WeaponCatalog = preload("res://scripts/systems/WeaponCatalog.gd")

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
	assert_int(WeaponTechService.city_weapon_tier(_city(5))).is_equal(3)
	assert_int(WeaponTechService.city_weapon_tier(_city(9))).is_equal(4)

func test_no_smithy_no_iron_even_at_level_9() -> void:
	# lvl 9 без технологий: fallback 4, железо не дается
	var c := _city(9, {"bog_iron": 5.0, "coal": 5.0, "gold_ore": 5.0, "quartz": 5.0, "cinnabar": 5.0})
	assert_int(WeaponTechService.city_weapon_tier(c, -1)).is_equal(4)

func test_smithy_iron_coal_gives_tier_3() -> void:
	var c := _city(1, {"bog_iron": 1.0, "coal": 1.0})
	_with_smithy(c)
	assert_int(WeaponTechService.city_weapon_tier(c)).is_equal(3)

func test_no_coal_no_iron() -> void:
	var c := _city(1, {"bog_iron": 5.0})
	_with_smithy(c)
	assert_int(WeaponTechService.city_weapon_tier(c)).is_equal(1)

func test_steel_gold_quartz_ladder() -> void:
	var c := _city(1, {"bog_iron": 1.0, "coal": 1.0, "gold_ore": 1.0})
	_with_smithy(c)
	assert_int(WeaponTechService.city_weapon_tier(c)).is_equal(4)
	c.storage["quartz"] = 1.0
	assert_int(WeaponTechService.city_weapon_tier(c)).is_equal(5)
	# киноварь (легенда) в новой лестнице не нужна: 5 = редкое/магия
	c.storage["cinnabar"] = 1.0
	assert_int(WeaponTechService.city_weapon_tier(c)).is_equal(5)

func test_tech_cannot_go_below_fallback() -> void:
	# lvl 9 (fallback 4) + только железо -> 4, не 3
	var c := _city(9, {"bog_iron": 1.0, "coal": 1.0})
	_with_smithy(c)
	assert_int(WeaponTechService.city_weapon_tier(c)).is_equal(4)

func test_hired_smithy_at_level_5() -> void:
	# без здания, lvl 5, cha 20, rep 20: найм кузнеца (DC 14) почти всегда успех
	WeaponTechService.set_rng(_rng(1))
	var c := _city(5, {"bog_iron": 1.0, "coal": 1.0})
	var hi: int = WeaponTechService.city_weapon_tier(c, 20)
	assert_bool(hi >= 3)
	# cha 2, rep -20: отказ -> fallback
	WeaponTechService.set_rng(_rng(1))
	var c2 := _city(5, {"bog_iron": 1.0, "coal": 1.0})
	var lo: int = WeaponTechService.city_weapon_tier(c2, 2)
	assert_int(lo).is_equal(3)

# --- catalog ---

func test_catalog_weights_per_tier() -> void:
	assert_float(WeaponCatalog.item_weight("club")).is_equal(1.0)
	assert_float(WeaponCatalog.item_weight("iron_sword")).is_equal(2.0)
	assert_float(WeaponCatalog.item_weight("steel_longsword")).is_equal(1.8)
	assert_float(WeaponCatalog.item_weight("runic_blade")).is_equal(2.5)
	assert_float(WeaponCatalog.item_weight("rune_sword")).is_equal(2.5)

func test_catalog_damage_ladder() -> void:
	assert_int(WeaponCatalog.item_damage("club")).is_equal(4)
	assert_int(WeaponCatalog.item_damage("stone_axe")).is_equal(5)
	assert_int(WeaponCatalog.item_damage("iron_sword")).is_equal(6)
	assert_int(WeaponCatalog.item_damage("steel_longsword")).is_equal(8)
	assert_int(WeaponCatalog.item_damage("runic_blade")).is_equal(13)
	assert_int(WeaponCatalog.item_damage("rune_sword")).is_equal(13)

func test_best_item_per_tier() -> void:
	assert_that(WeaponCatalog.best_item(1)).is_equal("club")
	assert_that(WeaponCatalog.best_item(2)).is_equal("stone_axe")
	assert_that(WeaponCatalog.best_item(3)).is_equal("iron_sword")
	var best5: String = WeaponCatalog.best_item(5)
	assert_bool(best5 == "runic_blade" or best5 == "rune_sword" or best5 == "unique_artifact")

# --- social-systems-delta: каталог по этапам ---

func test_catalog_at_least_6_per_stage() -> void:
	for tier in range(1, 6):
		var count: int = 0
		for id in WeaponCatalog.ITEMS:
			if int(WeaponCatalog.ITEMS[id]["tier"]) == tier:
				count += 1
		assert_bool(count >= 6).override_failure_message("этап %d: %d изделий" % [tier, count])

func test_catalog_items_have_type_and_purpose() -> void:
	var valid_types := ["bludgeoning", "piercing", "slashing", "throwing", "ranged", "defense"]
	for id in WeaponCatalog.ITEMS:
		var it: Dictionary = WeaponCatalog.ITEMS[id]
		assert_bool(valid_types.has(str(it.get("type", "")))).override_failure_message("type: " + str(id))
		assert_bool(str(it.get("purpose", "")).length() > 0).override_failure_message("purpose: " + str(id))

func test_stage_1_has_no_stone() -> void:
	# ТЗ: этап 1 — только дерево, каменное оружие недоступно
	for id in WeaponCatalog.ITEMS:
		var it: Dictionary = WeaponCatalog.ITEMS[id]
		if str(id).begins_with("stone_") or str(id) == "flint_arrows" or str(id) == "sling":
			assert_bool(int(it["tier"]) >= 2).override_failure_message("камень на этапе 1: " + str(id))

# --- social-systems-delta: требования переходов этапов ---

func test_stage_1_always_met() -> void:
	assert_bool(WeaponTechService.stage_requirements_met(_city(1), 1))

func test_stage_2_stone_and_wood() -> void:
	var c := _city(1)
	assert_bool(not WeaponTechService.stage_requirements_met(c, 2))
	c.storage["stone"] = 1.0
	assert_bool(not WeaponTechService.stage_requirements_met(c, 2))
	c.storage["wood"] = 1.0
	assert_bool(WeaponTechService.stage_requirements_met(c, 2))

func test_stage_3_smithy_coal_iron_smith() -> void:
	var c := _city(1, {"coal": 1.0, "bog_iron": 1.0})
	_with_smithy(c)
	assert_bool(not WeaponTechService.stage_requirements_met(c, 3))
	c.smith_hired = true
	assert_bool(WeaponTechService.stage_requirements_met(c, 3))

func test_stage_4_smithy_2() -> void:
	var c := _city(1)
	_with_smithy(c)
	assert_bool(not WeaponTechService.stage_requirements_met(c, 4))
	_with_smithy(c, 2)
	assert_bool(WeaponTechService.stage_requirements_met(c, 4))

func test_stage_5_quartz() -> void:
	var c := _city(1, {"quartz": 1.0})
	_with_smithy(c, 2)
	assert_bool(WeaponTechService.stage_requirements_met(c, 5))
	var c2 := _city(1)
	_with_smithy(c2, 2)
	assert_bool(not WeaponTechService.stage_requirements_met(c2, 5))

func test_try_hire_smith_sets_flag() -> void:
	# cha 20: d20 + 10 vs DC 14 — успех почти всегда; 20 сидов гарантируют попадание
	var hired: bool = false
	for seed in 20:
		var c := _city(5)
		if WeaponTechService.try_hire_smith(c, 20, _rng(seed)):
			hired = true
			assert_bool(c.smith_hired)
			# повторный вызов — сразу true, без броска
			assert_bool(WeaponTechService.try_hire_smith(c, 2, _rng(99)))
			break
	assert_bool(hired).override_failure_message("ни один из 20 сидов не нанял кузнеца")

# --- forge ---

func test_forge_unknown_item() -> void:
	var out := WeaponTechService.forge("nonexistent", {})
	assert_bool(bool(out.get("ok", false)) == false)

func test_forge_produces_artifact_with_tier_and_weight() -> void:
	WeaponTechService.set_rng(_rng(7))
	var out := WeaponTechService.forge("iron_sword", {"int": 10, "wis": 10, "cha": 10, "luk": 10})
	assert_bool(bool(out.get("ok", true)))
	var art: Artifact = out["artifact"]
	assert_int(art.tier).is_equal(3)
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

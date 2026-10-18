extends BaseTest
## T-020/T-021/T-022 — регион-граф кампании (K-T7, 02e1-base-map-v1): MVP-маска S1,
## туман (радиус 1, город всегда видим), движение по рёбрам (D-191, K-M4),
## one-time loot (Y4), SM героя, сейв (fail-fast).
## Данные — mvp_mask в movement.json (K-R4, единый источник).

func _make() -> RegionMap:
	var m := RegionMap.new()
	m.init_campaign(2, 600.0)
	return m


## — 1. Данные MVP-маски (movement.json → mvp_mask) —

func test_mvp_mask_loaded() -> void:
	var m := RegionMap.new()
	assert_bool(m.mask_id == "S1").override_failure_message("mask_id S1").is_true()
	assert_bool(m.start_region == "R01").is_true()
	assert_bool(m.regions.size() == 5).override_failure_message("5 регионов").is_true()
	assert_bool(str(m.biomes.get("R01", "")) == "plains").is_true()
	assert_bool(str(m.biomes.get("R04", "")) == "mountains").is_true()
	assert_bool(m.edges.size() == 4).override_failure_message("4 рёбра (линейный путь)").is_true()


func test_adjacency_symmetric() -> void:
	var m := RegionMap.new()
	# R01–R02–R03–R04–R05 (линейный путь).
	assert_bool(m.neighbors("R01") == ["R02"]).is_true()
	assert_bool(m.neighbors("R02") == ["R01", "R03"]).is_true()
	assert_bool(m.neighbors("R05") == ["R04"]).is_true()


## T-025: инвариант доходимости якорей 7/14/21 (K-M4) — граф связен.
func test_reachability_all_regions_from_start() -> void:
	var m := RegionMap.new()
	# Все 5 регионов MVP-маски достижимы из R01 (пусто = ок).
	assert_bool(m.unreachable_regions().is_empty()) \
		.override_failure_message("граф MVP-маски связен (якоря 7/14/21 достижимы)").is_true()


## — 2. Туман (Q-M54 → (а)): радиус 1, город всегда видим —

func test_fog_radius_1_on_start() -> void:
	var m := _make()
	# Старт R01: открыты R01 (город) + R02 (сосед).
	assert_bool(m.open_regions.has("R01")).is_true()
	assert_bool(m.open_regions.has("R02")).is_true()
	assert_bool(not m.open_regions.has("R03")).is_true()


func test_city_always_visible() -> void:
	var m := _make()
	m.travel("R02")
	# Город R01 остаётся видимым (в open_regions) после ухода.
	assert_bool(m.open_regions.has("R01")).is_true()


func test_fog_expands_on_travel() -> void:
	var m := _make()
	m.travel("R02")
	# Из R02 открыт R03 (сосед R02).
	assert_bool(m.open_regions.has("R03")).is_true()


## — 3. Движение (D-191, K-M4): рёберный шаг, еда 1/персонаж/переход —

func test_travel_edge_step() -> void:
	var m := _make()
	var r: Dictionary = m.travel("R02")
	assert_bool(bool(r.ok)).is_true()
	assert_bool(m.hero_region == "R02").is_true()
	# R02 = plains, entry_cost_days 1, party 2 → еда 2.
	assert_bool(int(r.days) == 1).is_true()
	assert_float(r.food_cost).is_equal_approx(2.0, 0.0001)
	assert_float(m.food).is_equal_approx(598.0, 0.0001)


func test_travel_non_neighbor_rejected() -> void:
	var m := _make()
	var r: Dictionary = m.travel("R03")  # R03 не сосед R01.
	assert_bool(bool(r.ok)).is_false()
	assert_bool(m.hero_region == "R01").is_true()


func test_travel_fog_rejected() -> void:
	var m := _make()
	# R02 открыт, R03 в тумане. Переход в R03 (не сосед) — reject.
	var r: Dictionary = m.travel("R03")
	assert_bool(bool(r.ok)).is_false()


func test_travel_food_insufficient() -> void:
	var m := RegionMap.new()
	m.init_campaign(2, 0.0)  # нет еды.
	var r: Dictionary = m.travel("R02")
	assert_bool(bool(r.ok)).is_false()
	assert_bool(m.hero_region == "R01").is_true()


func test_travel_mountain_cost() -> void:
	var m := _make()
	m.travel("R02")
	m.travel("R03")
	var r: Dictionary = m.travel("R04")  # R04 = mountains, entry 3 дня.
	assert_bool(bool(r.ok)).is_true()
	assert_bool(int(r.days) == 3).is_true()
	assert_float(r.food_cost).is_equal_approx(6.0, 0.0001)  # 2 × 3.


## — 4. One-time loot (Y4): первый визит — награда, второй — пусто —

func test_one_time_loot_ruin() -> void:
	var m := _make()
	m.travel("R02")
	m.travel("R03")  # R03 = ruin.
	var v1: Dictionary = m.visit_node("R03")
	assert_bool(bool(v1.looted)).is_true()
	assert_bool(int(v1.rewards.get("wood", 0)) == 10).is_true()
	assert_bool(int(v1.rewards.get("iron", 0)) == 5).is_true()
	assert_bool(int(v1.rewards.get("xp", 0)) == 300).is_true()
	# Второй визит — пусто.
	var v2: Dictionary = m.visit_node("R03")
	assert_bool(bool(v2.looted)).is_false()
	assert_bool(v2.rewards.size() == 0).is_true()


func test_loot_ore_and_camp() -> void:
	assert_bool(int(RegionMap.new().loot_catalog("ore").get("iron", 0)) == 20).is_true()
	assert_bool(int(RegionMap.new().loot_catalog("camp").get("xp", 0)) == 400).is_true()


func test_no_node_region() -> void:
	var m := _make()
	# R01 = город (нет узла в nodes).
	assert_bool(m.node_type("R01") == "").is_true()
	var v: Dictionary = m.visit_node("R01")
	assert_bool(bool(v.looted)).is_false()


## — 5. SM героя —

func test_sm_explore_to_engage() -> void:
	var m := _make()
	assert_bool(m.hero_state == RegionMap.STATE_EXPLORE).is_true()
	m.engage_battle()
	assert_bool(m.hero_state == RegionMap.STATE_ENGAGE).is_true()
	m.battle_victory()
	assert_bool(m.hero_state == RegionMap.STATE_VICTORY).is_true()
	m.resolve_battle()
	assert_bool(m.hero_state == RegionMap.STATE_EXPLORE).is_true()


func test_travel_blocked_in_engage() -> void:
	var m := _make()
	m.engage_battle()
	var r: Dictionary = m.travel("R02")
	assert_bool(bool(r.ok)).is_false()


## — 6. Отступление (Y10): авто-возврат за 1 день, без боёв —

func test_retreat_returns_to_city() -> void:
	var m := _make()
	m.travel("R02")
	m.travel("R03")
	m.engage_battle()
	var r: Dictionary = m.retreat()
	assert_bool(bool(r.ok)).is_true()
	assert_bool(m.hero_region == "R01").is_true()
	assert_bool(m.hero_state == RegionMap.STATE_EXPLORE).is_true()


## — 6b. FS (T-024): рейд по региону героя (поход) → бой; победа → −50% —

func test_field_raid_victory() -> void:
	var m := _make()
	m.travel("R02")
	var r: Dictionary = m.field_raid(true)
	assert_bool(bool(r.ok)).is_true()
	assert_bool(m.hero_state == RegionMap.STATE_VICTORY).is_true()


func test_field_raid_defeat() -> void:
	var m := _make()
	m.travel("R02")
	var r: Dictionary = m.field_raid(false)
	assert_bool(bool(r.ok)).is_true()
	assert_bool(m.hero_state == RegionMap.STATE_DEFEAT).is_true()


func test_field_raid_in_city_rejected() -> void:
	# Рейд по городу (R01) — через ThreatSystem (hero_in_city), не field_raid.
	var m := _make()
	var r: Dictionary = m.field_raid(true)
	assert_bool(not bool(r.ok)).is_true()


## — 7. Авто-режим (Y10): 2 дня без выбора → возврат в город —

func test_auto_mode_returns_to_city() -> void:
	var m := _make()
	m.travel("R02")
	m.tick_days(2)
	assert_bool(m.hero_region == "R01").is_true()
	assert_bool(m.days_without_choice == 0).is_true()


## — 8. Сейв (fail-fast) —

func test_save_roundtrip() -> void:
	var m := _make()
	m.travel("R02")
	m.travel("R03")
	m.visit_node("R03")
	var d: Dictionary = m.to_dict()
	var m2 := RegionMap.from_dict(d)
	assert_bool(m2.hero_region == "R03").is_true()
	assert_bool(m2.party_size == 2).is_true()
	assert_float(m2.food).is_equal_approx(m.food, 0.0001)
	assert_bool(m2.open_regions.has("R03")).is_true()
	assert_bool(m2.visited_nodes.size() == 1).is_true()


func test_save_version_mismatch_fail_fast() -> void:
	var m := _make()
	var d: Dictionary = m.to_dict()
	d["schema_version"] = 999
	var m2 := RegionMap.from_dict(d)
	# fail-fast: позиция не восстановлена (пусто).
	assert_bool(m2.hero_region == "").is_true()

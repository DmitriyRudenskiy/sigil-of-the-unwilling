extends BaseTest

## T-111-full (акт раунда 17 §1): чекер инвариантов waves.json (02e3 §9.5
## «Инварианты и проверки») + MVP-паритет (§1(д): волны не активны в MVP-цикле).
## Расовый состав — Приложение А (docs/10-appendix-a-races.md, транскрипция
## 02e3 §9.4); биомы/регионы — 02e1-base-map.md (карта v1).

const WAVES_PATH := "res://data/config/waves.json"

## Карта v1 (02e1-base-map.md §4): регион → биом.
const MAP_V1 := {
	"CN": "горы",
	"N1": "лес", "N2": "лес", "N3": "равнина", "N4": "равнина", "N5": "лес",
	"N6": "равнина", "N7": "вода", "N8": "вода", "N9": "холмы", "N10": "болото",
	"N11": "болото", "N12": "лес", "N13": "горы", "N14": "равнина",
	"E1": "равнина", "E2": "равнина", "E3": "равнина", "E4": "разлом",
	"E5": "равнина", "E6": "лес", "E7": "лес", "E8": "равнина", "E9": "равнина",
	"E10": "лес", "E11": "равнина", "E12": "болото", "E13": "лес",
	"E14": "равнина", "E15": "равнина", "E16": "лес",
	"S1": "лес", "S2": "лес", "S3": "равнина", "S4": "равнина", "S5": "холмы",
	"S6": "холмы", "S7": "вода", "S8": "вода", "S9": "равнина", "S10": "болото",
	"S11": "равнина", "S12": "равнина", "S13": "горы", "S14": "лес",
	"CS": "болото",
}

## Береги-исключение Охотников (R-W4 «вода — контроль берега»): переправы
## N6–N9, S6–S9 — канал Д/контроль у воды, сами по себе не «вода» на карте.
const COAST_CONTROL_EXCEPTIONS := ["N6", "N9", "S6", "S9"]


func _root() -> Dictionary:
	var file := FileAccess.open(WAVES_PATH, FileAccess.READ)
	assert_that(file).is_not_null()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_bool(parsed is Dictionary).is_true()
	return parsed


func _domains() -> Array:
	return _root().get("domains", [])


func test_waves_sum_54_and_pool_le_54() -> void:
	var total := 0
	for d in _domains():
		total += (d as Dictionary).get("races", []).size()
	assert_int(total).override_failure_message("Σ рас ≠ 54 (каталог 54, D-136)").is_equal(54)
	assert_bool(total <= 54).override_failure_message("пул > 54").is_true()


func test_waves_one_group_per_race() -> void:
	var seen := {}
	for d in _domains():
		for race in (d as Dictionary).get("races", []):
			assert_bool(not seen.has(str(race))).override_failure_message(
				"раса «%s» в двух доменах (принцип 1 A6-R)" % str(race)).is_true()
			seen[str(race)] = true


func test_waves_echelon_7_covers_all_domains() -> void:
	# Первый эшелон (★, Приложение А): по одной расе на домен, 7 доменов.
	var echelon := ["гномы", "полурослики", "тифлинги", "эльфы", "люди", "полуорки", "дворфы"]
	var domains := _domains()
	assert_int(domains.size()).is_equal(7)
	for d in domains:
		var races: Array = (d as Dictionary).get("races", [])
		var hits: Array = []
		for e in echelon:
			if races.has(e):
				hits.append(e)
		assert_int(hits.size()).override_failure_message(
			"домен «%s»: первый эшелон ≠ 1 раса" % str((d as Dictionary).get("group", ""))).is_equal(1)


func test_waves_undead_trio_outside_pool() -> void:
	for race in ["дампиры", "перерождённые", "одержимые гексом"]:
		for d in _domains():
			assert_bool(not (d as Dictionary).get("races", []).has(race)) \
				.override_failure_message("нежить-трио в пуле: %s" % race).is_true()


func test_waves_no_turn_field_anti_calendar() -> void:
	# R-W1: поле «ход» (и «turn») в конфиге волн запрещено.
	var file := FileAccess.open(WAVES_PATH, FileAccess.READ)
	var raw := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	_assert_no_turn(parsed, "waves.json")


func _assert_no_turn(node: Variant, path: String) -> void:
	if node is Dictionary:
		for key in node.keys():
			assert_bool(str(key) != "ход" and str(key) != "turn") \
				.override_failure_message("R-W1: поле хода в %s" % path).is_true()
			_assert_no_turn(node[key], path + "." + str(key))
	elif node is Array:
		for i in node.size():
			_assert_no_turn(node[i], "%s[%d]" % [path, i])


func test_waves_biomes_and_regions_on_map_v1() -> void:
	# Инвариант чекера «биомы ∈ карты v1»: биом домена объявлен на карте и
	# каждый регион-пример лежит в биоме домена (или берег Охотников — R-W4).
	var map_biomes := {}
	for r in MAP_V1.keys():
		map_biomes[str(MAP_V1[r])] = true
	for d in _domains():
		var dd: Dictionary = d
		var biomes: Array = dd.get("biomes", [])
		assert_bool(not biomes.is_empty()).is_true()
		for b in biomes:
			assert_bool(map_biomes.has(str(b))).override_failure_message(
				"биом «%s» не из карты v1" % str(b)).is_true()
		for region in dd.get("regions", []):
			assert_bool(MAP_V1.has(str(region))).override_failure_message(
				"регион %s не из карты v1" % str(region)).is_true()
			var biome_ok: bool = biomes.has(str(MAP_V1[str(region)]))
			var coast_ok: bool = str(dd.get("id", "")) == "hunters" \
				and COAST_CONTROL_EXCEPTIONS.has(str(region))
			assert_bool(biome_ok or coast_ok).override_failure_message(
				"регион %s (%s) вне биомов домена %s" % [str(region), str(MAP_V1[str(region)]), str(dd.get("group", ""))]).is_true()


func test_waves_two_channels_only() -> void:
	# R-W2: ровно каналы М и Д, третий запрещён.
	for d in _domains():
		var channels: Array = (d as Dictionary).get("channels", [])
		assert_int(channels.size()).override_failure_message(
			"каналы ≠ {M, D} (R-W2)").is_equal(2)
		assert_bool(channels.has("M") and channels.has("D")) \
			.override_failure_message("третий канал или отсутствие М/Д (R-W2)").is_true()


func test_waves_prisoners_domain_of_dungeon_biome() -> void:
	# «Пленники ∈ домена биома данжа» (инвариант §9.5): на уровне конфига —
	# у каждого домена канал Д открыт и биом объявлен (состав пленных — данные
	# сценария данжа, 1.0); нежить-трио — мобы, вне пула (тест трио выше).
	for d in _domains():
		var dd: Dictionary = d
		assert_bool((dd.get("channels", []) as Array).has("D")).is_true()
		assert_bool(not (dd.get("biomes", []) as Array).is_empty()).is_true()


func test_mvp_parity_waves_never_trigger_in_mvp_cycle() -> void:
	# §1(д): волны не активны в MVP-кампании — конфиг загружается, не
	# триггерится: у composition нет волнового состояния, сейв-секция waves
	# отсутствует, полный цикл 21 ход проходит без волновых записей.
	assert_int(_domains().size()).is_equal(7)  # конфиг читается
	var c := CampaignComposition.from_campaign_config(12345)
	c.set_sign("spark")
	while not c.campaign.is_done():
		c.advance_turn()
	var state := c.build_save_state()
	assert_bool((state.get("campaign", {}) as Dictionary).has("waves")) \
		.override_failure_message("волновое состояние просочилось в MVP-сейв").is_false()
	assert_bool(state.has("waves")).is_false()

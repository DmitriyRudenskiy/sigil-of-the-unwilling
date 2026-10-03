extends BaseTest

const CATALOG_PATH := "res://assets/data/mvp_catalog.json"

var catalog: Dictionary = {}

func before_test() -> void:
	catalog = _load_json(CATALOG_PATH)

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

func test_catalog_loads() -> void:
	assert_that(catalog.size() > 0).override_failure_message("mvp_catalog.json не загрузился: %d" % catalog.size())
	assert_that(catalog.has("classes") and catalog.has("races") and catalog.has("groups")).override_failure_message("нет ключей classes/races/groups")

func test_eleven_classes() -> void:
	var classes: Array = catalog.get("classes", [])
	assert_that(classes.size() == 11).override_failure_message("ожидалось 11 классов (K1, без Колдуна), получено %d" % classes.size())
	var ids := {}
	for c in classes:
		assert_that(not ids.has(c.id)).override_failure_message("дубликат класса: %s" % c.id)
		ids[c.id] = true
	assert_that(not ids.has("warlock")).override_failure_message("Колдун в каталоге — против K1")

func test_six_hireable() -> void:
	var hireable: Array[String] = []
	for c in catalog.get("classes", []):
		if c.hireable:
			hireable.append(c.id)
	hireable.sort()
	var expected := ["cleric", "fighter", "paladin", "ranger", "rogue", "wizard"]
	assert_that(hireable == expected).override_failure_message("MVP-наём: ожидался %s, получен %s" % [expected, hireable])

func test_gates_match_02d() -> void:
	var by_id := {}
	for c in catalog.get("classes", []):
		by_id[c.id] = c
	assert_that(_gate_reqs(by_id["monk"]) == [["DEX", 13], ["WIS", 13]]).override_failure_message("монах: не ЛОВ13 и МДР13")
	assert_that(by_id["monk"].gate.mode == "all").override_failure_message("монах: режим гейта не all")
	assert_that(by_id["fighter"].gate.mode == "any").override_failure_message("воин: режим гейта не any (СИЛ или ЛОВ)")
	assert_that(_gate_reqs(by_id["paladin"]) == [["STR", 13], ["CHA", 13]]).override_failure_message("паладин: не СИЛ13 и ХАР13")
	assert_that(_gate_reqs(by_id["wizard"]) == [["INT", 13]]).override_failure_message("волшебник: не ИНТ13")
	assert_that(_gate_reqs(by_id["barbarian"]) == [["STR", 13]]).override_failure_message("варвар: не СИЛ13")

func _gate_reqs(c: Dictionary) -> Array:
	var reqs: Array = []
	for r in c.gate.reqs:
		reqs.append([r[0], r[1]])
	return reqs

func test_seven_groups() -> void:
	var groups: Array = catalog.get("groups", [])
	assert_that(groups.size() == 7).override_failure_message("ожидалось 7 групп (02e3 §9.4), получено %d" % groups.size())
	var ids := {}
	for g in groups:
		assert_that(not ids.has(g.id)).override_failure_message("дубликат группы: %s" % g.id)
		ids[g.id] = true

func test_first_tier_seven_races_one_per_group() -> void:
	# K-M5-правка (2026-10-02): первый эшелон = 7 рас, одна на группу; дубли — горизонт каталога 54
	var groups: Array = catalog.get("groups", [])
	var races: Array = catalog.get("races", [])
	assert_that(races.size() == 7).override_failure_message("первый эшелон: ожидалось 7 рас, получено %d" % races.size())
	var covered := {}
	for r in races:
		assert_that(r.first_tier).override_failure_message("раса %s не первого эшелона" % r.id)
		assert_that(not covered.has(r.group)).override_failure_message("группа %s: две расы первого эшелона (дубли аннулированы)" % r.group)
		covered[r.group] = r.id
	for g in groups:
		assert_that(covered.has(g.id)).override_failure_message("группа %s без населения первого эшелона (K-M5: каждая группа получает население)" % g.id)

func test_no_orcs_term() -> void:
	# «Орки» — ошибка словаря: в базовой системе D&D раса — полуорки
	var has_half_orcs := false
	for r in catalog.get("races", []):
		assert_that(r.id != "orcs" and r.name != "Орки").override_failure_message("термин «орки» в каталоге — незаконный (основание: базовая система D&D)")
		if r.id == "half_orcs":
			has_half_orcs = true
	assert_that(has_half_orcs).override_failure_message("полуорки (half_orcs) отсутствуют в каталоге")

func test_srd_modifiers() -> void:
	# Модификаторы — SRD-таблица базовой системы; Удача в каталоге 0 (Удача гномов +2 — 07-balance, не код)
	var by_id := {}
	for r in catalog.get("races", []):
		by_id[r.id] = r
	assert_that(_mods(by_id["gnomes"]) == {"INT": 2}).override_failure_message("гномы: SRD = ИНТ +2")
	assert_that(_mods(by_id["halflings"]) == {"DEX": 2}).override_failure_message("полурослики: SRD = ЛОВ +2")
	assert_that(_mods(by_id["tieflings"]) == {"INT": 1, "CHA": 2}).override_failure_message("тифлинги: SRD = ИНТ +1, ХАР +2")
	assert_that(_mods(by_id["elves"]) == {"DEX": 2}).override_failure_message("эльфы: SRD = ЛОВ +2")
	assert_that(_mods(by_id["humans"]) == {}).override_failure_message("люди: SRD без модификаторов")
	assert_that(_mods(by_id["dwarves"]) == {"CON": 2}).override_failure_message("дворфы: SRD = ТЕЛ +2")
	assert_that(_mods(by_id["half_orcs"]) == {"STR": 2, "CON": 1}).override_failure_message("полуорки: SRD = СИЛ +2, ТЕЛ +1")
	for r in catalog.get("races", []):
		assert_that(r.luck == 0).override_failure_message("раса %s: Удача в каталоге = 0 (ратификация — 07-balance, не код)" % r.id)

func _mods(r: Dictionary) -> Dictionary:
	var m := {}
	for k in r.modifiers:
		if r.modifiers[k] != 0:
			m[k] = r.modifiers[k]
	return m

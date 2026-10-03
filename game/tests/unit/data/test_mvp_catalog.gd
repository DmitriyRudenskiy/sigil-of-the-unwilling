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
	assert_that(_gate_reqs(by_id["monk"]) == [["DEX", 13], ["WIS", 13]]).override_failure_message("монх: не ЛОВ13 и МДР13")
	assert_that(by_id["monk"].gate.mode == "all").override_failure_message("монх: режим гейта не all")
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

func test_first_tier_races() -> void:
	var defined: Array = []
	var group_ids := {}
	for g in catalog.get("groups", []):
		group_ids[g.id] = true
	for r in catalog.get("races", []):
		if r.first_tier:
			defined.append(r.id)
			assert_that(group_ids.has(r.group)).override_failure_message("раса %s: неизвестная группа %s" % [r.id, r.group])
	assert_that(defined.size() == 3).override_failure_message("определено %d рас первого эшелона, ожидалось 3 (02e3 §9.2)" % defined.size())
	var tbd: Dictionary = catalog.get("races_first_tier_tbd", {})
	assert_that(tbd.get("expected", 0) == 9).override_failure_message("первый эшелон: expected != 9")
	assert_that(tbd.get("defined", 0) == defined.size()).override_failure_message("races_first_tier_tbd.defined не совпадает с фактическим числом")

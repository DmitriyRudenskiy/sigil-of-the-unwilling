extends BaseTest
## T-113 (K1, 02d-classes-skills §2/§4.2): аксессор канон-классов (CanonClasses).
## Данные (11 классов, hireable-маска 6, гейты) — mvp_catalog.json, покрываются
## test_mvp_catalog.gd; здесь — поведение аксессора, которым пользуется конструктор.

func test_eleven_canon_classes_no_warlock() -> void:
	var ids: Array[String] = []
	for c in CanonClasses.classes():
		ids.append(str(c.get("id", "")))
	assert_bool(ids.size() == 11).override_failure_message("канон = 11 классов (K1), получено %d" % ids.size()).is_true()
	assert_bool(not ids.has("warlock")).override_failure_message("Колдун в каноне — против K1").is_true()
	assert_bool(ids.has("sorcerer")).override_failure_message("Чародей (sorcerer) — в каноне (1.0, hireable=false)").is_true()


func test_hireable_six_mvp_mask() -> void:
	var ids: Array[String] = []
	for c in CanonClasses.hireable():
		ids.append(str(c.get("id", "")))
	ids.sort()
	var expected := ["cleric", "fighter", "paladin", "ranger", "rogue", "wizard"]
	assert_bool(ids == expected).override_failure_message("MVP-наём: ожидался %s, получен %s" % [expected, ids]).is_true()


func test_canon_names_k1() -> void:
	assert_bool(CanonClasses.name_for("wizard") == "Волшебник").override_failure_message("«mage» = Волшебник (K1)").is_true()
	assert_bool(CanonClasses.name_for("cleric") == "Жрец").override_failure_message("cleric = Жрец (канон-имя)").is_true()
	assert_bool(CanonClasses.name_for("rogue") == "Плут").override_failure_message("rogue = Плут (канон-имя)").is_true()
	assert_bool(CanonClasses.name_for("fighter") == "Воин").override_failure_message("fighter = Воин (канон-имя)").is_true()
	assert_bool(CanonClasses.name_for("unknown_class") == "—").override_failure_message("неизвестный класс → «—»").is_true()


func test_gate_all_mode() -> void:
	assert_bool(CanonClasses.gate_ok("monk", {"DEX": 13, "WIS": 13})).override_failure_message("монах: ЛОВ13 и МДР13 — гейт пройден").is_true()
	assert_bool(not CanonClasses.gate_ok("monk", {"DEX": 13, "WIS": 12})).override_failure_message("монах: МДР12 < 13 — гейт (02d §4.2)").is_true()
	assert_bool(CanonClasses.gate_ok("cleric", {"WIS": 13})).override_failure_message("жрец: МДР13 — гейт пройден").is_true()


func test_gate_any_mode() -> void:
	assert_bool(CanonClasses.gate_ok("fighter", {"STR": 13})).override_failure_message("воин: СИЛ13 (any) — гейт пройден").is_true()
	assert_bool(CanonClasses.gate_ok("fighter", {"DEX": 13})).override_failure_message("воин: ЛОВ13 (any) — гейт пройден").is_true()
	assert_bool(not CanonClasses.gate_ok("fighter", {"STR": 12, "DEX": 12})).override_failure_message("воин: обе < 13 — гейт").is_true()


func test_gate_unknown_class() -> void:
	assert_bool(not CanonClasses.gate_ok("warlock", {"CHA": 13})).override_failure_message("неизвестный класс — гейт не пройден").is_true()

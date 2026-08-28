extends RefCounted
## Тесты валидации data/card_spells.json.
## Используют ядро валидатора как библиотеку.
##
## Запуск:
##   godot --headless -s tests/test_runner.gd
##   или standalone:
##   godot --headless -s tests/test_card_spells_json.gd

const _Validator = preload("res://tools/card_validation/CardSpellValidator.gd")

const JSON_PATH := "res://data/card_spells.json"

var _passed := 0
var _failed := 0
var _errors: Array = []
var validator

func _init() -> void:
	validator = _Validator.new()

# ==================== УТИЛИТЫ ====================

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		_fail("assert_eq failed: %s (got %s, expected %s)" % [msg, str(a), str(b)])
	else:
		_pass(msg)

func assert_true(val: bool, msg: String = "") -> void:
	if not val:
		_fail("assert_true failed: %s" % msg)
	else:
		_pass(msg)

func assert_false(val: bool, msg: String = "") -> void:
	if val:
		_fail("assert_false failed: %s" % msg)
	else:
		_pass(msg)

func _pass(msg: String) -> void:
	_passed += 1

func _fail(msg: String) -> void:
	_failed += 1
	_errors.append(msg)
	printerr("[FAIL] %s" % msg)

func get_results() -> String:
	var lines: Array = _errors.duplicate()
	lines.append("")
	lines.append("Results: %d passed, %d failed" % [_passed, _failed])
	if _failed == 0:
		lines.append("ALL TESTS PASSED")
	else:
		lines.append("SOME TESTS FAILED")
	return "\n".join(lines)

func _write(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()

# ==================== СТРУКТУРА ====================

func test_file_exists() -> void:
	assert_true(FileAccess.file_exists(JSON_PATH), "card_spells.json exists")

func test_file_is_valid_json() -> void:
	validator.validate_file(JSON_PATH)
	var has_parse_errors := false
	for issue in validator.report.issues:
		if issue.code.begins_with("E01"):
			has_parse_errors = true
	assert_false(has_parse_errors, "no JSON parse errors")

func test_no_structural_errors() -> void:
	validator.validate_file(JSON_PATH)
	var structural := 0
	for issue in validator.report.issues:
		if issue.code.begins_with("E1"):
			structural += 1
	assert_eq(structural, 0, "no structural errors")

func test_no_type_errors() -> void:
	validator.validate_file(JSON_PATH)
	var type_errors := 0
	for issue in validator.report.issues:
		if issue.code.begins_with("E2"):
			type_errors += 1
	assert_eq(type_errors, 0, "no type errors")

func test_no_value_errors() -> void:
	validator.validate_file(JSON_PATH)
	var value_errors := 0
	for issue in validator.report.issues:
		if issue.code.begins_with("E3"):
			value_errors += 1
	assert_eq(value_errors, 0, "no invalid-value errors")

func test_no_semantic_errors() -> void:
	validator.validate_file(JSON_PATH)
	var semantic := 0
	for issue in validator.report.issues:
		if issue.code.begins_with("E4"):
			semantic += 1
	assert_eq(semantic, 0, "no template-semantic errors")

func test_no_uniqueness_errors() -> void:
	validator.validate_file(JSON_PATH)
	var dup := 0
	for issue in validator.report.issues:
		if issue.code.begins_with("E5"):
			dup += 1
	assert_eq(dup, 0, "no uniqueness errors")

func test_overall_passes() -> void:
	var ok: bool = validator.validate_file(JSON_PATH)
	assert_true(ok, "overall validation passes")

# ==================== СОДЕРЖИМОЕ ====================

func test_spell_count() -> void:
	validator.validate_file(JSON_PATH)
	var count: int = int(validator.report.stats.get("spell_count", 0))
	assert_true(count > 0, "spell_count > 0 (actual: %d)" % count)

func test_all_ids_unique() -> void:
	validator.validate_file(JSON_PATH)
	# Если есть дубли — будет E500
	var dups := 0
	for issue in validator.report.issues:
		if issue.code == "E500":
			dups += 1
	assert_eq(dups, 0, "all ids unique")

func test_all_templates_present() -> void:
	validator.validate_file(JSON_PATH)
	var dist = validator.report.stats.get("template_distribution", {})
	for template in validator.TEMPLATES:
		assert_true(dist.has(template) and int(dist[template]) > 0,
			"template %s has spells" % template)

func test_average_cost_in_range() -> void:
	validator.validate_file(JSON_PATH)
	var avg: float = float(validator.report.stats.get("avg_cost", 0.0))
	assert_true(avg >= 1.0 and avg <= 5.0, "avg cost %.2f in [1.0, 5.0]" % avg)

# ==================== ОТРИЦАТЕЛЬНЫЕ КЕЙСЫ (юнит-тесты валидатора) ====================

func test_validator_catches_missing_field() -> void:
	var v = _Validator.new()
	var bad_json := JSON.stringify([
		{"id": "test", "name": "Test", "template": "DIRECT_DAMAGE",
		 "speed": "fast", "color": "fire"}
	])
	_write("user://test_missing_field.json", bad_json)
	v.validate_file("user://test_missing_field.json")
	var found := false
	for issue in v.report.issues:
		if issue.code == "E105":
			found = true
	assert_true(found, "detects missing cost")

func test_validator_catches_bad_template() -> void:
	var v = _Validator.new()
	var bad_json := JSON.stringify([
		{"id": "test", "name": "Test", "template": "NONEXISTENT",
		 "speed": "fast", "cost": 1, "color": "fire"}
	])
	_write("user://test_bad_template.json", bad_json)
	v.validate_file("user://test_bad_template.json")
	var found := false
	for issue in v.report.issues:
		if issue.code == "E302":
			found = true
	assert_true(found, "detects unknown template")

func test_validator_catches_bad_cost() -> void:
	var v = _Validator.new()
	var bad_json := JSON.stringify([
		{"id": "test", "name": "Test", "template": "DIRECT_DAMAGE",
		 "speed": "fast", "cost": 99, "color": "fire",
		 "params": {"amount": 2, "target": "ENEMY_UNIT"}}
	])
	_write("user://test_bad_cost.json", bad_json)
	v.validate_file("user://test_bad_cost.json")
	var found := false
	for issue in v.report.issues:
		if issue.code == "E304":
			found = true
	assert_true(found, "detects out-of-range cost")

func test_validator_catches_duplicate_id() -> void:
	var v = _Validator.new()
	var dup_json := JSON.stringify([
		{"id": "same", "name": "A", "template": "BOUNCE", "speed": "fast",
		 "cost": 1, "color": "fire", "params": {"target": "ALLY_UNIT"}},
		{"id": "same", "name": "B", "template": "BOUNCE", "speed": "fast",
		 "cost": 2, "color": "fire", "params": {"target": "ALLY_UNIT"}}
	])
	_write("user://test_dup_id.json", dup_json)
	v.validate_file("user://test_dup_id.json")
	var found := false
	for issue in v.report.issues:
		if issue.code == "E500":
			found = true
	assert_true(found, "detects duplicate id")

func test_validator_catches_missing_template_param() -> void:
	var v = _Validator.new()
	# DIRECT_DAMAGE требует amount, но его нет
	var bad_json := JSON.stringify([
		{"id": "dmg", "name": "Dmg", "template": "DIRECT_DAMAGE",
		 "speed": "fast", "cost": 2, "color": "fire",
		 "params": {"target": "ENEMY_UNIT"}}
	])
	_write("user://test_missing_param.json", bad_json)
	v.validate_file("user://test_missing_param.json")
	var found := false
	for issue in v.report.issues:
		if issue.code == "E400":
			found = true
	assert_true(found, "detects missing required param")

func test_validator_catches_bad_keyword() -> void:
	var v = _Validator.new()
	var bad_json := JSON.stringify([
		{"id": "kw", "name": "Kw", "template": "KEYWORD_BUFF",
		 "speed": "fast", "cost": 2, "color": "fire",
		 "params": {"keyword": "INVALID_KEYWORD"}}
	])
	_write("user://test_bad_keyword.json", bad_json)
	v.validate_file("user://test_bad_keyword.json")
	var found := false
	for issue in v.report.issues:
		if issue.code == "E321":
			found = true
	assert_true(found, "detects invalid keyword")

# ==================== BASELINE (DRIFT-ДЕТЕКЦИЯ) ====================

func test_baseline_matches_current_data() -> void:
	validator.validate_file(JSON_PATH)
	var built: Dictionary = validator.build_baseline()
	var committed: Dictionary = _Validator.load_baseline(_Validator.BASELINE_PATH)
	assert_true(not committed.is_empty(), "baseline file exists and parses")
	assert_eq(built.get("total", -1), committed.get("total", -2), "baseline total matches data")
	assert_eq(built.get("templates", {}), committed.get("templates", {}),
		"baseline template distribution matches data")

func test_baseline_drift_total_warns() -> void:
	var v = _Validator.new()
	_write("user://test_baseline_drift.json",
		JSON.stringify({"total": 42, "templates": {}}))
	v._baseline = _Validator.load_baseline("user://test_baseline_drift.json")
	v.validate_file(JSON_PATH)
	var found := false
	for issue in v.report.issues:
		if issue.code == "W920":
			found = true
	assert_true(found, "W920 raised when total differs from baseline")

func test_baseline_drift_template_warns() -> void:
	var v = _Validator.new()
	v.validate_file(JSON_PATH)
	var built: Dictionary = v.build_baseline()
	var templates: Dictionary = built["templates"].duplicate()
	templates["BOUNCE"] = 999
	_write("user://test_baseline_tpl.json",
		JSON.stringify({"total": built["total"], "templates": templates}))
	v._baseline = _Validator.load_baseline("user://test_baseline_tpl.json")
	v.validate_file(JSON_PATH)
	var found := false
	for issue in v.report.issues:
		if issue.code == "W921" and "BOUNCE" in issue.message:
			found = true
	assert_true(found, "W921 raised on per-template drift")

func test_baseline_save_load_roundtrip() -> void:
	var v = _Validator.new()
	v.validate_file(JSON_PATH)
	var before: Dictionary = v.build_baseline()
	assert_true(v.save_baseline("user://test_baseline_rt.json"),
		"save_baseline returns true")
	var after: Dictionary = _Validator.load_baseline("user://test_baseline_rt.json")
	assert_eq(after, before, "baseline roundtrip preserves data")

# ==================== W910 / W901 РЕГРЕССИИ ====================

func test_unconditional_suppresses_w910() -> void:
	var v = _Validator.new()
	_write("user://test_hr_uncond.json", JSON.stringify([
		{"id": "hr1", "name": "HR1", "template": "HARD_REMOVAL", "speed": "fast",
		 "cost": 4, "color": "shadow", "params": {"unconditional": true},
		 "description": "x"}
	]))
	v.validate_file("user://test_hr_uncond.json")
	var w910 := 0
	for issue in v.report.issues:
		if issue.code == "W910":
			w910 += 1
	assert_eq(w910, 0, "unconditional flag suppresses W910")

	_write("user://test_hr_plain.json", JSON.stringify([
		{"id": "hr2", "name": "HR2", "template": "HARD_REMOVAL", "speed": "fast",
		 "cost": 4, "color": "shadow", "params": {},
		 "description": "x"}
	]))
	v.validate_file("user://test_hr_plain.json")
	var w910b := 0
	for issue in v.report.issues:
		if issue.code == "W910":
			w910b += 1
	assert_eq(w910b, 1, "HARD_REMOVAL without condition/unconditional warns W910")

func test_duplicate_display_name_warns() -> void:
	var v = _Validator.new()
	_write("user://test_dup_name.json", JSON.stringify([
		{"id": "a1", "name": "Dismantle", "template": "DIRECT_DAMAGE", "speed": "fast",
		 "cost": 2, "color": "fire", "params": {"amount": 1, "target": "ENEMY_UNIT"}, "description": "x"},
		{"id": "b1", "name": "Dismantle", "template": "DIRECT_DAMAGE", "speed": "fast",
		 "cost": 3, "color": "fire", "params": {"amount": 2, "target": "ENEMY_UNIT"}, "description": "x"}
	]))
	v.validate_file("user://test_dup_name.json")
	var found := false
	for issue in v.report.issues:
		if issue.code == "W901":
			found = true
	assert_true(found, "duplicate display name warns W901")

func test_no_w901_or_w910_in_project_data() -> void:
	validator.validate_file(JSON_PATH)
	var bad := 0
	for issue in validator.report.issues:
		if issue.code == "W901" or issue.code == "W910":
			bad += 1
	assert_eq(bad, 0, "project data has no duplicate names or unmarked HARD_REMOVALs")

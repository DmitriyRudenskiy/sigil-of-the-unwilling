extends GdUnitTestSuite

const _Validator = preload("res://tests/spell_validation/SpellValidator.gd")

const JSON_PATH := "res://assets/data/spells.json"

var validator


func before() -> void:
	validator = _Validator.new()


func _write(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()


func test_file_exists() -> void:
	assert_bool(FileAccess.file_exists(JSON_PATH)).is_true()

func test_file_is_valid_json() -> void:
	validator.validate_file(JSON_PATH)
	var has_parse_errors := false
	for issue in validator.report.issues:
		if issue.code.begins_with("E01"):
			has_parse_errors = true
	assert_bool(has_parse_errors).is_false()

func test_no_structural_errors() -> void:
	validator.validate_file(JSON_PATH)
	var structural := 0
	for issue in validator.report.issues:
		if issue.code.begins_with("E1"):
			structural += 1
	assert_that(structural).is_equal(0)

func test_no_type_errors() -> void:
	validator.validate_file(JSON_PATH)
	var type_errors := 0
	for issue in validator.report.issues:
		if issue.code.begins_with("E2"):
			type_errors += 1
	assert_that(type_errors).is_equal(0)

func test_no_value_errors() -> void:
	validator.validate_file(JSON_PATH)
	var value_errors := 0
	for issue in validator.report.issues:
		if issue.code.begins_with("E3"):
			value_errors += 1
	assert_that(value_errors).is_equal(0)

func test_no_semantic_errors() -> void:
	validator.validate_file(JSON_PATH)
	var semantic := 0
	for issue in validator.report.issues:
		if issue.code.begins_with("E4"):
			semantic += 1
	assert_that(semantic).is_equal(0)

func test_no_uniqueness_errors() -> void:
	validator.validate_file(JSON_PATH)
	var dup := 0
	for issue in validator.report.issues:
		if issue.code.begins_with("E5"):
			dup += 1
	assert_that(dup).is_equal(0)

func test_overall_passes() -> void:
	var ok: bool = validator.validate_file(JSON_PATH)
	assert_bool(ok).is_true()


func test_spell_count() -> void:
	validator.validate_file(JSON_PATH)
	var count: int = int(validator.report.stats.get("spell_count", 0))
	assert_bool(count > 0).is_true()

func test_all_ids_unique() -> void:
	validator.validate_file(JSON_PATH)
	var dups := 0
	for issue in validator.report.issues:
		if issue.code == "E500":
			dups += 1
	assert_that(dups).is_equal(0)

func test_all_templates_present() -> void:
	validator.validate_file(JSON_PATH)
	var dist = validator.report.stats.get("template_distribution", {})
	for template in validator.TEMPLATES:
		assert_bool(dist.has(template) and int(dist[template]) > 0).is_true()

func test_average_cost_in_range() -> void:
	validator.validate_file(JSON_PATH)
	var avg: float = float(validator.report.stats.get("avg_cost", 0.0))
	assert_bool(avg >= 1.0 and avg <= 5.0).is_true()


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
	assert_bool(found).is_true()

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
	assert_bool(found).is_true()

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
	assert_bool(found).is_true()

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
	assert_bool(found).is_true()

func test_validator_catches_missing_template_param() -> void:
	var v = _Validator.new()
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
	assert_bool(found).is_true()

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
	assert_bool(found).is_true()


func test_baseline_matches_current_data() -> void:
	validator.validate_file(JSON_PATH)
	var built: Dictionary = validator.build_baseline()
	var committed: Dictionary = _Validator.load_baseline(validator.baseline_path())
	assert_bool(not committed.is_empty()).is_true()
	assert_that(built.get("total", -1)).is_equal(committed.get("total", -2))
	assert_that(built.get("templates", {})).is_equal(committed.get("templates", {}))

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
	assert_bool(found).is_true()

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
	assert_bool(found).is_true()

func test_baseline_save_load_roundtrip() -> void:
	var v = _Validator.new()
	v.validate_file(JSON_PATH)
	var before: Dictionary = v.build_baseline()
	assert_bool(v.save_baseline("user://test_baseline_rt.json")).is_true()
	var after: Dictionary = _Validator.load_baseline("user://test_baseline_rt.json")
	assert_that(after).is_equal(before)


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
	assert_that(w910).is_equal(0)

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
	assert_that(w910b).is_equal(1)

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
	assert_bool(found).is_true()

func test_no_w901_or_w910_in_project_data() -> void:
	validator.validate_file(JSON_PATH)
	var bad := 0
	for issue in validator.report.issues:
		if issue.code == "W901" or issue.code == "W910":
			bad += 1
	assert_that(bad).is_equal(0)


func test_strict_mode_fails_on_any_warning() -> void:
	var v = _Validator.new()
	_write("user://test_strict_warn.json",
		JSON.stringify([
			{"id": "w1", "name": "WarnMe", "template": "HARD_REMOVAL", "speed": "fast",
			 "cost": 4, "color": "shadow", "params": {}, "description": "x"}
		]))
	v.validate_file("user://test_strict_warn.json")
	var warnings := 0
	for issue in v.report.issues:
		if issue.code.begins_with("W"):
			warnings += 1
	assert_bool(warnings > 0).is_true()
	var ok: bool = v.validate_file("user://test_strict_warn.json")
	assert_bool(ok).is_true()
	assert_bool(ok and v.report.warning_count() == 0).is_false()

func test_project_data_strict_errors_clean() -> void:
	validator.validate_file(JSON_PATH)
	assert_that(validator.report.error_count()).is_equal(0)

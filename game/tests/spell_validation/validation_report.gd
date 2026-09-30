class_name ValidationReport
extends RefCounted

enum Severity { ERROR, WARNING, INFO }

class Issue extends RefCounted:
	var severity: int
	var code: String
	var message: String
	var spell_id: String
	var line_hint: String

	func format() -> String:
		var sev_str: String
		match severity:
			Severity.ERROR: sev_str = "ERROR  "
			Severity.WARNING: sev_str = "WARN   "
			_: sev_str = "INFO   "
		var loc: String = ("[%s] " % spell_id) if spell_id != "" else ""
		return "%s%s %s%s" % [sev_str, code, loc, message]

var issues: Array = []
var stats: Dictionary = {}

func error(code: String, msg: String, spell_id: String = "") -> void:
	_add(Severity.ERROR, code, msg, spell_id)

func warning(code: String, msg: String, spell_id: String = "") -> void:
	_add(Severity.WARNING, code, msg, spell_id)

func info(code: String, msg: String, spell_id: String = "") -> void:
	_add(Severity.INFO, code, msg, spell_id)

func _add(sev: int, code: String, msg: String, spell_id: String) -> void:
	var issue := Issue.new()
	issue.severity = sev
	issue.code = code
	issue.message = msg
	issue.spell_id = spell_id
	issues.append(issue)

func count_severity(sev: int) -> int:
	var n := 0
	for issue in issues:
		if issue.severity == sev:
			n += 1
	return n

func error_count() -> int:
	return count_severity(Severity.ERROR)

func warning_count() -> int:
	return count_severity(Severity.WARNING)

func info_count() -> int:
	return count_severity(Severity.INFO)

func has_errors() -> bool:
	return error_count() > 0

func filtered(min_severity: int) -> Array:
	var result = []
	for issue in issues:
		if issue.severity <= min_severity:
			result.append(issue)
	return result

func to_text() -> String:
	var lines = []
	lines.append("=".repeat(70))
	lines.append("SPELLBOOK VALIDATION REPORT")
	lines.append("=".repeat(70))

	var by_code = {}
	for issue in issues:
		by_code[issue.code] = int(by_code.get(issue.code, 0)) + 1

	if issues.is_empty():
		lines.append("No issues found.")
	else:
		lines.append("")
		lines.append("Issues by code:")
		var codes = by_code.keys()
		codes.sort()
		for code in codes:
			lines.append("  %s x %d" % [code, by_code[code]])
		lines.append("")
		lines.append("Details:")
		lines.append("-".repeat(70))
		for issue in issues:
			lines.append("  " + issue.format())

	lines.append("")
	lines.append("-".repeat(70))
	lines.append("TOTALS: %d errors, %d warnings, %d info" % [
		error_count(), warning_count(), info_count()])

	if stats.size() > 0:
		lines.append("")
		lines.append("STATS:")
		for k in stats:
			lines.append("  %s: %s" % [k, str(stats[k])])

	lines.append("=".repeat(70))
	if has_errors():
		lines.append("RESULT: FAILED")
	else:
		lines.append("RESULT: PASSED")
	lines.append("=".repeat(70))
	return "\n".join(lines)

func to_json() -> String:
	var arr = []
	for issue in issues:
		arr.append({
			"severity": ["error", "warning", "info"][issue.severity],
			"code": issue.code,
			"spell_id": issue.spell_id,
			"message": issue.message,
		})
	return JSON.stringify({
		"errors": error_count(),
		"warnings": warning_count(),
		"info": info_count(),
		"stats": stats,
		"issues": arr,
	}, "\t")

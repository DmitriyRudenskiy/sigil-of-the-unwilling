extends SceneTree
## CLI-валидатор card_spells.json.
##
## Запуск:
##   godot --headless --path . -s tools/card_validation/validate_card_spells.gd
##
## Флаги:
##   --path <file>   Путь к файлу (по умолчанию: res://data/card_spells.json)
##   --strict            Warnings считаются ошибками (ненулевой exit code)
##   --json              Вывод в формате JSON (для CI)
##   --quiet             Показывать только ошибки (без INFO)
##   --out <file>        Сохранить отчёт в файл
##   --update-baseline   Переписать baseline.json из текущей выборки (после валидации)

const _Validator = preload("res://tools/card_validation/CardSpellValidator.gd")
const _Report = preload("res://tools/card_validation/ValidationReport.gd")

func _init() -> void:
	var args := OS.get_cmdline_args()

	var path := "res://data/card_spells.json"
	var strict := false
	var json_output := false
	var quiet := false
	var out_file := ""
	var update_baseline := false

	for i in args.size():
		if args[i] == "--path" and i + 1 < args.size():
			path = args[i + 1]
		elif args[i] == "--strict":
			strict = true
		elif args[i] == "--json":
			json_output = true
		elif args[i] == "--quiet":
			quiet = true
		elif args[i] == "--out" and i + 1 < args.size():
			out_file = args[i + 1]
		elif args[i] == "--update-baseline":
			update_baseline = true

	var validator = _Validator.new()
	var start_time := Time.get_ticks_usec()
	var ok: bool = validator.validate_file(path)
	var elapsed_ms: float = (Time.get_ticks_usec() - start_time) / 1000.0

	var report = validator.report
	report.stats["validation_time_ms"] = elapsed_ms
	report.stats["file"] = path

	if strict and report.warning_count() > 0:
		ok = false

	# Вывод
	if json_output:
		print(report.to_json())
	else:
		if quiet:
			# Только ошибки и предупреждения
			for issue in report.filtered(_Report.Severity.WARNING):
				print(issue.format())
			print("RESULT: %s (%d errors, %d warnings)" % [
				"FAILED" if not ok else "PASSED",
				report.error_count(), report.warning_count()])
		else:
			print(report.to_text())

	# Обновление baseline (только если данные прошли без ошибок,
	# чтобы не заморозить сломанную выборку как эталон)
	if update_baseline:
		if ok:
			if validator.save_baseline(_Validator.BASELINE_PATH):
				print("Baseline updated: %s" % _Validator.BASELINE_PATH)
			else:
				print("❌ Failed to write baseline")
				quit(1)
				return
		else:
			print("⚠️  --update-baseline skipped: validation has errors")

	# Сохранение отчёта
	if out_file != "":
		var fa := FileAccess.open(out_file, FileAccess.WRITE)
		if fa != null:
			fa.store_string(report.to_json() if json_output else report.to_text())
			fa.close()
			print("Report saved to: %s" % out_file)

	quit(0 if ok else 1)

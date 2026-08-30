extends SceneTree
## CLI-валидатор spells.json.
##
## Запуск:
##   godot --headless --path game -s tools/spell_validation/validate_spells.gd
## (project root = game/, данные: game/data/spells.json.
##  зависимости скрипта грузятся из исходника — res://tools/... не нужны.)
##
## Флаги:
##   --path <file>   Путь к файлу (по умолчанию: res://data/spells.json)
##   --strict            Warnings считаются ошибками (ненулевой exit code)
##   --json              Вывод в формате JSON (для CI)
##   --quiet             Показывать только ошибки (без INFO)
##   --out <file>        Сохранить отчёт в файл
##   --update-baseline   Переписать baseline.json из текущей выборки (после валидации)

## Путь к зависимостям вычисляется в рантайме, а не статическим preload'ом.
## Причина: статический `preload("res://tools/...")` ломался бы при --path game
## (тогда res://tools/ = game/tools/, которого нет). Скрипт лежит в
## tools/spell_validation/ в корне репозитория — резолвим относительно себя.
var _self_path: String = ""
func _dir() -> String:
	if _self_path.is_empty():
		_self_path = get_script().resource_path
	return _self_path.get_base_dir()

## Грузим зависимости из исходника, а не через load()/preload() по res://.
## Причина: скрипт лежит в tools/spell_validation/ в КОРНЕ репозитория, а
## project root = game/. При --path game нет res://-маппинга на root/tools, а
## load() не принимает абсолютные OS-пути (повисал бы). GDScript из текста
## работает с любым абсолютным путём и при любом --path.
static func _load_src(path: String) -> Script:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		push_error("[validate_spellbook] cannot open %s" % path)
		return null
	var text := fa.get_as_text()
	fa.close()
	# Убираем «class_name X» из динамически загружаемого исходника:
	# иначе Godот ругается «hides a global script class», когда имя класса
	# уже зарегистрировано глобально (такой класс уже есть в проекте).
	var lines := text.split("\n", true)
	var kept: Array = []
	for line in lines:
		if line.strip_edges().begins_with("class_name "):
			continue
		kept.append(line)
	var gs := GDScript.new()
	gs.source_code = "\n".join(kept)
	gs.reload()
	return gs

var _Validator: Script
var _Report: Script

func _init() -> void:
	var dir := _dir()
	_Validator = _load_src(dir.path_join("SpellValidator.gd"))
	_Report = _load_src(dir.path_join("ValidationReport.gd"))

	var args := OS.get_cmdline_args()

	var path := "res://data/spells.json"
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

	var validator = _Validator.new(_Report)
	validator.set_base_dir(dir)
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
			if validator.save_baseline(validator.baseline_path()):
				print("Baseline updated: %s" % validator.baseline_path())
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

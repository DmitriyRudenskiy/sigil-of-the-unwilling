extends BaseTest

# Вердикт «весь игровой код компилируется» обязан быть одинаковым на любой машине.
# Урок 2026-11-02: скан ходил по всему `res://` (исключив только .git/.godot/addons/
# tools/tests) и натыкался на gitignored огрызок чужой съёмки `game/tmp/fixture_hero4.gd`
# — `tests/functional` был красен в изолированном прогоне на машине разработчика и
# зелёным в артефакте гейта. Проверка, зависящая от мусора в рабочем дереве, ничего
# не доказывает.
#
# Поэтому: список сканируемых каталогов явный, а каталог верхнего уровня, не помянутый
# ни в SCAN, ни в SKIP, прогон красит — молча из проверки не выпадет ни новый каталог
# с кодом, ни переименованный старый.
const SCAN := ["scripts", "scenes", "assets", "data"]

# `addons` — вендор (GdUnit4, godot-mcp), `tools` — утилиты прогона и патченная копия
# godot-mcp, `tests` — сами тесты (их проверяет прогон GdUnit), `tmp`/`reports`/`venv`
# — артефакты, `user`/`locale`/`image-clone`/`balance_reports` — не код.
# `concept_art` — выход генератора концепт-арта (`krea2/…`), gitignored: он появляется
# в рабочем дереве между прогонами и красил smoke на чужой машине (урок 2026-11-08,
# тот же класс, что `tmp/fixture_hero4.gd` выше).
# Файл `res://mcp_interaction_server.gd` — артефакт инъекции вендорного MCP-сервера
# (в git его нет), в SCAN верхнего уровня он не участвует.
const SKIP := [
	".git", ".godot", "addons", "assets", "balance_reports", "concept_art", "data",
	"image-clone", "locale", "reports", "scenes", "scripts", "tests", "tmp", "tools",
	"user", "venv",
]

# Пол: 420 версионированных .gd в SCAN (замер 2026-11-09: scripts 418 + scenes 2;
# dbg_stats.gd переехал в tools/ и выпал из SCAN — tools входит в SKIP).
# Нужен, чтобы переименованный каталог в SCAN не превращал проверку в зелёную на нуле.
const MIN_COMPILED := 400

var _bad: Array[String] = []
var _ok := 0

func test_all_gd_compiles() -> void:
	_bad.clear()
	_ok = 0
	var root := DirAccess.open("res://")
	assert_object(root).is_valid()
	if root.list_dir_begin() != OK:
		fail("res:// не читается")
		return
	var dirs: Array[String] = []
	var top_files: Array[String] = []
	var n: String = root.get_next()
	while n != "":
		if root.current_is_dir():
			dirs.append(n)
		elif n.ends_with(".gd"):
			top_files.append(n)
		n = root.get_next()
	root.list_dir_end()
	dirs.sort()
	top_files.sort()
	for d in dirs:
		if d in SCAN:
			_scan("res://" + d)
		elif d not in SKIP:
			_bad.append("res://%s/ — каталог верхнего уровня не описан в SCAN/SKIP (test_compile_all.gd)" % d)
	for f in top_files:
		_check("res://" + f)
	assert_that(_bad).is_empty()
	assert_that(_ok).is_greater_equal(MIN_COMPILED)

func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null or dir.list_dir_begin() != OK:
		_bad.append(path + " — каталог из SCAN не читается")
		return
	var f: String = dir.get_next()
	while f != "":
		if not f.begins_with("."):
			var full: String = path.path_join(f)
			if dir.current_is_dir():
				_scan(full)
			elif f.ends_with(".gd"):
				_check(full)
		f = dir.get_next()
	dir.list_dir_end()

func _check(full: String) -> void:
	var res = ResourceLoader.load(full, "GDScript")
	if res == null or not (res is GDScript) or not res.can_instantiate():
		_bad.append(full)
	else:
		_ok += 1

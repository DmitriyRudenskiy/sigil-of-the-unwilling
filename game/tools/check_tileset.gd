extends SceneTree

## Проверка целостности тайлкета (CI-шаг). Работает как check_scene_refs.gd:
## сканируем в _process и завершаем проект через quit().
## Печатает «RESULT: PASSED» / «RESULT: FAILED» — надёжный сигнал для CI.

var _ok := true
const SHEET_PATH := "res://assets/tiles/world_tiles.jpeg"


func _process(_delta: float) -> bool:
	var tex := load(SHEET_PATH)
	if not (tex is Texture2D):
		print("FAIL: не удалось загрузить ", SHEET_PATH)
		_ok = false
	else:
		print("OK: текстура %dx%d" % [tex.get_width(), tex.get_height()])

	var ts := TileAtlas.build_hex_tileset()
	if ts == null:
		print("FAIL: TileAtlas.build_hex_tileset() == null")
		_ok = false
	else:
		print("OK: TileSet источников ", ts.get_source_count())

	var verdict := "PASSED" if _ok else "FAILED"
	print("=== tileset check: RESULT: ", verdict, " ===")
	quit(0 if _ok else 1)
	return true

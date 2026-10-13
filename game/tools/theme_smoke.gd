extends SceneTree

# Дым-проверка глобальной темы (фаза 5, шаг 0; harness по образцу tools/ux_shots.gd):
# рендерит ключевые UI-сцены и кладёт кадры в /tmp/theme-smoke/<TAG>/.
# Запуск НЕ headless (нужен рендер):
#   Godot --path game -s tools/theme_smoke.gd
# TAG — переменная окружения SMOKE_TAG (по умолчанию "run"): так снимаются «до»
# и «после» одного кода и сравниваются файлы. Экраны-под-окна (settings_screen и
# др.) без игрового состояния сами себя освобождают — это фиксируется в логе,
# прогон не падает.

const OUT_DIR := "/tmp/theme-smoke/"
const SIZE := Vector2i(1280, 720)

const SCENES: Array[String] = [
	"res://scenes/main_menu.tscn",
	"res://scenes/ui/character_creation.tscn",
	"res://scenes/ui/settings_screen.tscn",
	"res://scenes/ui/save_load_screen.tscn",
	"res://scenes/ui/info_panel.tscn",
	"res://scenes/ui/artifact_inventory_screen.tscn",
	"res://scenes/ui/artifact_chest_dialog.tscn",
	"res://scenes/ui/resource_collect_popup.tscn",
	"res://scenes/ui/battle_spellbook_panel.tscn",
	"res://scenes/ui/city_screen.tscn",
	"res://scenes/ui/world_ui.tscn",
]

var _out: String
var _shots := 0


func _initialize() -> void:
	var tag := OS.get_environment("SMOKE_TAG")
	if tag == "":
		tag = "run"
	_out = OUT_DIR + tag + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = SIZE
	_run()


func _run() -> void:
	for path in SCENES:
		var name := path.get_file().get_basename()
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("cannot load %s" % path)
			continue
		var scene := packed.instantiate()
		# локальная тема читается ДО await: экраны-под-окна освобождают себя в _ready
		var ci := scene as CanvasItem
		var local_theme := ("n/a (root не CanvasItem)" if ci == null
			else ("none" if ci.theme == null else str(ci.theme.resource_path)))
		root.add_child(scene)
		await _frames(6)
		var alive := "ok" if is_instance_valid(scene) else "FREED-ITSELF"
		_shot(name)
		print("SHOT %s local_theme=%s state=%s" % [name, local_theme, alive])
		if is_instance_valid(scene):
			scene.queue_free()
		await _frames(1)
	print("THEME_SMOKE_DONE=%d project_theme=%s" % [
		_shots, str(ProjectSettings.get_setting("gui/theme/custom"))])
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	var img: Image = root.get_window().get_texture().get_image()
	var err := img.save_png(_out + name + ".png")
	if err != OK:
		push_error("save_png failed: %s (%d)" % [name, err])
		return
	_shots += 1

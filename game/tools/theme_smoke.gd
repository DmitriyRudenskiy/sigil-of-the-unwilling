extends SceneTree

# Дым-проверка глобальной темы (фаза 5, шаг 0; harness по образцу tools/ux_shots.gd):
# рендерит ключевые UI-сцены и кладёт кадры в /tmp/theme-smoke/<TAG>/.
# Запуск НЕ headless (нужен рендер):
#   Godot --path game -s tools/theme_smoke.gd
# TAG — переменная окружения SMOKE_TAG (по умолчанию "run"): так снимаются «до»
# и «после» одного кода и сравниваются файлы. Экраны-под-окна (settings_screen и
# др.) без игрового состояния сами себя освобождают — это фиксируется в логе,
# прогон не падает.
#
# ОГРАНИЧЕНИЕ ПОКРЫТИЯ (фиксируем явно, владелец 2026-10-14): дым-проверка
# сравнивает только живые экраны, а они молчат про половину темы. В прогоне
# 2026-10-14 четыре строки реестра §9 дали 0% дельты — не потому что тема не
# поменялась, а потому что проверяемые контролы на этих экранах не рисуются:
#   К-3 Slider · К-6 LineEdit · К-6 CheckBox · К-6 вкладки/тултип → 0.00%
# Единственное визуальное доказательство для них — scenes/ui/kitchen_sink.tscn
# (собрана в фазе 5, добавлена в SCENES ниже): все компоненты во всех состояниях
# на одном кадре. 0% на живом экране = «не видно», а не «не тронуто».

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
	# Компоненты К-3/К-6 не живут ни на одном экране — см. «ОГРАНИЧЕНИЕ ПОКРЫТИЯ».
	"res://scenes/ui/kitchen_sink.tscn",
]

var _out: String
var _only := ""
var _shots := 0


func _initialize() -> void:
	var tag := OS.get_environment("SMOKE_TAG")
	if tag == "":
		tag = "run"
	_out = OUT_DIR + tag + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	# Кадры «до/после» сравниваются попиксельно, поэтому окно обязано быть одним и
	# тем же в обоих прогонах. `root.size = SIZE` его не гарантирует: macOS отдаёт
	# окну последний пользовательский размер, аспект меняется, фон масштабируется —
	# и на кадре 40% «дельты» без всякой темы (замер 2026-10-14). Пинним размер и
	# позицию явно перед каждым кадром.
	_pin_window()
	# SMOKE_ONLY=подстрока — отобрать один экран (быстрая итерация по одной сцене).
	_only = OS.get_environment("SMOKE_ONLY")
	_run()


func _pin_window() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(SIZE)
	DisplayServer.window_set_position(Vector2i.ZERO)


## Отпечаток состояния, с которым снят кадр (md5 темы + текстуры кнопки). Кадры
## «до/после» снимаются в разных checkout'ах одной рабочей копии: без строки
## STATE в логе кадр, снятый не с того состояния, неотличим от настоящего
## (проверено: так шагу 0 приписался 0% kitchen-sink).
func _state_fingerprint() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for path in ["res://assets/theme/game_theme.tres",
			"res://assets/ui/widgets/buttons/button_normal.png",
			"res://scripts/theme/theme_config.gd"]:
		ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode().substr(0, 12)


func _run() -> void:
	for path in SCENES:
		var name := path.get_file().get_basename()
		if _only != "" and not name.contains(_only):
			continue
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
		_pin_window()
		await _frames(6)
		var alive := "ok" if is_instance_valid(scene) else "FREED-ITSELF"
		_shot(name)
		print("SHOT %s size=%dx%d local_theme=%s state=%s" % [
			name, root.size.x, root.size.y, local_theme, alive])
		if is_instance_valid(scene):
			scene.queue_free()
		await _frames(1)
	print("THEME_SMOKE_DONE=%d project_theme=%s fp=%s" % [
		_shots, str(ProjectSettings.get_setting("gui/theme/custom")), _state_fingerprint()])
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

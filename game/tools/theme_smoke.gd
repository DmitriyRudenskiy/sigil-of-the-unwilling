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
# Переменные окружения: SMOKE_TAG (подкаталог/«до-после»), SMOKE_ONLY (имя сцены
# или glob), SMOKE_OUT (каталог результатов вместо /tmp/theme-smoke/<tag>/ —
# приёмка ui-mockup-parity кладёт кадры в docs/img), SMOKE_PREFIX (приставка к
# имени файла, чтобы пара «до/после» была сортируемой: `22_main_menu_before`),
# SMOKE_REQUIRE_RENDER=1 (пустой кадр = падение прогона, а не молчаливый PNG).
# Проверено на 6 и 20 кадрах устаканивания — значения меры совпали, отдельного
# рычага под число кадров не заводили.
# ОГРАНИЧЕНИЕ gate: SMOKE_REQUIRE_RENDER=1 включать только на наборе самостоятельных
# экранов. Экраны-под-окна без игрового состояния (spellbook, chest, collect-popup)
# освобождают себя в _ready и снимаются пустым кадром по делу — на полном прогоне
# они дают ложное падение.
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
# Мера «кадр настоящий»: разброс яркости по плотной сетке. Однотонный кадр
# (clear color вместо рендера) даёт ровно 0.0; кадр с любым содержимым — десятыми.
# Шаг 3, не 17: на самом пустом настоящем кадре (кампейн «День: 1» на сером —
# подпись 180×30 px на 1280×720) выборка с шагом 17 в подпись не попадает и кадр
# подписывается пустым (проверено на сохранённом PNG).
const MIN_LUMA_SPREAD := 0.02
const SAMPLE_STRIDE := 3

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
	# Экран боя: без него в съёмке не было ни одного кадра того, на чём игрок дерётся
	# (состояния боевого HUD снимает другой harness — tools/ux_shots.gd).
	"res://scenes/battle.tscn",
	"res://scenes/ui/world_ui.tscn",
	# Кампейн-экран, который игрок получает после sign_choice (D-202/ui-mockup-parity):
	# в списке его не было, и «серый кадр вместо кампейн-HUD» не видел никто —
	# отсутствие экрана на снимке неотличимо от отсутствия съёмки.
	"res://scenes/main/main.tscn",
	# Компоненты К-3/К-6 не живут ни на одном экране — см. «ОГРАНИЧЕНИЕ ПОКРЫТИЯ».
	"res://scenes/ui/kitchen_sink.tscn",
]

var _out: String
var _only := ""
var _prefix := ""
var _require_render := false
var _shots := 0
var _blank := 0


func _initialize() -> void:
	var tag := OS.get_environment("SMOKE_TAG")
	if tag == "":
		tag = "run"
	# SMOKE_OUT — явный каталог результатов (приёмка ui-mockup-parity: docs/img).
	# Только абсолютный: относительный путь Godot трактует как res://-относительный,
	# и кадры уезжают в game/docs/img, где ещё и импортируются (проверено).
	var out := OS.get_environment("SMOKE_OUT")
	if out != "" and not out.is_absolute_path():
		push_error("SMOKE_OUT обязан быть абсолютным путём, получено: %s" % out)
		quit(2)
		return
	_out = (out + "/") if out != "" else (OUT_DIR + tag + "/")
	DirAccess.make_dir_recursive_absolute(_out)
	_prefix = OS.get_environment("SMOKE_PREFIX")
	_require_render = OS.get_environment("SMOKE_REQUIRE_RENDER") == "1"
	# Кадры «до/после» сравниваются попиксельно, поэтому окно обязано быть одним и
	# тем же в обоих прогонах. `root.size = SIZE` его не гарантирует: macOS отдаёт
	# окну последний пользовательский размер, аспект меняется, фон масштабируется —
	# и на кадре 40% «дельты» без всякой темы (замер 2026-10-14). Пинним размер и
	# позицию явно перед каждым кадром.
	_pin_window()
	# SMOKE_ONLY=имя сцены или glob (`city_screen`, `battle*`, `*popup*`). Раньше
	# фильтром была подстрока: `battle` тянул за собой spellbook, `main` — main_menu,
	# и набор приёмки нельзя было снять одним запуском под gate.
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
		if _only != "" and not name.match(_only):
			continue
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("cannot load %s" % path)
			continue
		var scene := packed.instantiate()
		# локальная тема читается ДО await: экраны-под-окна освобождают себя в _ready
		# `theme` есть только у Control: корень-Node2D (battle.tscn) — это CanvasItem,
		# но без свойства theme, а корень-Node (main.tscn) — вообще вне CanvasItem.
		var local_theme := "n/a (root не Control)"
		if scene is Control:
			var ctl := scene as Control
			local_theme = "none" if ctl.theme == null else str(ctl.theme.resource_path)
		root.add_child(scene)
		_pin_window()
		await _frames(6)
		var alive := "ok" if is_instance_valid(scene) else "FREED-ITSELF"
		var spread := _shot(name)
		print("SHOT %s size=%dx%d local_theme=%s state=%s luma_spread=%.4f blank=%s" % [
			name, root.size.x, root.size.y, local_theme, alive, spread,
			"YES" if spread <= MIN_LUMA_SPREAD else "no"
		])
		if is_instance_valid(scene):
			scene.queue_free()
		await _frames(1)
	print("THEME_SMOKE_DONE=%d project_theme=%s fp=%s" % [
		_shots, str(ProjectSettings.get_setting("gui/theme/custom")), _state_fingerprint()])
	if _require_render and _blank > 0:
		# Пустой кадр — не доказательство. Молча записать его значит выдать
		# отсутствие картинки за успешную съёмку.
		print("RENDER-GATE: FAILED (пустых кадров %d из %d)" % [_blank, _shots])
		quit(1)
		return
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> float:
	var img: Image = root.get_window().get_texture().get_image()
	var spread := _luma_spread(img)
	var err := img.save_png(_out + _prefix + name + ".png")
	if err != OK:
		push_error("save_png failed: %s (%d)" % [name, err])
		return -1.0
	_shots += 1
	if spread <= MIN_LUMA_SPREAD:
		_blank += 1
	return spread


# Разброс яркости по сетке: дешёвая проверка, что в кадре есть что смотреть,
# до того как PNG станет чьим-то «доказательством внешности». Image.get_histogram
# для этого не годится: на живых кадрах всех сцен мера возвращала 0.0 (пустую
# гистограмму от пустого кадра отличить было нечем), а на загруженном webp
# подвешивала процесс (проверено).
func _luma_spread(img: Image) -> float:
	var lo := 1.0
	var hi := 0.0
	for y in range(0, img.get_height(), SAMPLE_STRIDE):
		for x in range(0, img.get_width(), SAMPLE_STRIDE):
			var c := img.get_pixel(x, y)
			var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			lo = minf(lo, l)
			hi = maxf(hi, l)
	return hi - lo

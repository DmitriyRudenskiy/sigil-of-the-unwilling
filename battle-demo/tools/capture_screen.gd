extends Node

## Снимает экран боя для визуальной приёмки задач 9.3–9.4.
##
##     godot --path battle-demo res://tools/capture_screen.tscn
##
## Кадры: старт состава A и середина боя (несколько действий). Полный комплект
## «четыре состояния × два набора» — задача 9.10, здесь только то, чем принимается
## этот экран. Только с дисплеем: в `--headless` рендер не поднимается.
## Пиксели в git не идут (D-185) — кадры пишутся в `tmp/shots/`.

const OUT := "/Users/user/sigil-of-the-unwilling/tmp/shots"
const ACTIONS_BEFORE_MIDSHOT := 5


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size = Vector2i(1920, 1080)
	var screen: BattleScreen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.start_roster("a", 3)
	await _shot("start")
	for _action in ACTIONS_BEFORE_MIDSHOT:
		if screen.combat.finished:
			break
		BattleFactory.auto_play(screen.combat, 1)
	await _shot("mid")
	get_tree().quit(0)


func _shot(tag: String) -> void:
	# Первое окно на macOS рисуется не сразу: без паузы первый кадр выходит чёрным
	# (проверено на паре кадров 2026-10-25 — 8 КБ против 500 КБ).
	await get_tree().create_timer(1.0).timeout
	for _frame in 4:
		await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	var error: int = image.save_png("%s/screen-%s.png" % [OUT, tag])
	print("%s → %s (%dx%d)" % [tag, error_string(error), image.get_width(), image.get_height()])

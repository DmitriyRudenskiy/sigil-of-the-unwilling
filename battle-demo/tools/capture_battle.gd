extends Node

## Снимает поле боя по дорожкам для визуальной приёмки (задача 8.2).
##
##     godot --path battle-demo res://tools/capture_battle.tscn
##
## Только с дисплеем: в `--headless` рендер не поднимается и кадр выходит чёрным,
## поэтому скрипт не входит в гейт, а поднимает окно на несколько кадров.
## Пиксели в git не идут (D-185) — кадры пишутся в `tmp/shots/`.

const OUT := "/Users/user/sigil-of-the-unwilling/tmp/shots"
const STATES := ["idle", "attack", "hit", "turn"]
## Кадр берётся через несколько кадров движка: спрайт должен успеть переключиться.
const SETTLE := 4


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size = Vector2i(1920, 1080)
	var field: BattleField = load("res://scenes/battle_field.tscn").instantiate()
	field.auto_cycle = false
	add_child(field)
	for state: String in STATES:
		field.show_state(StringName(state))
		for _settle in SETTLE:
			await get_tree().process_frame
		var image: Image = get_viewport().get_texture().get_image()
		var error: int = image.save_png("%s/battle-%s.png" % [OUT, state])
		print("%s → %s (%dx%d)" % [state, error_string(error), image.get_width(), image.get_height()])
	get_tree().quit(0)

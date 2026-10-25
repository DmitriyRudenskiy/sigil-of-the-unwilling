extends Node
## Снимает идущий бой: семь юнитов состава A против шторм-мага, кадр в момент
## контакта (атакующий в замахе, цель начинает `hit`).
##
##     godot --path battle-demo res://tools/capture_fight.tscn
##
## Отличие от `capture_screen.tscn`: тот снимает старт и «после пяти действий»,
## где анимации уже доехали до последнего кадра и стоят. Здесь кадр берётся через
## половину `contact_delay()` после реального действия — тот же путь, что у боя:
## `action_performed` → `BattleField.on_action` → `hit` цели с задержкой контакта.
## Только с дисплеем; пиксели в git не идут (D-185) — кадры в `tmp/shots/`.

const OUT := "/Users/user/sigil-of-the-unwilling/tmp/shots"
const ACTIONS := 9


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size = Vector2i(1920, 1080)
	var screen: BattleScreen = load("res://scenes/battle.tscn").instantiate()
	add_child(screen)
	screen.start_roster("a", 7)
	await get_tree().create_timer(1.0).timeout
	for action in ACTIONS:
		if screen.combat.finished:
			break
		BattleFactory.auto_play(screen.combat, 1)
		var actor = screen.combat.current
		var view: BattleUnitView = screen.field.view_of(actor) if actor != null else null
		var wait := 0.0 if view == null else view.contact_delay() * 0.6
		await get_tree().create_timer(wait).timeout
		for _frame in 2:
			await get_tree().process_frame
		var image: Image = get_viewport().get_texture().get_image()
		var error := image.save_png("%s/fight-%d.png" % [OUT, action])
		print("fight-%d → %s (%dx%d)" % [action, error_string(error), image.get_width(), image.get_height()])
	get_tree().quit(0)

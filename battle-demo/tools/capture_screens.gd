extends Node

# [AI]: сгенерировано по задаче 9.10 tasks.md, проверено человеком.
#
# Съёмка четырёх состояний двух наборов (спека `battle-demo-ui`, «Кадры
# приёмки»): выбор набора, старт, середина, результат → 8 кадров в
# `artifacts/screenshots/<roster>_<state>.png`. Один GUI-процесс, короткое
# время жизни, пиксели в git не идут (D-185) — в репо остаётся только этот
# скрипт и отчёт со ссылками на md5.
#
#     godot --path battle-demo res://tools/capture_screens.tscn
#
# Дисплей: `Xvfb` на свободном номере поднимает `run_tests.sh` (или оператор);
# без X кадр получить нечем.

const OUT := "res://artifacts/screenshots"
const SEED := 3
## Действий до «середины»: к этому моменту у обеих сторон есть потери, но бой
## ещё не выигран — ровно то состояние, на котором ищутся наложения полос.
const MID_ACTIONS := 9


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size = Vector2i(1920, 1080)
	for id in DataLibrary.ROSTER_IDS:
		var roster := String(id)
		# Кадр выбора снимается на каждый набор со своим выделением: имя файла
		# обязано читаться как `<roster>_<state>` (спека), а игроку в этом кадре
		# видно, какой набор он подтверждает.
		var choice: RosterSelect = load("res://scenes/roster_select.tscn").instantiate()
		add_child(choice)
		choice.select(roster)
		await _shot("%s_select" % roster, choice)
		var screen := load("res://scenes/battle.tscn").instantiate() as BattleScreen
		add_child(screen)
		screen.start_roster(roster, SEED)
		# Пауза перед первым кадром боя: текстуры атласов загружаются в первый
		# же кадр после создания окна, и без неё старт снимается чёрным
		# (тот же эффект, из-за которого `capture_fight.gd` ждёт секунду).
		await get_tree().create_timer(1.0).timeout
		await _shot("%s_start" % roster, screen)
		BattleFactory.auto_play(screen.combat, MID_ACTIONS)
		await _shot("%s_mid" % roster, screen)
		BattleFactory.auto_play(screen.combat)
		await _shot("%s_result" % roster, screen)
		screen.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)



func _shot(name: String, node: Node) -> void:
	# Два кадра паузы: полоса и метки пересобираются в сигнале, но в отрисовку
	# попадают только к следующему кадру.
	for _frame in 2:
		await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT, name]
	var error := image.save_png(path)
	print(
		"%s → %s (%dx%d)" % [name, error_string(error), image.get_width(), image.get_height()]
	)
	if node is Control:
		node.queue_free()
		await get_tree().process_frame

extends Node

# [AI]: сгенерировано по задаче 9.10 tasks.md.
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
## Кадр — целевое разрешение спеки, а не размер окна: macOS не даёт окну быть
## 1920×1080 (меню-бар срезает 53 px), а `stretch/aspect="expand"` на чужом
## аспекте разъезжается. Сцена рисуется в `SubViewport` ровно 1920×1080.
const FRAME := Vector2i(1920, 1080)
const SEED := 3
## Действий до «середины»: к этому моменту у обеих сторон есть потери, но бой
## ещё не выигран — ровно то состояние, на котором ищутся наложения полос.
const MID_ACTIONS := 9

var _stage := SubViewport.new()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_stage.size = FRAME
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage)
	for id in DataLibrary.ROSTER_IDS:
		var roster := String(id)
		# Кадр выбора снимается на каждый набор со своим выделением: имя файла
		# обязано читаться как `<roster>_<state>` (спека), а игроку в этом кадре
		# видно, какой набор он подтверждает.
		var choice: RosterSelect = load(DemoFlow.ROSTER_SCENE).instantiate()
		_stage.add_child(choice)
		choice.select(roster)
		await _shot("%s_select" % roster, choice)
		var screen := load("res://scenes/battle.tscn").instantiate() as BattleScreen
		_stage.add_child(screen)
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
	var image: Image = _stage.get_texture().get_image()
	var path := "%s/%s.png" % [OUT, name]
	var error := image.save_png(path)
	print("%s → %s (%dx%d)%s" % [
		name, error_string(error), image.get_width(), image.get_height(),
		# Модель рядом с кадром: приёмка сверяет прочитанные с кадра числа с тем,
		# что считалось в момент съёмки, а не с отдельным прогоном (общий ГШЧ
		# экрана, стартующего себя сам, делает второй прогон необъективным).
		"" if not (node is BattleScreen) else " | " + _model_line(node as BattleScreen),
	])
	if node is Control:
		node.queue_free()
		await get_tree().process_frame


## Раунд, живые своего состава и HP противника — те же величины, что подписаны
## на кадре (счётчик хода, полоса состава, панель противника).
func _model_line(screen: BattleScreen) -> String:
	var combat := screen.combat
	var foes := combat.alive(BattleUnit.SIDE_ENEMY)
	# После победы живых противников нет — HP снимаем с мёртвого, а не с пустого списка.
	var foe: BattleUnit = combat.units.filter(
		func(u: BattleUnit) -> bool: return u.side == BattleUnit.SIDE_ENEMY
	)[0] if foes.is_empty() else foes[0]
	return "round=%d alive=%d/%d foe=%d/%d finished=%s" % [
		screen.hud.round_number(),
		combat.alive(BattleUnit.SIDE_PLAYER).size(),
		DataLibrary.ROSTER_SIZE,
		foe.hp,
		foe.max_hp(),
		combat.finished,
	]

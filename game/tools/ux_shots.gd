extends SceneTree

# UX-review harness (UI-3 шаг 3, docs/14 §6): рендер battle HUD в 1280×720 и
# сохранение кадров в OUT. Запуск НЕ headless (нужен рендер):
#   Godot --path game -s tools/ux_shots.gd
# Каждый кадр — независимое состояние; вызовы защищены has_method/has_node —
# harness должен запускаться и на «before»-коммите (до шага 2).

const OUT := "/tmp/ux-shots/"

var _shots_done := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280, 720)
	_run()


func _run() -> void:
	var scene: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)
	await _frames(4)
	var ui: Node = scene.get_node_or_null("BattleUI")
	if ui == null:
		push_error("no BattleUI in battle.tscn")
		quit(2)
		return

	await _shot(ui, "01_default")

	# B: карточка цели — длинное ru-имя (32), AC/HP/УДЧ, dnd-профиль
	var long_ru = _make_unit(
		"Пепельный дозорник Обгоревшего Предела имени Огненного", 1200000, 1200000, 19, 7, 1
	)
	if ui.has_method("show_target_card"):
		ui.show_target_card(long_ru)
		await _shot(ui, "02_target_long_ru")

	# overflow: 1.2M числа + длинное en-имя + stack count
	var long_en = _make_unit(
		"Ashen Warden of the Scorched March of Fire and Ruin", 1200000, 1200000, 19, 7, 1200000
	)
	if ui.has_method("show_target_card"):
		ui.show_target_card(long_en)
		await _shot(ui, "03_overflow_long_en")

	# error-chip предпросмотра поверх карточки
	if ui.has_method("set_attack_preview"):
		ui.set_attack_preview("Недостаточно места для удара")
		await _shot(ui, "04_error_chip")
		ui.set_attack_preview("")

	# A: очередь — активный/обычный/мёртвый (форма, не только цвет)
	if ui.has_method("update_initiative"):
		var units: Array[BattleState.BattleUnit] = []
		var a = _make_unit("Ала", 20, 20, 12, 3, 1)
		var b = _make_unit("Бор", 8, 30, 14, 2, 1)
		var c = _make_unit("Вив", 0, 24, 10, 1, 1)
		c.alive = false
		for u in [a, b, c]:
			units.append(u)
		ui.update_initiative(units, a)
		await _shot(ui, "05_queue_states")

	# все контролы: lock (skip остаётся активной — инвариант)
	if ui.has_method("set_controls_enabled"):
		ui.set_controls_enabled(false)
		await _shot(ui, "06_controls_lock")
		ui.set_controls_enabled(true)

	# фокус-рамка (библия §6)
	var skip := ui.get_node_or_null("bottom_bar/bar_box/right_box/skip_btn")
	if skip != null:
		skip.grab_focus()
		await _shot(ui, "07_focus_frame")

	# F: финал
	if ui.has_method("show_result"):
		ui.show_result(0, 1200000, 7)
		await _shot(ui, "08_result")

	# лог-строка (подпись зоны, длинный текст)
	if ui.has_method("set_status"):
		ui.set_status(
			"Пепельный дозорник нанёс 1200000 урона: отряд рассеян, знамя потеряно в пепле"
		)
		await _shot(ui, "09_log_long")

	print("UX_SHOTS_DONE=%d" % _shots_done)
	quit(0)


func _make_unit(p_name: String, hp: int, max_hp: int, ac: int, atk: int, count: int):
	var stats := UnitStats.new()
	stats.key = "ux_shot"
	stats.display_name = p_name
	stats.hp = hp
	stats.defense = ac
	stats.attack = atk
	var stack := UnitStack.new(stats, count)
	var profile := DnDCombatantProfile.new()
	profile.name = p_name
	profile.max_hp = max_hp
	var unit := BattleState.BattleUnit.new(stack)
	unit.dnd_profile = profile
	unit.dnd_current_hp = hp
	return unit


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(ui: Node, name: String) -> void:
	await _frames(3)
	var img: Image = root.get_window().get_texture().get_image()
	var path := OUT + name + ".png"
	var err := img.save_png(path)
	if err != OK:
		push_error("save_png failed: %s (%d)" % [path, err])
	_shots_done += 1

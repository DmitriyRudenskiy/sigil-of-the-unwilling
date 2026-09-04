## scripts/ui/DeathSequence.gd
class_name DeathSequence
extends CanvasLayer
## legend-chronicle: момент смерти героя — полноэкранная последовательность
## (код-билд, не .tscn — конвенция репо: GameOverScreen/AdventureUI).
##
## Биты: (a) падение — имя героя + «цикл оборвался/продолжится»;
## (b) сводка забега (ходы, дата, города, слава, бои, поколения);
## (c) если есть преемник — карточка преемника + «Знак переходит»
## (вызывает succession-поток в WorldController); иначе «В меню»;
## (d) hero-survival: если доступен великий храм — «Воскресить»
## (альтернатива преемнику: герой возвращается, цикл не оборвался).
## Пока открыта — глотает весь unhandled-ввод (как GameOverScreen).

signal successor_chosen
signal return_to_menu
signal chronicle_requested
signal resurrection_chosen

const _CAUSES: Dictionary = {
	&"battle": "в бою",
	# hero-survival: смерти по потребностям (HeroNeeds._death_cause).
	&"exhaustion": "от истощения",
	&"isolation": "от одиночества",
	&"burnout": "от выгорания",
}

var _root: Control = null


func _init() -> void:
	layer = 110
	visible = false


## successor == null → «цикл оборвался» + «В меню»; иначе карточка
## преемника + «Знак переходит». res_city (hero-survival) — город с
## великим храмом: третья кнопка «Воскресить». summary — формат endgame.
func show_death(
	deceased_name: String,
	cause: StringName,
	summary: Dictionary,
	successor: HeroController = null,
	res_city: City = null
) -> void:
	_build()
	var title: Label = _root.get_node("Panel/VBox/Title")
	var reason: Label = _root.get_node("Panel/VBox/Reason")
	if successor == null:
		title.text = "%s — цикл оборвался" % deceased_name
		title.add_theme_color_override("font_color", Color(0.75, 0.3, 0.28))
	else:
		title.text = "%s — цикл продолжится" % deceased_name
		title.add_theme_color_override("font_color", Color(0.92, 0.84, 0.55))
	reason.text = "Герой пал %s." % str(_CAUSES.get(cause, String(cause)))

	var d: Dictionary = summary.get("date", {})
	var values: Dictionary = {
		"TurnsLabel": "Ходы: %d" % int(summary.get("turns", 0)),
		"DateLabel": "Дата: %d/%d/%d" % [
			int(d.get("month", 1)), int(d.get("week", 1)), int(d.get("day", 1))],
		"CitiesLabel": "Города: %d" % int(summary.get("cities_owned", 0)),
		"GloryLabel": "Слава: %d" % int(summary.get("glory", 0)),
		"BattlesLabel": "Боёв: %d побед / %d поражений" % [
			int(summary.get("battles_won", 0)), int(summary.get("battles_lost", 0))],
		"GenerationsLabel": "Поколений: %d" % int(summary.get("generations", 1)),
	}
	var grid: VBoxContainer = _root.get_node("Panel/VBox/Grid")
	for l in grid.get_children():
		if l is Label:
			l.text = str(values.get(l.name, l.text))

	# Карточка преемника (только если преемник есть).
	var card: VBoxContainer = _root.get_node("Panel/VBox/SuccessorCard")
	var successor_btn: Button = _root.get_node("Panel/VBox/Buttons/SuccessorButton")
	var resurrection_btn: Button = _root.get_node("Panel/VBox/Buttons/ResurrectionButton")
	var menu_btn: Button = _root.get_node("Panel/VBox/Buttons/MenuButton")
	# hero-survival: «Воскресить» — только при городе-кандидате (WorldController
	# передаёт res_city лишь когда цикл жив и герой не воскрешал в цикле).
	var res_cost := SuccessionController.RESURRECTION_INDUSTRY
	var res_gold := SuccessionController.RESURRECTION_SPECIAL_AMOUNT
	if successor != null:
		var card_label: Label = card.get_node("CardLabel")
		card_label.text = "Знак переходит к: %s" % _successor_caption(successor)
		card.visible = true
		successor_btn.visible = true
		menu_btn.visible = false
		resurrection_btn.visible = res_city != null
		if res_city != null:
			resurrection_btn.text = "Воскресить (%d⚙ + %d💰)" % [res_cost, res_gold]
	else:
		card.visible = false
		successor_btn.visible = false
		menu_btn.visible = true
		resurrection_btn.visible = false

	visible = true
	# Твин требует ноду в дереве — в headless-тестах показываем без анимации.
	if _root.get_node("Panel").is_inside_tree():
		UIAnimator.animate_in(_root.get_node("Panel"))


## «Имя (Раса, Путь)» для карточки преемника.
func _successor_caption(successor: HeroController) -> String:
	var parts: Array[String] = [successor.hero_name]
	var registry = FollowerSystem.raceclass_registry()
	var race_def = registry.get_race(successor.race_id) if "race_id" in successor else null
	if race_def != null and not race_def.name.is_empty():
		parts.append(race_def.name)
	var path := String(successor.path_id)
	if not path.is_empty():
		parts.append(path)
	return parts[0] + (" (%s)" % ", ".join(parts.slice(1)) if parts.size() > 1 else "")


func _build() -> void:
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	# ponytail: имя явное — Godot 4.7 auto-name (@Control@N) ломает get_node.
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var panel: Panel = Panel.new()
	# ponytail: имя ставим явно — в Godot 4.7 auto-name для unnamed-нод
	# получается «@Panel@N» и get_node("Panel") не находит.
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(460, 0)
	panel.position = Vector2(-230, -230)
	_root.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.position = Vector2(16, 16)
	vbox.size = Vector2(panel.custom_minimum_size.x - 32, 420)
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	var reason := Label.new()
	reason.name = "Reason"
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.add_theme_font_size_override("font_size", 15)
	vbox.add_child(reason)

	var grid := VBoxContainer.new()
	grid.name = "Grid"
	var rows: Array[String] = [
		"TurnsLabel", "DateLabel", "CitiesLabel", "GloryLabel",
		"BattlesLabel", "GenerationsLabel",
	]
	for r in rows:
		var l := Label.new()
		l.name = r
		l.add_theme_font_size_override("font_size", 14)
		grid.add_child(l)
	vbox.add_child(grid)

	var card := VBoxContainer.new()
	card.name = "SuccessorCard"
	card.visible = false
	var card_label := Label.new()
	card_label.name = "CardLabel"
	card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_label.add_theme_font_size_override("font_size", 16)
	card.add_child(card_label)
	vbox.add_child(card)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(buttons)

	var successor_btn := Button.new()
	successor_btn.name = "SuccessorButton"
	successor_btn.text = "Знак переходит"
	successor_btn.custom_minimum_size = Vector2(0, 48)
	successor_btn.pressed.connect(func() -> void: successor_chosen.emit())
	buttons.add_child(successor_btn)

	# hero-survival: «Воскресить» — виден только с res_city (show_death).
	var resurrection_btn := Button.new()
	resurrection_btn.name = "ResurrectionButton"
	resurrection_btn.custom_minimum_size = Vector2(0, 48)
	resurrection_btn.visible = false
	resurrection_btn.pressed.connect(func() -> void: resurrection_chosen.emit())
	buttons.add_child(resurrection_btn)

	var chronicle_btn := Button.new()
	chronicle_btn.name = "ChronicleButton"
	chronicle_btn.text = "Летопись"
	chronicle_btn.custom_minimum_size = Vector2(0, 48)
	chronicle_btn.pressed.connect(func() -> void: chronicle_requested.emit())
	buttons.add_child(chronicle_btn)

	var menu_btn := Button.new()
	menu_btn.name = "MenuButton"
	menu_btn.text = "В меню"
	menu_btn.custom_minimum_size = Vector2(0, 48)
	menu_btn.pressed.connect(func() -> void: return_to_menu.emit())
	buttons.add_child(menu_btn)


func _unhandled_input(_event: InputEvent) -> void:
	# Страховка: пока открыт экран, ввод мира не проходит.
	if visible:
		get_viewport().set_input_as_handled()

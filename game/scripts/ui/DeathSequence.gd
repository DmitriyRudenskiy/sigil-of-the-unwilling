class_name DeathSequence
extends CanvasLayer

signal successor_chosen
signal return_to_menu
signal chronicle_requested
signal resurrection_chosen

var _wired := false


func show_death(
	deceased_name: String,
	cause: StringName,
	summary: Dictionary,
	successor: HeroController = null,
	res_city: City = null
) -> void:
	_wire_once()
	var title: Label = get_node("Root/Panel/VBox/Title")
	var reason: Label = get_node("Root/Panel/VBox/Reason")
	if successor == null:
		title.text = GameText.death_cycle_ends(deceased_name)
		title.add_theme_color_override("font_color", ThemeConfig.C_DEFEAT_TITLE)
	else:
		title.text = GameText.death_cycle_continues(deceased_name)
		title.add_theme_color_override("font_color", ThemeConfig.C_VICTORY_TITLE)
	reason.text = GameText.death_fell_in(GameText.death_cause(cause))

	var d: Dictionary = summary.get("date", {})
	var values: Dictionary = {
		"TurnsLabel": GameText.endgame_turns(int(summary.get("turns", 0))),
		"DateLabel": GameText.endgame_date(
			int(d.get("month", 1)), int(d.get("week", 1)), int(d.get("day", 1))),
		"CitiesLabel": GameText.endgame_cities(int(summary.get("cities_owned", 0))),
		"GloryLabel": GameText.endgame_glory(int(summary.get("glory", 0))),
		"BattlesLabel": GameText.endgame_battles(
			int(summary.get("battles_won", 0)), int(summary.get("battles_lost", 0))),
		"GenerationsLabel": GameText.endgame_generations(int(summary.get("generations", 1))),
	}
	var grid: VBoxContainer = get_node("Root/Panel/VBox/Grid")
	for l in grid.get_children():
		if l is Label:
			l.text = str(values.get(l.name, l.text))

	var card: VBoxContainer = get_node("Root/Panel/VBox/SuccessorCard")
	var successor_btn: Button = get_node("Root/Panel/VBox/Buttons/SuccessorButton")
	var resurrection_btn: Button = get_node("Root/Panel/VBox/Buttons/ResurrectionButton")
	var menu_btn: Button = get_node("Root/Panel/VBox/Buttons/MenuButton")
	var res_cost := GameNumbers.SUCCESSION_RESURRECT_IND
	var res_gold := GameNumbers.SUCCESSION_RESURRECT_GOLD
	if successor != null:
		var card_label: Label = card.get_node("CardLabel")
		card_label.text = GameText.death_successor(_successor_caption(successor))
		card.visible = true
		successor_btn.visible = true
		menu_btn.visible = false
		resurrection_btn.visible = res_city != null
		if res_city != null:
			resurrection_btn.text = GameText.death_resurrection_button(int(res_cost), int(res_gold))
	else:
		card.visible = false
		successor_btn.visible = false
		menu_btn.visible = true
		resurrection_btn.visible = false

	visible = true
	if (get_node("Root/Panel") as Control).is_inside_tree():
		UIAnimator.animate_in(get_node("Root/Panel"))


func _wire_once() -> void:
	if _wired:
		return
	_wired = true
	var buttons := get_node("Root/Panel/VBox/Buttons") as HBoxContainer
	var successor_btn := buttons.get_node("SuccessorButton") as Button
	successor_btn.text = GameText.death_successor_button()
	successor_btn.pressed.connect(_on_successor_pressed)
	(buttons.get_node("ResurrectionButton") as Button).pressed.connect(_on_resurrection_pressed)
	var chronicle_btn := buttons.get_node("ChronicleButton") as Button
	chronicle_btn.text = GameText.death_chronicle_button()
	chronicle_btn.pressed.connect(_on_chronicle_pressed)
	var menu_btn := buttons.get_node("MenuButton") as Button
	menu_btn.text = GameText.death_menu_button()
	menu_btn.pressed.connect(_on_menu_pressed)


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


func _on_successor_pressed() -> void:
	_close_and_emit(successor_chosen)


func _on_resurrection_pressed() -> void:
	_close_and_emit(resurrection_chosen)


func _on_chronicle_pressed() -> void:
	chronicle_requested.emit()


func _on_menu_pressed() -> void:
	_close_and_emit(return_to_menu)


func _close_and_emit(sig: Signal) -> void:
	visible = false
	sig.emit()
	queue_free()


func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()

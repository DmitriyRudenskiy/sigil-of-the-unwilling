class_name GameOverScreen
extends CanvasLayer

signal return_to_menu

var _wired := false


func show_result(result: String, reason: StringName, summary: Dictionary) -> void:
	_wire_once()
	var title: Label = get_node("Root/Panel/VBox/Title")
	var reason_label: Label = get_node("Root/Panel/VBox/Reason")
	title.text = GameText.endgame_victory() if result == "VICTORY" else GameText.endgame_defeat()
	title.add_theme_color_override(
		"font_color", ThemeConfig.C_VICTORY_TITLE if result == "VICTORY" else ThemeConfig.C_DEFEAT_TITLE)
	reason_label.text = GameText.endgame_reason(reason)

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
	for row_name in ["TurnsLabel", "DateLabel", "CitiesLabel", "GloryLabel",
			"BattlesLabel", "GenerationsLabel"]:
		grid.get_node(row_name).text = str(values[row_name])
	visible = true


func _wire_once() -> void:
	if _wired:
		return
	_wired = true
	var menu_btn := get_node("Root/Panel/VBox/MenuButton") as Button
	menu_btn.text = GameText.endgame_to_menu()
	menu_btn.pressed.connect(func() -> void: return_to_menu.emit())


func _unhandled_input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()

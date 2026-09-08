extends Control
class_name ArtifactChestDialog

const THEME_PATH := "res://assets/theme/game_theme.tres"

signal choice_made(choice: String, chest: ArtifactChest)

var _current_chest: ArtifactChest = null
var _artifact_label: Label = null
var _gold_label: Label = null
var _theme: Theme = null


func _ready() -> void:
	_theme = load(THEME_PATH)
	_apply_theme()
	_connect_skeleton()


func open(chest: ArtifactChest) -> void:
	_current_chest = chest
	_update_display()
	visible = true
	GameLogger.ui("Chest dialog opened at %s" % chest.cell)


func _apply_theme() -> void:
	if _theme == null:
		return
	var sb := _theme.get_stylebox("panel", "Panel")
	if sb:
		add_theme_stylebox_override("panel", sb)


func _connect_skeleton() -> void:
	_artifact_label = get_node_or_null("Margin/VBox/artifact_label") as Label
	_gold_label = get_node_or_null("Margin/VBox/gold_label") as Label
	var take := get_node_or_null("Margin/VBox/buttons/take")
	var gold := get_node_or_null("Margin/VBox/buttons/gold")
	var cancel := get_node_or_null("Margin/VBox/cancel")
	if take != null and not take.pressed.is_connected(_on_take):
		take.pressed.connect(_on_take)
	if gold != null and not gold.pressed.is_connected(_on_gold):
		gold.pressed.connect(_on_gold)
	if cancel != null and not cancel.pressed.is_connected(_on_close):
		cancel.pressed.connect(_on_close)


func _update_display() -> void:
	if _current_chest == null:
		return

	if _current_chest.artifact != null:
		var art := _current_chest.artifact
		_artifact_label.text = "%s\n(%s) ATK+%d DEF+%d" % [
			art.display_name, art.get_rarity_name(), art.get_attack(), art.get_defense()
		]
		_artifact_label.add_theme_color_override("font_color", art.get_rarity_color())
	else:
		_artifact_label.text = "Empty"
		_artifact_label.add_theme_color_override("font_color", ThemeConfig.C_TEXT_GRAY)

	_gold_label.text = "%d Gold" % _current_chest.gold_reward


func _on_take() -> void:
	if _current_chest != null:
		choice_made.emit("take", _current_chest)
	_close()


func _on_gold() -> void:
	if _current_chest != null:
		choice_made.emit("gold", _current_chest)
	_close()


func _on_close() -> void:
	_close()


func _close() -> void:
	_current_chest = null
	visible = false

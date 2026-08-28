extends Control
class_name ArtifactChestDialog
## Chest open dialog: artifact preview + Take/Gold buttons.

signal choice_made(choice: String, chest: ArtifactChest)

var _current_chest: ArtifactChest = null
var _artifact_label: Label = null
var _gold_label: Label = null


func open(chest: ArtifactChest) -> void:
	_current_chest = chest
	_build_layout()
	_update_display()
	visible = true
	GameLogger.ui("Chest dialog opened at %s" % chest.cell)


func _build_layout() -> void:
	for child in get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_bottom", 100)
	margin.add_theme_constant_override("margin_left", 200)
	margin.add_theme_constant_override("margin_right", 200)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_FILL
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "📦 Treasure Chest"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	# Separator
	vbox.add_child(HSeparator.new())

	# Artifact preview
	_artifact_label = Label.new()
	_artifact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_artifact_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_artifact_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_artifact_label)

	# Gold preview
	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	vbox.add_child(_gold_label)

	vbox.add_child(HSeparator.new())

	# Buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.size_flags_horizontal = SIZE_FILL
	vbox.add_child(btn_hbox)

	var btn_take := Button.new()
	btn_take.text = "✋ Artifact"
	btn_take.size_flags_horizontal = SIZE_FILL
	btn_take.pressed.connect(_on_take)
	btn_hbox.add_child(btn_take)

	var btn_gold := Button.new()
	btn_gold.text = "💰 Gold"
	btn_gold.size_flags_horizontal = SIZE_FILL
	btn_gold.pressed.connect(_on_gold)
	btn_hbox.add_child(btn_gold)

	# Cancel
	var btn_cancel := Button.new()
	btn_cancel.text = "Close"
	btn_cancel.pressed.connect(_on_close)
	vbox.add_child(btn_cancel)


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
		_artifact_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

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




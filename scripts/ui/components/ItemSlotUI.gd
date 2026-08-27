extends PanelContainer
class_name ItemSlotUI
## A single slot in the inventory grid showing an artifact.
## Emits `clicked(artifact)` and `hover_entered(artifact)` / `hover_exited()`.

signal clicked(artifact: Artifact)
signal hover_entered(artifact: Artifact)
signal hover_exited()

var artifact: Artifact = null:
	set(val):
		artifact = val
		if _icon != null:
			_update_display()

var _icon: TextureRect
var _name_label: Label
var _rarity_bar: ColorRect
var _hovering := false


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	add_theme_stylebox_override("panel", _create_panel_style())
	mouse_exited.connect(_on_mouse_exited)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(32, 32)
	vbox.add_child(_icon)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 9)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_name_label)

	_rarity_bar = ColorRect.new()
	_rarity_bar.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(_rarity_bar)

	_update_display()


func _update_display() -> void:
	if artifact == null:
		_icon.texture = null
		_name_label.text = ""
		_name_label.visible = false
		_rarity_bar.color = Color(0.15, 0.15, 0.15, 0.5)
		return

	_icon.texture = PlaceholderTexture.circle(32, artifact.get_rarity_color(), Color.BLACK)
	_name_label.text = artifact.display_name
	_name_label.visible = true
	_rarity_bar.color = artifact.get_rarity_color()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(artifact)
	elif event is InputEventMouseMotion:
		if not _hovering:
			_hovering = true
			hover_entered.emit(artifact)



func _on_mouse_exited() -> void:
	if _hovering:
		_hovering = false
		hover_exited.emit()


func _create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

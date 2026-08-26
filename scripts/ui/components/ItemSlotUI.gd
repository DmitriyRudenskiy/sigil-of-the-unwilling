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
		_update_display()

@onready var _icon: TextureRect = $Icon
@onready var _name_label: Label = $NameLabel
@onready var _rarity_bar: ColorRect = $RarityBar


func _ready() -> void:
	custom_minimum_size = Vector2(64, 64)
	add_theme_stylebox_override("panel", _create_panel_style())


func _update_display() -> void:
	if artifact == null:
		_icon.texture = null
		_name_label.text = ""
		_name_label.visible = false
		_rarity_bar.color = Color(0.15, 0.15, 0.15, 0.5)
		return

	_icon.texture = PlaceholderTexture.circle(32, _rarity_color(artifact.rarity), Color.BLACK)
	_name_label.text = artifact.display_name
	_name_label.visible = true
	_rarity_bar.color = _rarity_color(artifact.rarity)


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(artifact)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_entered.emit(artifact)
	elif event is InputEventMouseExit:
		hover_exited.emit()


func _rarity_color(rarity: Artifact.Rarity) -> Color:
	match rarity:
		Artifact.Rarity.MAJOR: return Color(0.4, 0.6, 1.0)
		Artifact.Rarity.RELIC: return Color(1.0, 0.75, 0.15)
		_: return Color(0.8, 0.8, 0.6)


func _create_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

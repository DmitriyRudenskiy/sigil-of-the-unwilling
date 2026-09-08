class_name ItemSlotUI
extends VBoxContainer

signal clicked(artifact: Artifact)
signal hover_entered(artifact: Artifact)
signal hover_exited()

var artifact: Artifact = null:
	set(val):
		artifact = val
		if _icon != null:
			_update_display()

@onready var _icon: TextureRect = $Icon
@onready var _name_label: Label = $Name
@onready var _rarity_bar: ColorRect = $Rarity
var _hovering := false


func _ready() -> void:
	mouse_exited.connect(_on_mouse_exited)
	_update_display()


func _update_display() -> void:
	if artifact == null:
		_icon.texture = null
		_name_label.text = ""
		_name_label.visible = false
		_rarity_bar.color = ThemeConfig.C_RARITY_TRACK
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

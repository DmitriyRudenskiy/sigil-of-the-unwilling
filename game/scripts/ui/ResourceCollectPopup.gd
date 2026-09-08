extends Panel
class_name ResourceCollectPopup

const SIZE := Vector2(240, 170)
const AUTO_DISMISS_SECONDS := 4.0


var _image: TextureRect:
	get: return get_node("Margin/VBox/Image") as TextureRect
var _label: Label:
	get: return get_node("Margin/VBox/Label") as Label
var _ok: Button:
	get: return get_node("Margin/VBox/OKButton") as Button
var _timer: Timer:
	get: return get_node("DismissTimer") as Timer


func _ready() -> void:
	_ok.pressed.connect(_on_ok)
	_timer.timeout.connect(_on_auto_dismiss)
	_apply_style()


func show_resource(resource_id: StringName, amount: int = 0) -> void:
	var tex: Texture2D = ResourceIcons.get_texture(resource_id)
	if tex == null:
		var border := ThemeConfig.C_POPUP_BORDER
		tex = PlaceholderTexture.circle(24, ThemeConfig.resource_color(resource_id), border)
	_image.texture = tex
	_label.text = "%s\n+%d" % [GameText.resource_name(resource_id), amount]
	visible = true
	if is_inside_tree():
		_timer.start()


func _on_ok() -> void:
	_timer.stop()
	visible = false


func _on_auto_dismiss() -> void:
	visible = false


func _apply_style() -> void:
	var theme: Theme = load("res://assets/theme/game_theme.tres")
	if theme == null:
		return
	var sb := theme.get_stylebox("panel", "Panel")
	if sb != null:
		add_theme_stylebox_override("panel", sb)

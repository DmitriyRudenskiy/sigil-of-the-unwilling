extends Panel
class_name ResourceCollectPopup
## resource-collection-popup: попап «Собрано ресурс»: иконка + имя/кол-во + OK.
##
## Код-билд, не .tscn (конвенция репо: DeathSequence/GameOverScreen/AdventureUI).
## Несуточный (non-modal): обычный Control на оверлей-слое AdventureUI —
## НЕ блокирует ввод мира (не PopupPanel с exclusive). Авто-скрывается через
## AUTO_DISMISS_SECONDS либо по кнопке OK. Повторный показ перезапускает таймер.
##
## Деградация (D5): неизвестный/пустой resource_id → заглушка-круг и имя = id;
## некорректное кол-во → 0.

const SIZE := Vector2(240, 170)
const AUTO_DISMISS_SECONDS := 4.0

var _image: TextureRect
var _label: Label
var _ok: Button
var _timer: Timer


func _init() -> void:
	# Скелет строится в _init: в headless-тестах _ready может не сработать.
	custom_minimum_size = SIZE
	visible = false

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var vb := VBoxContainer.new()
	vb.name = "VBox"
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)

	_image = TextureRect.new()
	_image.name = "Image"
	_image.custom_minimum_size = Vector2(56, 56)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(_image)

	_label = Label.new()
	_label.name = "Label"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	vb.add_child(_label)

	_ok = Button.new()
	_ok.name = "OKButton"
	_ok.text = "OK"
	_ok.pressed.connect(_on_ok)
	vb.add_child(_ok)

	_timer = Timer.new()
	_timer.name = "DismissTimer"
	_timer.one_shot = true
	_timer.wait_time = AUTO_DISMISS_SECONDS
	_timer.timeout.connect(_on_auto_dismiss)
	add_child(_timer)

	# Попап — прямой потомок CanvasLayer AdventureUI: координаты viewport,
	# центрируем якорями (размер фиксирован — SIZE).
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	offset_left = -SIZE.x * 0.5
	offset_top = -SIZE.y * 0.5
	offset_right = SIZE.x * 0.5
	offset_bottom = SIZE.y * 0.5

	_apply_style()


## Показ сбора. amount — точное целое кол-во, доставленное в инвентарь;
## при повторном вызове контент обновляется, таймер перезапускается.
func show_resource(resource_id: StringName, amount: int = 0) -> void:
	var tex: Texture2D = ResourceIcons.get_texture(resource_id)
	if tex == null:
		var border := Color(0.12, 0.10, 0.08, 0.9)
		tex = PlaceholderTexture.circle(24, ResourceIcons.get_color(resource_id), border)
	_image.texture = tex
	_label.text = "%s\n+%d" % [ResourceIcons.resource_name(resource_id), amount]
	visible = true
	# Таймер стартует только внутри дерева (headless-тесты без кадров:
	# Timer.start() вне дерева логит ERROR; авто-скрытие там не нужно).
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

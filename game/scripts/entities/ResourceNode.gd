extends Node2D
class_name ResourceNode

const HIDDEN_ICON_SCALE := 0.4

enum State { HIDDEN, DISCOVERED, EXHAUSTED }

signal state_changed(node: ResourceNode)
signal exhausted(node: ResourceNode)

var resource_id: StringName
var cell: Vector2i
var _state: int = State.HIDDEN
var _days_until_removal: int = 0
var _yield_amount: int = 0

var sprite: Sprite2D = null
var outline: Sprite2D = null

func init_node(r_id: StringName, c: Vector2i, initial_yield: int) -> void:
	resource_id = r_id
	cell = c
	_yield_amount = initial_yield
	_setup_visual()

func get_state() -> int:
	return _state

func is_hidden() -> bool:
	return _state == State.HIDDEN

func is_discovered() -> bool:
	return _state == State.DISCOVERED

func is_exhausted() -> bool:
	return _state == State.EXHAUSTED

func discover() -> void:
	if _state != State.HIDDEN:
		return
	_state = State.DISCOVERED
	state_changed.emit(self)
	_update_visual()

func exhaust() -> void:
	if _state != State.DISCOVERED:
		return
	_state = State.EXHAUSTED
	_days_until_removal = 3
	exhausted.emit(self)
	state_changed.emit(self)
	_update_visual()

func tick_day() -> int:
	_days_until_removal -= 1
	return _days_until_removal

func get_yield() -> int:
	return _yield_amount

func reduce_yield(amount: int) -> void:
	_yield_amount = max(0, _yield_amount - amount)
	if _yield_amount <= 0:
		exhaust()

func _setup_visual() -> void:

	sprite = $Sprite
	outline = $Outline
	_apply_texture()
	_update_visual()

func _apply_texture() -> void:
	var tex: Texture2D = ResourceAtlas.texture_for_id(resource_id)
	if tex == null:
		return
	sprite.texture = tex
	sprite.scale = Vector2(HIDDEN_ICON_SCALE, HIDDEN_ICON_SCALE)
	outline.texture = tex
	outline.scale = sprite.scale

func _update_visual() -> void:
	match _state:
		State.HIDDEN:
			sprite.modulate = ThemeConfig.C_WHITE_DIM_30
			outline.visible = false
		State.DISCOVERED:
			sprite.modulate = Color.WHITE
			outline.visible = true
			outline.modulate = ThemeConfig.C_GOLD_OUTLINE
		State.EXHAUSTED:
			sprite.modulate = ThemeConfig.C_GRAY_DIM_40
			outline.visible = false

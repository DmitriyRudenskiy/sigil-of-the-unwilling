extends Node
class_name CursorControllerAutoload

enum Mode { DEFAULT = 0, WALK = 1, COLLECT = 2, ATTACK = 3, CAST_SPELL = 4, TALK = 5 }

const MODE_ASSETS := {
	Mode.WALK:     {"path": "res://assets/cursors/cursor_walk.png", "size": 32, "hotspot": Vector2i(16, 28)},
	Mode.COLLECT:  {"path": "res://assets/cursors/cursor_collect.png", "size": 32, "hotspot": Vector2i(24, 8)},
	Mode.ATTACK:   {"path": "res://assets/cursors/cursor_attack.png", "size": 32, "hotspot": Vector2i(24, 24)},
	Mode.CAST_SPELL: {"path": "res://assets/cursors/cursor_spell.png", "size": 32, "hotspot": Vector2i(20, 20)},
	Mode.TALK: {"path": "res://assets/cursors/cursor_talk.png", "size": 32, "hotspot": Vector2i(16, 28)},
}
const COLLECT_HOLD_SECONDS := 0.6

var _current: int = Mode.DEFAULT
var _loaded: Dictionary = {}
var _collect_left: float = 0.0
var _collect_active: bool = false

func _ready() -> void:
	_connect_context(GameEventBus)

func _exit_tree() -> void:
	if is_node_ready():
		_disconnect_context(GameEventBus)

func _connect_context(bus: Node) -> void:
	bus.hero_moving_changed.connect(_on_hero_moving_changed)
	bus.resource_extracted.connect(_on_resource_extracted)
	bus.battle_completed.connect(_on_battle_completed)
	bus.battle_lost.connect(_on_battle_lost)

func _disconnect_context(bus: Node) -> void:
	if bus.hero_moving_changed.is_connected(_on_hero_moving_changed):
		bus.hero_moving_changed.disconnect(_on_hero_moving_changed)
	if bus.resource_extracted.is_connected(_on_resource_extracted):
		bus.resource_extracted.disconnect(_on_resource_extracted)
	if bus.battle_completed.is_connected(_on_battle_completed):
		bus.battle_completed.disconnect(_on_battle_completed)
	if bus.battle_lost.is_connected(_on_battle_lost):
		bus.battle_lost.disconnect(_on_battle_lost)

func _on_hero_moving_changed(moving: bool) -> void:
	_change_mode(Mode.WALK if moving else Mode.DEFAULT)

func _on_resource_extracted(_cell: Variant, _rid: Variant, _amount: Variant) -> void:
	_collect_active = true
	_collect_left = COLLECT_HOLD_SECONDS
	_change_mode(Mode.COLLECT)

func _on_battle_completed(_winner: BattleState.Side, _enemy_cell: Vector2i) -> void:
	_change_mode(Mode.DEFAULT)

func _on_battle_lost(_enemy_cell: Vector2i) -> void:
	_change_mode(Mode.DEFAULT)

func _process(delta: float) -> void:
	if _collect_active:
		_advance_collect(delta)

func _advance_collect(delta: float) -> void:
	_collect_left -= delta
	if _collect_left <= 0.0:
		_collect_active = false
		_change_mode(Mode.DEFAULT)

func set_mode(mode: int) -> void:
	_change_mode(mode)

func current_mode() -> int:
	return _current

func _change_mode(mode: int) -> void:
	if mode == _current:
		return
	_current = mode
	_apply_cursor(mode)
	GameLogger.info("cursor -> %s" % _mode_name(mode), "Cursor")

func _apply_cursor(mode: int) -> void:
	if mode == Mode.DEFAULT:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	var cfg = MODE_ASSETS.get(mode)
	if cfg is Dictionary and str(cfg.get("path", "")).ends_with(".png") and not cfg.get("path", "").is_empty():
		var tex := _load_texture(cfg.get("path", ""), int(cfg.get("size", 128)))
		if tex != null:
			Input.set_custom_mouse_cursor(tex, cfg.get("hotspot", Vector2i.ZERO))
			return
		GameLogger.warn("cursor: asset failed to load, staying DEFAULT: %s" % cfg.get("path", ""), "Cursor")
	_apply_default()

func _apply_default() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _load_texture(path: String, _size: int) -> Texture2D:
	if _loaded.has(path):
		return _loaded[path] as Texture2D
	var res := load(path)
	if res is Texture2D:
		_loaded[path] = res
		return res
	return null

func _mode_name(mode: int) -> String:
	match mode:
		Mode.WALK: return "WALK"
		Mode.COLLECT: return "COLLECT"
		Mode.ATTACK: return "ATTACK"
		Mode.CAST_SPELL: return "CAST_SPELL"
		Mode.TALK: return "TALK"
		_: return "DEFAULT"

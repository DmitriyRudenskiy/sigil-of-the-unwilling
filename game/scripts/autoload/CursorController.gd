extends Node
## Центральный контроллер контекстного системного курсора (autoload).
## Переключает системный курсор (Input.set_custom_mouse_cursor /
## set_default_cursor_shape) по контексту:
## DEFAULT (стрелка), WALK (ботинок), COLLECT (рука), ATTACK (два воина).
## Ассеты конфигурируемы; под неизвестный/нет ассета режим — стрелка (DEFAULT).
##
## ⚠️ АССЕТЫ НЕ ИДЕНФИЦИРОВАНЫ (tasks 0.1–0.2): cursor_01..31.png — unnamed
## 128×128 вырезки из sprite-листа, именованного соответствия режимам нет.
## Пока mapping не задан (path = "") все режимы падают в DEFAULT + лог.

enum Mode { DEFAULT = 0, WALK = 1, COLLECT = 2, ATTACK = 3 }

# ---------- Конфиг ассетов — заполнить по ответу пользователя (tasks 0.1–0.2) ----------
# path: "res://assets/cursors/cursor_XX.png"; size: 128; hotspot: (x,y) центра/указа.
const MODE_ASSETS := {
	Mode.WALK:     {"path": "", "size": 128, "hotspot": Vector2i(16, 96)},
	Mode.COLLECT:  {"path": "", "size": 128, "hotspot": Vector2i(96, 32)},
	Mode.ATTACK:   {"path": "", "size": 128, "hotspot": Vector2i(96, 32)},
}
## Держать курсор «рука» столько секунд после resource_extracted (анимация сбора).
const COLLECT_HOLD_SECONDS := 0.6

var _current: int = Mode.DEFAULT
# Динамический доступ к синглону Input: в headless-скане compile_all bare-идентификатор
# "Input" не резolvesится (parse-error), в то время как OS резолвится. Храним ссылку.
# ponytail: Engine.get_singleton — костыль ради прохода compile_all; на рунтайме Input
# доступен как глобальный синглон, можно было бы писать Input.set_default_mouse_cursor().
var _input: Object
var _loaded: Dictionary = {}
var _collect_left: float = 0.0
var _collect_active: bool = false

func _ready() -> void:
	_input = Engine.get_singleton("Input")
	_connect_context(GameEventBus)

## Подключить курсор к шине событий (вызвается из _ready; доступен для тестов).
func _connect_context(bus: Node) -> void:
	bus.hero_moving_changed.connect(_on_hero_moving_changed)
	bus.resource_extracted.connect(_on_resource_extracted)
	bus.battle_completed.connect(_on_battle_ended)
	bus.battle_lost.connect(_on_battle_ended)

# ==================== ПУТИ ИЗ ШИНЫ ====================

func _on_hero_moving_changed(moving: bool) -> void:
	_change_mode(Mode.WALK if moving else Mode.DEFAULT)

func _on_resource_extracted(_cell: Variant, _rid: Variant, _amount: Variant) -> void:
	_collect_active = true
	_collect_left = COLLECT_HOLD_SECONDS
	_change_mode(Mode.COLLECT)

func _on_battle_ended(_winner_or_cell: Variant, _enemy_cell: Variant = null) -> void:
	# battle_completed передаёт (winner, enemy_cell), battle_lost — один аргумент;
	# опциональный параметр покрывает обе сигнатуры сигнала.
	_change_mode(Mode.DEFAULT)

# ==================== ПРОЦЕСС ====================

func _process(delta: float) -> void:
	if _collect_active:
		_advance_collect(delta)

## Вынесено из _process — юнит-тест вызывает напрямую.
func _advance_collect(delta: float) -> void:
	_collect_left -= delta
	if _collect_left <= 0.0:
		_collect_active = false
		_change_mode(Mode.DEFAULT)

# ==================== ПУБЛИЧНЫЙ API ====================

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
	# Без синглона Input (напр. в headless-тесте) — просто отметить режим, не падать.
	if _input == null:
		return
	if mode == Mode.DEFAULT:
		# Стрелка: ни одного ассета, родной системный курсор Godot.
		# Godot 4.7: reset через set_default_cursor_shape (set_default_mouse_cursor
		# в API нет — SCRIPT ERROR на каждом запуске).
		_input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	var cfg = MODE_ASSETS.get(mode)
	if cfg is Dictionary and str(cfg.get("path", "")).ends_with(".png") and not cfg.get("path", "").is_empty():
		var tex := _load_texture(cfg.get("path", ""), int(cfg.get("size", 128)))
		if tex != null:
			_input.set_custom_mouse_cursor(tex, cfg.get("hotspot", Vector2i.ZERO))
			return
		# Ассет не загрузился — остаться на стрелке, не ронять игру.
		GameLogger.warn("cursor: asset failed to load, staying DEFAULT: %s" % cfg.get("path", ""), "Cursor")
	_apply_default()

func _apply_default() -> void:
	_input.set_default_cursor_shape(Input.CURSOR_ARROW)

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
		_: return "DEFAULT"

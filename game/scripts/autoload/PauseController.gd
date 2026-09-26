extends Node
## PauseController — центральный менеджер паузы со счётчиком ссылок.
##
## Решает проблему «залипшей паузы»: несколько систем (UI событий, бой)
## могут независимо запрашивать паузу; игра остаётся на паузе, пока хотя бы
## один владелец не отпустил свою. При смене сцены все выданные токены
## сбрасываются автоматически (scene_changed), поэтому уходящая сцена не
## может оставить дерево в приостановленном состоянии.

const GameLogger := preload("res://scripts/core/GameLogger.gd")

signal pause_state_changed(is_paused: bool)

var _depth: int = 0
var _next_token_id: int = 1
var _active_tokens: Dictionary[int, StringName] = {}

func _ready() -> void:
	# Сам контроллер должен работать даже на паузе.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_on_scene_changed)

## Запросить паузу. owner — имя подсистемы для диагностики.
## Возвращает токен; release(token, owner) обязателен (или scene_changed).
func acquire(owner: StringName = &"unknown") -> int:
	var token := _next_token_id
	_next_token_id += 1
	_active_tokens[token] = owner
	_depth += 1
	if _depth == 1:
		get_tree().paused = true
		pause_state_changed.emit(true)
	GameLogger.trace("Pause acquired by '%s' (depth=%d)" % [owner, _depth], "Pause")
	return token

## Отпустить паузу по токену. Повторный release того же токена — no-op.
func release(token: int, _owner: StringName = &"unknown") -> void:
	if not _active_tokens.has(token):
		# Stale/foreign token: уже отпущен или принадлежит прошлой сцене.
		return
	_active_tokens.erase(token)
	_depth = maxi(0, _depth - 1)
	if _depth == 0:
		get_tree().paused = false
		pause_state_changed.emit(false)
		GameLogger.trace("Pause released (depth=0)", "Pause")

## Принудительно снять всю паузу (загрузка сейва, game over, смена сцены).
func force_release_all() -> void:
	if _depth > 0 or not _active_tokens.is_empty():
		_depth = 0
		_active_tokens.clear()
		get_tree().paused = false
		pause_state_changed.emit(false)
		GameLogger.trace("Pause force-released", "Pause")

func is_paused() -> bool:
	return _depth > 0

func get_depth() -> int:
	return _depth

func _on_scene_changed(_scenetree: SceneTree) -> void:
	# Смена сцены: ни одна уходящая система не должна держать паузу.
	force_release_all()

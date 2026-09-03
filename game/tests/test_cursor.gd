extends "res://tests/test_base.gd"
## Тесты контекстного курсора: переключение режимов по GameEventBus,
## таймер COLLECT, публичный API, graceful fallback (ассеты не заданы).

const _CursorController = preload("res://scripts/autoload/CursorController.gd")
const _GameEventBus = preload("res://scripts/autoload/GameEventBus.gd")

var cc: Object
var bus: Node

func before_each() -> void:
	cc = _CursorController.new()
	bus = _GameEventBus.new()
	cc._connect_context(bus)

func after_each() -> void:
	if cc != null:
		cc.free()
		cc = null
	if bus != null:
		bus.free()
		bus = null

# ==================== РЕЖИМЫ ПО ШИНЕ ====================

func test_walk_moving_changes_mode() -> void:
	bus.hero_moving_changed.emit(true)
	assert_eq(cc.current_mode(), _CursorController.Mode.WALK, "moving -> WALK")

func test_walk_still_changes_mode() -> void:
	bus.hero_moving_changed.emit(false)
	assert_eq(cc.current_mode(), _CursorController.Mode.DEFAULT, "still -> DEFAULT")

func test_resource_extracted_sets_collect() -> void:
	bus.resource_extracted.emit(Vector2i(4, 4), &"silver", 2)
	assert_eq(cc.current_mode(), _CursorController.Mode.COLLECT, "extracted -> COLLECT")

func test_collect_timer_returns_to_default() -> void:
	bus.resource_extracted.emit(Vector2i(4, 4), &"silver", 2)
	assert_eq(cc.current_mode(), _CursorController.Mode.COLLECT, "COLLECT first")
	cc._advance_collect(_CursorController.COLLECT_HOLD_SECONDS)
	assert_eq(cc.current_mode(), _CursorController.Mode.DEFAULT, "after timer -> DEFAULT")

func test_collect_partial_delta_stays_collect() -> void:
	bus.resource_extracted.emit(Vector2i(4, 4), &"silver", 2)
	cc._advance_collect(0.3)  # меньше COLLECT_HOLD_SECONDS (0.6)
	assert_eq(cc.current_mode(), _CursorController.Mode.COLLECT, "partial delta stays COLLECT")

func test_battle_completed_resets_to_default() -> void:
	bus.battle_completed.emit(Vector2i(3, 3))
	assert_eq(cc.current_mode(), _CursorController.Mode.DEFAULT, "battle completed -> DEFAULT")

func test_battle_lost_resets_to_default() -> void:
	bus.battle_lost.emit(Vector2i(3, 3))
	assert_eq(cc.current_mode(), _CursorController.Mode.DEFAULT, "battle lost -> DEFAULT")

# ==================== ПУБЛИЧНЫЙ API ====================

func test_set_mode_attack() -> void:
	cc.set_mode(_CursorController.Mode.ATTACK)
	assert_eq(cc.current_mode(), _CursorController.Mode.ATTACK, "set_mode ATTACK")

func test_set_mode_same_is_noop() -> void:
	cc.set_mode(_CursorController.Mode.WALK)
	cc._change_mode(_CursorController.Mode.WALK)  # тот же режим — no-op
	assert_eq(cc.current_mode(), _CursorController.Mode.WALK, "same mode keeps WALK")

# ==================== GRACEFUL FALLBACK ====================

## Ассеты по умолчанию: path = "" → режим переключается, курсор не роняет (null-guard).
func test_unconfigured_mode_does_not_crash() -> void:
	cc.set_mode(_CursorController.Mode.WALK)
	assert_eq(cc.current_mode(), _CursorController.Mode.WALK, "unconfigured WALK still sets mode")
	cc.set_mode(_CursorController.Mode.ATTACK)
	assert_eq(cc.current_mode(), _CursorController.Mode.ATTACK, "unconfigured ATTACK still sets mode")

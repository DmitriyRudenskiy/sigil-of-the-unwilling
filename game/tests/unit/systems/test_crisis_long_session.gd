extends BaseTest

## Long-session stability for the crisis/event system
## (dynamic-world-crisis-system, Task 5.4 "Тестирование на длительной сессии
## (100+ ходов)").
##
## Drives CrisisEventSystem.on_day_passed() for 200 days against a real
## GameManager (mounted at /root/GameManager) with a fixed RNG seed and asserts
## the system stays stable: no crash, crises keep firing, and player stats
## (population/morale/resources) never run away.
##
## Also pins a real deadlock found while writing this test: active_events was
## only ever cleared on load/reset, so it accumulated forever. After
## max_active_events (3) fired, the on_day_passed gate
## `active_events.size() < max_active_events` blocked ALL further events — the
## event system deadlocked after exactly 3 events in a real session.

var _gm: GameManager = null
const DAYS := 200
const SEED := 20260927

func _sys() -> CrisisEventSystem:
	return make_node(CrisisEventSystem)

## Integration target: a real GameManager at /root/GameManager so
## CrisisEventSystem's get_node_or_null("/root/GameManager") resolves to it.
func _wire_game_manager() -> GameManager:
	_gm = GameManager.new()
	_gm.name = "GameManager"
	get_tree().root.add_child(_gm)
	return _gm

func after_test() -> void:
	if is_instance_valid(_gm):
		get_tree().root.remove_child(_gm)
		_gm.queue_free()
	_gm = null

func _count_history(sys: CrisisEventSystem, type: String) -> int:
	var n := 0
	for r in sys.event_history:
		if str(r.get("type", "")) == type:
			n += 1
	return n

## Task 5.4: 100+ turn long session. Must not crash and must keep the world in
## a sane state (stats clamped, both crises and events firing over time).
func test_long_session_stays_stable() -> void:
	var gm := _wire_game_manager()
	var sys := _sys()
	sys.set_difficulty(3)
	seed(SEED)
	for day in range(1, DAYS + 1):
		sys.on_day_passed(day)
	# Reaching here without a crash is the primary stability signal.
	assert_that(_count_history(sys, "crisis")).is_greater(0)
	assert_that(_count_history(sys, "event")).is_greater(0)
	assert_that(gm.get_population()).is_greater_equal(0)
	assert_that(gm.get_global_morale()).is_between(0, 100)
	assert_that(gm.get_resource("food")).is_greater_equal(0)
	assert_that(gm.get_resource("gold")).is_greater_equal(0)
	assert_that(gm.get_resource("wood")).is_greater_equal(0)

## Regression: the active_events deadlock. With 3 stale events accumulated (the
## old behavior), a new day must clear them so the spawn gate can fire again —
## otherwise the event system is permanently dead after 3 events.
func test_on_day_passed_clears_stale_active_events() -> void:
	var _gm := _wire_game_manager()
	var sys := _sys()
	sys.active_events.clear()
	sys.active_events.append(sys.event_templates[0])
	sys.active_events.append(sys.event_templates[1])
	sys.active_events.append(sys.event_templates[2])
	assert_that(sys.active_events.size()).is_equal(3)
	sys.day_counter = 39
	sys.next_event_day = 40
	sys.on_day_passed(40)
	# Stale events cleared; at most the just-triggered event may remain.
	assert_that(sys.active_events.size()).is_less_equal(1)

## Save/load round-trip mid-session: state survives a wipe+restore and the
## session continues without crashing.
func test_save_load_roundtrip_mid_session() -> void:
	var _gm := _wire_game_manager()
	var sys := _sys()
	sys.set_difficulty(3)
	seed(SEED + 2)
	for day in range(1, 101):
		sys.on_day_passed(day)
	var saved: Dictionary = sys.serialize_state()
	var sys2 := _sys()
	sys2.deserialize_state(saved)
	assert_that(sys2.day_counter).is_equal(100)
	assert_that(sys2.event_history.size()).is_equal(sys.event_history.size())
	for day in range(101, DAYS + 1):
		sys2.on_day_passed(day)
	assert_that(sys2.day_counter).is_equal(DAYS)

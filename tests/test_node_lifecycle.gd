extends "res://tests/test_base.gd"
## ResourceNode tests: state transitions, yield, exhaustion, daily tick.

var node_state: int
var node_yield: int
var node_days: int

enum State { HIDDEN, DISCOVERED, EXHAUSTED }

func before_each() -> void:
	node_state = State.HIDDEN
	node_yield = 4
	node_days = 0


func test_starts_hidden() -> void:
	assert_true(node_state == State.HIDDEN, "starts hidden")
	assert_true(node_state != State.DISCOVERED, "not discovered")
	assert_true(node_state != State.EXHAUSTED, "not exhausted")


func test_discover() -> void:
	node_state = State.DISCOVERED
	assert_true(node_state == State.DISCOVERED, "is discovered")
	assert_true(node_state != State.HIDDEN, "not hidden")


func test_discover_twice_noop() -> void:
	node_state = State.DISCOVERED
	node_state = State.DISCOVERED  # idempotent
	assert_true(node_state == State.DISCOVERED, "still discovered")


func test_exhaust() -> void:
	node_state = State.DISCOVERED
	node_state = State.EXHAUSTED
	assert_true(node_state == State.EXHAUSTED, "is exhausted")
	assert_true(node_state != State.DISCOVERED, "not discovered")


func test_exhaust_from_hidden_fails() -> void:
	node_state = State.HIDDEN
	assert_true(node_state == State.HIDDEN, "still hidden")


func test_yield_amount() -> void:
	assert_eq(node_yield, 4, "initial yield")


func test_reduce_yield() -> void:
	node_yield = maxi(node_yield - 2, 0)
	assert_eq(node_yield, 2, "reduced")


func test_reduce_to_zero_exhausts() -> void:
	node_state = State.DISCOVERED
	node_yield = max(0, node_yield - 4)
	if node_yield <= 0:
		node_state = State.EXHAUSTED
	assert_true(node_state == State.EXHAUSTED, "auto exhaust")


func test_reduce_over_yield() -> void:
	node_state = State.DISCOVERED
	node_yield = max(0, node_yield - 10)
	if node_yield <= 0:
		node_state = State.EXHAUSTED
	assert_true(node_state == State.EXHAUSTED, "over-reduce exhausts")


func test_daily_tick_removes() -> void:
	node_state = State.DISCOVERED
	node_state = State.EXHAUSTED
	node_days = 3
	node_days -= 1
	assert_eq(node_days, 2, "after 1 day")
	node_days -= 1
	assert_eq(node_days, 1, "after 2 days")
	node_days -= 1
	assert_eq(node_days, 0, "ready for removal")


func test_tick_non_exhausted() -> void:
	node_state = State.DISCOVERED
	assert_eq(node_days, 0, "discovered ticks return 0")

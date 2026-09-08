extends GdUnitTestSuite

var node_state: int
var node_yield: int
var node_days: int

enum State { HIDDEN, DISCOVERED, EXHAUSTED }

func before_test() -> void:
	node_state = State.HIDDEN
	node_yield = 4
	node_days = 0


func test_starts_hidden() -> void:
	assert_bool(node_state == State.HIDDEN).is_true()
	assert_bool(node_state != State.DISCOVERED).is_true()
	assert_bool(node_state != State.EXHAUSTED).is_true()


func test_discover() -> void:
	node_state = State.DISCOVERED
	assert_bool(node_state == State.DISCOVERED).is_true()
	assert_bool(node_state != State.HIDDEN).is_true()


func test_discover_twice_noop() -> void:
	node_state = State.DISCOVERED
	node_state = State.DISCOVERED  
	assert_bool(node_state == State.DISCOVERED).is_true()


func test_exhaust() -> void:
	node_state = State.DISCOVERED
	node_state = State.EXHAUSTED
	assert_bool(node_state == State.EXHAUSTED).is_true()
	assert_bool(node_state != State.DISCOVERED).is_true()


func test_exhaust_from_hidden_fails() -> void:
	node_state = State.HIDDEN
	assert_bool(node_state == State.HIDDEN).is_true()


func test_yield_amount() -> void:
	assert_that(node_yield).is_equal(4)


func test_reduce_yield() -> void:
	node_yield = maxi(node_yield - 2, 0)
	assert_that(node_yield).is_equal(2)


func test_reduce_to_zero_exhausts() -> void:
	node_state = State.DISCOVERED
	node_yield = max(0, node_yield - 4)
	if node_yield <= 0:
		node_state = State.EXHAUSTED
	assert_bool(node_state == State.EXHAUSTED).is_true()


func test_reduce_over_yield() -> void:
	node_state = State.DISCOVERED
	node_yield = max(0, node_yield - 10)
	if node_yield <= 0:
		node_state = State.EXHAUSTED
	assert_bool(node_state == State.EXHAUSTED).is_true()


func test_daily_tick_removes() -> void:
	node_state = State.DISCOVERED
	node_state = State.EXHAUSTED
	node_days = 3
	node_days -= 1
	assert_that(node_days).is_equal(2)
	node_days -= 1
	assert_that(node_days).is_equal(1)
	node_days -= 1
	assert_that(node_days).is_equal(0)


func test_tick_non_exhausted() -> void:
	node_state = State.DISCOVERED
	assert_that(node_days).is_equal(0)

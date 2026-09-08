extends GdUnitTestSuite
# TASK_09: ResourceNodeManager — обнаружение/добыча ресурсных узлов.

var _rnm: ResourceNodeManager
var _rng: RandomNumberGenerator


func before_test() -> void:
	_rnm = ResourceNodeManager.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 42
	_rnm.setup(null, _rng)


func test_discover_fails_on_empty_cell() -> void:
	var r := _rnm.try_discover(Vector2i(0, 0), {})
	assert_that(r["error"]).is_equal(ResourceNodeManager.NodeError.NODE_NOT_FOUND)


func test_extract_fails_on_hidden_node() -> void:
	_rnm._spawn_node(Vector2i(1, 1), &"oak", 4)
	var r := _rnm.try_extract(Vector2i(1, 1), {})
	assert_that(r["error"]).is_equal(ResourceNodeManager.NodeError.NOT_DISCOVERED)


func test_discover_with_skill() -> void:
	_rnm._spawn_node(Vector2i(1, 1), &"oak", 4)
	var r := _rnm.try_discover(Vector2i(1, 1), {&"nature_sense": 1})
	assert_that(r["discovered"]).is_true()
	assert_that(_rnm.get_node_at(Vector2i(1, 1)).is_discovered()).is_true()


func test_discover_twice_returns_already_discovered() -> void:
	_rnm._spawn_node(Vector2i(1, 1), &"oak", 4)
	_rnm.try_discover(Vector2i(1, 1), {&"nature_sense": 1})
	var r := _rnm.try_discover(Vector2i(1, 1), {&"nature_sense": 1})
	assert_that(r["error"]).is_equal(ResourceNodeManager.NodeError.ALREADY_DISCOVERED)


func test_extract_requires_key() -> void:
	_rnm._spawn_node(Vector2i(1, 1), &"oak", 4)
	_rnm.get_node_at(Vector2i(1, 1)).discover()
	var r := _rnm.try_extract(Vector2i(1, 1), {})
	assert_that(r["error"]).is_equal(ResourceNodeManager.NodeError.EXTRACTION_KEY_MISSING)


func test_extract_success() -> void:
	_rnm._spawn_node(Vector2i(1, 1), &"oak", 4)
	_rnm.get_node_at(Vector2i(1, 1)).discover()
	var r := _rnm.try_extract(Vector2i(1, 1), {&"strong_strike": 1})
	assert_that(r["error"]).is_equal(ResourceNodeManager.NodeError.OK)
	assert_that(r["amount"]).is_equal(4)


func after_test() -> void:
	if is_instance_valid(_rnm):
		for n in _rnm._nodes.values():
			n.free()
		_rnm.free()

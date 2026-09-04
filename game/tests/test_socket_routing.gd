extends "res://tests/gut_base.gd"
## Tests for the SocketController command-routing table (_COMMANDS) and the
## pre-dispatch validation in _route_command (R2, world-controller-decoupling).
## The handler-dispatch path calls get_tree() (lazy scene-tree lookup), which
## is null for a detached instance, so we exercise the routing table directly
## and the validation branches that run before that lookup.

const _SC = preload("res://scripts/autoload/SocketController.gd")

var _ctrl: Object

func before_each() -> void:
	# Detached instance: _init builds _COMMANDS + the extracted emulators/
	# serializers; no scene tree, no socket server.
	_ctrl = _SC.new()

func after_each() -> void:
	if is_instance_valid(_ctrl):
		_ctrl.free()

func test_commands_table_has_all_actions() -> void:
	var expected := ["START_GAME", "GET_STATE", "MOVE_TO", "END_TURN", "HERO_DIE",
		"SAVE_GAME", "LOAD_GAME", "COLLECT_HERE", "CITY_BUILD", "CITY_LEVEL",
		"CITY_HIRE", "CITY_CLOSE", "RETREAT", "FORCE_RETREAT", "GET_SPELLS",
		"CAST_SPELL", "EMULATE_BATTLE", "CAST_IN_BATTLE", "SEQUENCE_BATTLE",
		"BATTLE_SPELL", "SPELL_REGISTRY", "GET_METRICS"]
	var commands = _ctrl.get("_COMMANDS")
	for action in expected:
		var handler = commands.get(action)
		assert_true(handler.is_valid(), "_COMMANDS should have valid Callable for %s" % action)

func test_commands_table_unknown_action_absent() -> void:
	var commands = _ctrl.get("_COMMANDS")
	assert_false(commands.has("BOGUS_ACTION"), "_COMMANDS should not contain unknown actions")

func test_route_invalid_json_returns_error() -> void:
	var resp = _ctrl.call("_route_command", "{not valid json")
	assert_engine_error("error != Error::OK")  # JSON.parse_string шлёт engine-error на битом JSON
	assert_true(resp.has("error"), "invalid JSON should error, got %s" % str(resp))
	assert_true(str(resp["error"]).begins_with("Invalid JSON"), "error says Invalid JSON: %s" % str(resp.get("error")))

func test_route_missing_action_returns_error() -> void:
	var resp = _ctrl.call("_route_command", JSON.stringify({"foo": "bar"}))
	assert_true(resp.has("error"), "missing action should error, got %s" % str(resp))

func test_route_empty_action_returns_error() -> void:
	var resp = _ctrl.call("_route_command", JSON.stringify({"action": ""}))
	assert_true(resp.has("error"), "empty action should error, got %s" % str(resp))

func test_route_line_too_large_returns_error() -> void:
	var big = JSON.stringify({"action": "GET_METRICS", "pad": "x".repeat(200000)})
	var resp = _ctrl.call("_route_command", big)
	assert_true(resp.has("error"), "oversized line should error, got %s" % str(resp))
	assert_true(str(resp["error"]).begins_with("Command too large"), "error says too large: %s" % str(resp.get("error")))

func test_require_world_null_returns_error() -> void:
	var err = _ctrl.call("_require_world", null)
	assert_eq(err, {"error": "Not in World mode"}, "null world → Not in World mode")

func test_require_world_visible_returns_empty() -> void:
	var w := _FakeWorld.new()
	var err = _ctrl.call("_require_world", w)
	assert_eq(err, {}, "visible world → empty dict")
	w.free()

func test_extract_action_reads_field() -> void:
	var line = JSON.stringify({"action": "MOVE_TO", "x": 3})
	assert_eq(_ctrl.call("_extract_action", line), "MOVE_TO", "_extract_action returns the action")
	var garbage_action = _ctrl.call("_extract_action", "garbage")
	assert_engine_error("error != Error::OK")  # JSON.parse_string шлёт engine-error на "garbage"
	assert_eq(garbage_action, "UNKNOWN", "unparseable line → UNKNOWN")


class _FakeWorld extends Node:
	func is_world_visible() -> bool:
		return true

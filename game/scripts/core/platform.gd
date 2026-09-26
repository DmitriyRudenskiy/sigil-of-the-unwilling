class_name Platform
extends RefCounted

static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"

static func should_auto_quit() -> bool:
	return "--autoquit" in OS.get_cmdline_args()

static func is_test_framework_run() -> bool:
	var args = OS.get_cmdline_args()
	for arg in args:
		if "--add" in arg or "--gdUnit4" in arg or "GdUnitCmdTool.gd" in arg:
			return true
	# MCP-тесты (обёртка godot-headless ставит MCP_TEST=1) — игра не должна auto-quit в headless.
	return OS.get_environment("MCP_TEST") != ""

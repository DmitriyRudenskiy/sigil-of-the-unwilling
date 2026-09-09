class_name Platform
extends RefCounted

static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"

static func should_auto_quit() -> bool:
	return "--autoquit" in OS.get_cmdline_args()

static func is_test_framework_run() -> bool:
	return "--add" in OS.get_cmdline_args() or "--gdUnit4" in OS.get_cmdline_args() or "GdUnitCmdTool.gd" in OS.get_cmdline_args()

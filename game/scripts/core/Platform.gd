class_name Platform
extends RefCounted

static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"

static func should_auto_quit() -> bool:
	return "--autoquit" in OS.get_cmdline_args()

static func is_test_framework_run() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--add") and arg.contains("gdUnit4"):
			return true
		if arg.begins_with("--gdUnit4"):
			return true

		if arg.ends_with("GdUnitCmdTool.gd"):
			return true
	return false

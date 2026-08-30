class_name Platform
extends RefCounted
## Central abstraction for platform checks (headless, test-server, etc.).
## Replaces scattered OS.has_feature("headless") calls for testability.

static func is_headless() -> bool:
	return OS.has_feature("headless")


static func is_test_server() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--test-server"):
			return true
	return false


static func should_auto_quit() -> bool:
	return "--autoquit" in OS.get_cmdline_args()

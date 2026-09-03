class_name Platform
extends RefCounted
## Central abstraction for platform checks (headless, test-server, etc.).
## Replaces scattered OS.has_feature("headless") calls for testability.

## В Godot 4.7 OS.has_feature("headless") НЕ вернёт true для --headless —
## надёжный способ: DisplayServer.get_name() == "headless".
static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func is_test_server() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--test-server"):
			return true
	return false


## SocketController слушает 127.0.0.1:9095 только при этом флаге (или
## --test-server) — иначе второй инстанс процесса получает EADDRINUSE.
static func is_socket_server() -> bool:
	return is_test_server() or "--socket-server" in OS.get_cmdline_args()


static func should_auto_quit() -> bool:
	return "--autoquit" in OS.get_cmdline_args()

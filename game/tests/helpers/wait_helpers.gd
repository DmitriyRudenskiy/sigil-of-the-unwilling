class_name TestWait
extends RefCounted

## Поллинг состояния по кадрам с таймаутом.
static func wait_for(condition: Callable, timeout_ms: int = 10000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await Engine.get_main_loop().process_frame
	return condition.call()

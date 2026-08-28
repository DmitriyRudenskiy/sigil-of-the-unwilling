extends SceneTree

var _passed: int = 0
var _failed: int = 0
func _init():
	GameLogger.info("Logger test successful!")
	_passed = 1
	_failed = 0

	await process_frame
	quit()

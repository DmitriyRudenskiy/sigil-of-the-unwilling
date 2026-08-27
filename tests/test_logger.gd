extends SceneTree
func _init():
	GameLogger.info("Logger test successful!")
	await process_frame
	quit()

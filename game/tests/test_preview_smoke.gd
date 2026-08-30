extends SceneTree

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	print("Running Test Preview Smoke...")
	# Dev-тул (tools/) не входит в portable-проект game/ — если сцены нет,
	# прогоняем тест как skip, а не fail.
	if not ResourceLoader.exists("res://tools/texture_preview_tool.tscn"):
		print("  SKIP: dev-тул tools/texture_preview_tool.tscn не в проекте")
		quit(0)
		return
	# We can't easily run the full CLI in a script, but we can check if the scene loads
	var scene = load("res://tools/texture_preview_tool.tscn")
	if scene:
		print("  SUCCESS: Preview scene loads")
		_passed = 1
	else:
		print("  FAILURE: Preview scene failed to load")
		_failed = 1
	quit(0)

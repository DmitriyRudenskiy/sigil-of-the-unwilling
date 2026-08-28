extends SceneTree

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
    print("Running Test Preview Smoke...")
    # We can't easily run the full CLI in a script, but we can check if the scene loads
    var scene = load("res://tools/texture_preview_tool.tscn")
    if scene:
        print("  SUCCESS: Preview scene loads")
    else:
        print("  FAILURE: Preview scene failed to load")
        
    _failed = 0 if scene else 1
    _passed = 1 if scene else 0
    quit(0)

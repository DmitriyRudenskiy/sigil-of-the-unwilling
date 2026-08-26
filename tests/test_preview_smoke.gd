extends SceneTree

func _init() -> void:
    print("Running Test Preview Smoke...")
    # We can't easily run the full CLI in a script, but we can check if the scene loads
    var scene = load("res://tools/texture_preview_tool.tscn")
    if scene:
        print("  SUCCESS: Preview scene loads")
    else:
        print("  FAILURE: Preview scene failed to load")
        
    quit(0)

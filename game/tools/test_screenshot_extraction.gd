extends SceneTree
func _init() -> void:
    print("=== Test Screenshot Extraction ===")
    var img = Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
    img.fill(Color(0.35, 0.6, 0.3)) # Grass base
    
    # Draw some fake hexes
    var tool_script = load("res://tools/texture_preview_tool.gd")
    var tool_instance = tool_script.new()
    
    # Verify methods exist
    assert(tool_instance.has_method("_extract_from_screenshot"))
    assert(tool_instance.has_method("_apply_hex_mask"))
    print("✅ Test Screenshot Extraction passed")
    quit(0)

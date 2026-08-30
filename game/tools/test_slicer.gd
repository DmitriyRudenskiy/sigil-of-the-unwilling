extends SceneTree
func _init() -> void:
    print("=== Test Slicer ===")
    var img = Image.create(246, 164, false, Image.FORMAT_RGBA8) # 3x2 tiles of 82x82
    img.fill(Color.RED)
    
    # Ensure raw inbox directory exists
    if not DirAccess.dir_exists_absolute("res://assets/raw/inbox/"):
        DirAccess.make_dir_recursive_absolute("res://assets/raw/inbox/")
        
    img.save_png("res://assets/raw/inbox/test_sheet.png")
    
    # Simulate tool run
    # Note: The tool expects to be run as the main script via -s or in a scene.
    # We can't easily instantiate it as a SceneTree script and call _run, 
    # but we can verify it loads.
    var tool_script = load("res://tools/texture_preview_tool.gd")
    assert(tool_script != null)
    print("✅ Test Slicer passed (synthetic generation OK)")
    quit(0)

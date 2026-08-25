extends Control
class_name MainMenu

func _ready() -> void:
    _build_bg()
    _build_column()

func _build_bg() -> void:
    var bg := TextureRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    var path := "res://assets/ui/main_menu_bg.png"
    if ResourceLoader.exists(path):
        bg.texture = load(path)
    else:
        bg.texture = _placeholder()
        print("[Menu] No bg image, using placeholder")
    add_child(bg)

func _placeholder() -> ImageTexture:
    var img := Image.create(1920,1080,false,Image.FORMAT_RGBA8)
    for y in 1080:
        var t := float(y)/1080.0
        for x in 1920:
            img.set_pixel(x,y,Color(lerpf(0.08,0.02,t),lerpf(0.06,0.01,t),lerpf(0.15,0.05,t)))
    return ImageTexture.create_from_image(img)

func _build_column() -> void:
    var col := VBoxContainer.new()
    col.offset_left = 1560; col.offset_right = 1880; col.offset_top = 100; col.offset_bottom = 980
    col.alignment = BoxContainer.ALIGNMENT_BEGIN; col.add_theme_constant_override("separation", 20)
    add_child(col)
    # Lock panel
    var lp := PanelContainer.new()
    var ls := StyleBoxFlat.new(); ls.bg_color = Color(0.35,0.35,0.38,0.85)
    ls.set_corner_radius_all(8); ls.set_border_width_all(2); ls.border_color = Color(0.5,0.5,0.55)
    lp.add_theme_stylebox_override("panel", ls); lp.custom_minimum_size = Vector2(300,180)
    col.add_child(lp)
    var lvb := VBoxContainer.new(); lvb.alignment = BoxContainer.ALIGNMENT_CENTER; lp.add_child(lvb)
    var li := Label.new(); li.text = "🔒"; li.add_theme_font_size_override("font_size", 64)
    li.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lvb.add_child(li)
    var lt := Label.new(); lt.text = "Locked"; lt.add_theme_font_size_override("font_size", 16)
    lt.add_theme_color_override("font_color", Color(0.7,0.7,0.7))
    lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lvb.add_child(lt)
    # 3 blue buttons
    for bd in [["New Game","_new"],["Load","_load"],["Exit","_exit"]]:
        var btn := Button.new(); btn.text = bd[0]; btn.custom_minimum_size = Vector2(300,70)
        btn.add_theme_font_size_override("font_size", 24)
        var sn := StyleBoxFlat.new(); sn.bg_color = Color(0.15,0.35,0.75)
        sn.set_corner_radius_all(10); sn.set_border_width_all(2); sn.border_color = Color(0.3,0.5,0.9)
        btn.add_theme_stylebox_override("normal", sn)
        var sh := sn.duplicate(); sh.bg_color = Color(0.2,0.45,0.9)
        btn.add_theme_stylebox_override("hover", sh)
        btn.add_theme_color_override("font_color", Color(0.9,0.95,1.0))
        btn.pressed.connect(Callable(self, bd[1])); col.add_child(btn)

func _new() -> void: get_tree().change_scene_to_file("res://scenes/World.tscn")
func _load() -> void: print("Load: not implemented")
func _exit() -> void: get_tree().quit()

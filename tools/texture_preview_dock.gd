@tool
extends VBoxContainer
class_name TexturePreviewDock

var input_path_edit: LineEdit
var mode_option: OptionButton
var run_button: Button

func _ready() -> void:
    input_path_edit = LineEdit.new()
    input_path_edit.placeholder_text = "Path to texture sheet/screenshot"
    add_child(input_path_edit)
    
    mode_option = OptionButton.new()
    mode_option.add_item("Sheet")
    mode_option.add_item("Screenshot")
    add_child(mode_option)
    
    run_button = Button.new()
    run_button.text = "Slice & Preview"
    run_button.pressed.connect(_on_run_pressed)
    add_child(run_button)

func _on_run_pressed() -> void:
    var path = input_path_edit.text
    if path.is_empty():
        print("Please enter a path")
        return
        
    var mode = "sheet" if mode_option.selected == 0 else "screenshot"
    var cmd = "godot --path \"$(pwd)\" res://tools/texture_preview_tool.gd --mode %s --input %s" % [mode, path]
    
    print("Executing: %s" % cmd)
    OS.execute(cmd, [])

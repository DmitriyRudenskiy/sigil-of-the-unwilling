@tool
extends EditorPlugin

var dock: Control

func _enter_tree() -> void:
    var dock_script = load("res://tools/texture_preview_dock.gd")
    dock = dock_script.new()
    add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _exit_tree() -> void:
    remove_control_from_docks(dock)
    dock.queue_free()

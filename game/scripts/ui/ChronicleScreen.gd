class_name ChronicleScreen
extends CanvasLayer

signal closed

const _Entry = preload("res://scenes/ui/ChronicleEntry.tscn")

@onready var _panel: Panel = $Root/Panel
@onready var _list: VBoxContainer = $Root/Panel/VBox/Scroll/List
@onready var _close_btn: Button = $Root/Panel/VBox/CloseButton

var _wired := false

func _init() -> void:
    layer = 120
    visible = false

func _ready() -> void:
    if not _wired:
        _wired = true
        get_node("Root/Panel/VBox/Title").text = GameText.chronicle_title()
        _close_btn.text = GameText.chronicle_close()
        _close_btn.pressed.connect(_on_close_pressed)

func show_entries(entries: Array) -> void:
    _populate_list(entries)
    visible = true
    if _panel.is_inside_tree():
        UIAnimator.animate_in(_panel)

func _populate_list(entries: Array) -> void:

    for child: Control in _list.get_children():
        child.queue_free()
    var count := entries.size()
    for i in range(count - 1, -1, -1):
        var e: Dictionary = entries[i]
        var l: Label = _Entry.instantiate()
        l.text = _entry_line(e)
        _list.add_child(l)
    if count == 0:
        var empty: Label = _Entry.instantiate()
        empty.text = GameText.chronicle_empty()
        empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _list.add_child(empty)

func _entry_line(e: Dictionary) -> String:
    var outcome := str(e.get("outcome", "?"))
    var icon := "👑" if outcome == "VICTORY" else "💀" if outcome == "DEFEAT" else "🔁"
    return GameText.chronicle_entry(
        icon,
        int(e.get("generation", 0)),
        str(e.get("hero_name", "?")),
        str(e.get("path", "")),
        outcome,
        int(e.get("end_turn", 0)),
        int(e.get("glory", 0)),
        int(e.get("battles_won", 0)),
        int(e.get("battles_lost", 0)),
    )

func _on_close_pressed() -> void:
    visible = false
    closed.emit()

func _unhandled_input(_event: InputEvent) -> void:
    if visible:
        get_viewport().set_input_as_handled()

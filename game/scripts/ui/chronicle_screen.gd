class_name ChronicleScreen
extends CanvasLayer

signal closed

const _Entry = preload("res://scenes/ui/chronicle_entry.tscn")

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
    _set_title(GameText.chronicle_title())
    _populate_list(entries)
    visible = true
    if _panel.is_inside_tree():
        UIAnimator.animate_in(_panel)

## D-240: кампейн-режим — запись `ChronicleLog.records()` ([{turn, lines}]).
## Легаси `show_entries` не тронут: у него другой носитель (строки итога забега),
## и его вызывают main_menu / world_ui_manager / hero_lifecycle_system.
## Заголовок тоже разный: «Летопись поколений» — про династию, кампейн-лента —
## «Хроника» поселения (00-glossary: «лог-нарратив кампании»).
func show_records(records: Array) -> void:
    _set_title(GameText.chronicle_campaign_title())
    _populate_records(records)
    visible = true
    if _panel.is_inside_tree():
        UIAnimator.animate_in(_panel)

func _set_title(text: String) -> void:
    var title: Label = get_node_or_null("Root/Panel/VBox/Title")
    if title != null:
        title.text = text

## Лента: свежие ходы сверху (тот же порядок, что в легаси-списке), внутри хода
## записи идут в хронологическом порядке — иначе заголовок дня уезжал бы под
## свои же строки.
## Перенос (`autowrap_mode`) работает только при `horizontal_scroll_mode = 0` у
## `Scroll` (сцена): со скроллом-авто контейнер даёт Label бесконечную ширину, и
## строка хроники уезжает за край панели вместо переноса.
func _populate_records(records: Array) -> void:
    for child: Control in _list.get_children():
        child.queue_free()
    if records.is_empty():
        var empty: Label = _Entry.instantiate()
        empty.text = GameText.chronicle_empty()
        empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _list.add_child(empty)
        return
    var days: Array = []
    var day_turns: Array[int] = []
    for rec in records:
        var turn := int((rec as Dictionary).get("turn", 0))
        if day_turns.is_empty() or day_turns[day_turns.size() - 1] != turn:
            day_turns.append(turn)
            days.append([])
        (days[days.size() - 1] as Array).append(rec)
    for d in range(day_turns.size() - 1, -1, -1):
        var header: Label = _Entry.instantiate()
        header.text = GameText.chronicle_turn(day_turns[d])
        _list.add_child(header)
        for rec in days[d]:
            for line in (rec as Dictionary).get("lines", []):
                var l: Label = _Entry.instantiate()
                l.text = GameText.chronicle_line(
                    str((line as Dictionary).get("key", "")),
                    (line as Dictionary).get("args", {}))
                l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                _list.add_child(l)


func _populate_list(entries: Array) -> void:
    for child: Control in _list.get_children():
        child.queue_free()
    var count := entries.size()
    for i in range(count - 1, -1, -1):
        var e: Dictionary = entries[i]
        var l: Label = _Entry.instantiate()
        l.text = _entry_line(e)
        # Перенос — не украшение: с выключенным горизонтальным скроллом (см. сцену)
        # длинная строка итога забега без autowrap не уезжала бы за край, а
        # обрезалась бы — чтение хроники не должно зависеть от ширины фразы.
        l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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

class_name QuestJournalScreen
extends CanvasLayer
## quests-reputation-system 4.1: журнал квестов (активные/завершённые/проваленные).
## Программа — без .tscn (headless-безопасно, как большинство панелей).

signal quest_turned_in(quest_id: String)

const QuestSystem = preload("res://scripts/systems/quest_system.gd")
const HeroFactions = preload("res://scripts/data/hero_factions.gd")

var _panel: Panel
var _list: VBoxContainer
var _close_btn: Button
var _tab := "active"  # active | completed | failed
var _last_state: Dictionary = {}

func _init() -> void:
	layer = 120
	visible = false
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(560, 480)
	_panel.size = Vector2(560, 480)
	_panel.position = -_panel.size / 2
	root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 12
	vbox.offset_top = 12
	vbox.offset_right = -12
	vbox.offset_bottom = -12
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Журнал квестов"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var tabs := HBoxContainer.new()
	vbox.add_child(tabs)
	for t in ["active", "completed", "failed"]:
		var b := Button.new()
		b.text = {"active": "Активные", "completed": "Завершённые", "failed": "Проваленные"}[t]
		b.toggle_mode = true
		b.button_pressed = (t == _tab)
		b.pressed.connect(_on_tab_pressed.bind(t))
		tabs.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_close_btn = Button.new()
	_close_btn.text = "Закрыть"
	_close_btn.pressed.connect(func(): visible = false)
	vbox.add_child(_close_btn)

func show_journal(state: Dictionary) -> void:
	_populate(state)
	visible = true

func _on_tab_pressed(tab: String) -> void:
	_tab = tab
	# state хранится в последнем show_journal
	if not _last_state.is_empty():
		_populate(_last_state)

func _populate(state: Dictionary) -> void:
	_last_state = state
	for child: Control in _list.get_children():
		child.queue_free()
	var source: Dictionary = state.get(_tab, {})
	if source.is_empty():
		var empty := Label.new()
		empty.text = "Пусто"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(empty)
		return
	for quest_id: String in source:
		var q: Dictionary = source[quest_id]
		_list.add_child(_quest_row(quest_id, q, _tab == "active"))

func _quest_row(quest_id: String, q: Dictionary, is_active: bool) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	var progress: int = int(q.get("progress", 0))
	var target: int = int(q.get("target_count", 0))
	var text: String = str(q.get("title", quest_id)) + " — %s" % HeroFactions.faction_name(str(q.get("faction_id", "")))
	if is_active:
		text += "  [%d/%d]" % [progress, target]
		if progress >= target:
			var turn_in := Button.new()
			turn_in.text = "Сдать"
			turn_in.pressed.connect(func(): quest_turned_in.emit(quest_id))
			row.add_child(label)
			row.add_child(turn_in)
			return row
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row

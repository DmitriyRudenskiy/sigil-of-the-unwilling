class_name TeamDialogScreen
extends Control
## team-romance-roleplay 5.2/5.3: диалоги с последователями + сцены-события.
## Интерактивный режим: open_dialog(hero, follower) — сцена по стадиям,
## варианты с эффектами, Esc — закрыть.
## Событийный режим: open_event(hero, index) — сцена из pending_scenes,
## блокирующий (pause), выбор обязателен.
## Контент: assets/data/team_dialogs/*.json (TeamDialogData/TeamDialogSystem).

signal dialog_finished

const EVENT_SCENE_FILES := {
	"jealousy": "jealousy",
	"conflict": "conflict",
	"betrayal": "betrayal",
	"proposal": "proposal",
	"marriage": "wedding",
}
## Варианты сцены-события, применяемые через resolve_pending.
const EVENT_CHOICES := ["confirm", "decline", "soothe", "ignore", "joke", "reconcile", "sever"]

## Пакетные прогоны (autopilot/MCP): сцены не открываются автоматически.
## Тесты выключают флаг через группу "team_dialog" (static через class_name
## не компилируется в MCP eval).
var ui_enabled := true

var _hero = null
var _follower: Follower = null
var _ctx: Dictionary = {}
var _dialog_id := ""
var _node_id := ""
var _event: Dictionary = {}  # {} = интерактивный режим
var _event_index := -1
var _event_applied := false
var _mode_event := false

var _title: Label
var _line_label: Label
var _choices_box: VBoxContainer
var _consequence: Label
var _close_btn: Button

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("team_dialog")
	_title = get_node("Panel/VBox/Title") as Label
	_line_label = get_node("Panel/VBox/Line") as Label
	_choices_box = get_node("Panel/VBox/Choices") as VBoxContainer
	_consequence = get_node("Panel/VBox/Consequence") as Label
	_close_btn = get_node("Panel/VBox/CloseButton") as Button
	_close_btn.pressed.connect(_on_close_pressed)

func is_open() -> bool:
	return visible

## Интерактивный диалог с последователем.
func open_dialog(hero, follower: Follower) -> void:
	if follower == null:
		return
	_hero = hero
	_follower = follower
	_event = {}
	_event_index = -1
	_event_applied = false
	_mode_event = false
	_ctx = TeamDialogSystem.make_context(hero, follower)
	_dialog_id = TeamDialogSystem.pick_dialog(_ctx)
	if _dialog_id.is_empty():
		return
	var d: Dictionary = TeamDialogSystem.get_dialog(_dialog_id)
	_node_id = String(d.get("entry", ""))
	_consequence.text = ""
	_render()
	show()

## Сцена-событие из pending_scenes (блокирующая).
func open_event(hero, index: int) -> void:
	var rel = hero.relationships
	if rel == null or index < 0 or index >= rel.pending_scenes.size():
		return
	_hero = hero
	_event = rel.pending_scenes[index]
	_event_index = index
	_event_applied = false
	_mode_event = true
	var uid := int(_event.get("uid", 0))
	_follower = _find_follower(uid)
	_ctx = TeamDialogSystem.make_context(hero, _follower) if _follower != null else {}
	_open_event_content()
	show()
	_set_paused(true)

## Предательство: последователь уже ушёл — псевдо-сцена (без resolve_pending).
func open_betrayal(hero, uid: int) -> void:
	_hero = hero
	_follower = null
	_event = {"type": "betrayal", "uid": uid}
	_event_index = -1
	_event_applied = false
	_mode_event = true
	_ctx = {}
	_open_event_content()
	show()
	_set_paused(true)

func _open_event_content() -> void:
	var type := String(_event.get("type", ""))
	_dialog_id = String(EVENT_SCENE_FILES.get(type, type))
	if not TeamDialogSystem.has_dialog(_dialog_id):
		_dialog_id = "talk_generic"
	var d: Dictionary = TeamDialogSystem.get_dialog(_dialog_id)
	_node_id = String(d.get("entry", ""))
	_consequence.text = ""
	_render()

func _render() -> void:
	var d: Dictionary = TeamDialogSystem.get_dialog(_dialog_id)
	if d.is_empty():
		_close()
		return
	var nodes: Dictionary = d.get("nodes", {})
	var node: Dictionary = nodes.get(_node_id, {})
	if node.is_empty():
		_close()
		return
	_title.text = _title_text()
	var lines: Array = TeamDialogSystem.visible_lines(node, _ctx)
	var first: Dictionary = lines[0] if not lines.is_empty() else {}
	_line_label.text = String(first.get("text", ""))
	for c in _choices_box.get_children():
		c.queue_free()
	var choices: Array = TeamDialogSystem.visible_choices(node, _ctx, Settings.content_adult)
	for c in choices:
		var cd: Dictionary = c
		var btn := Button.new()
		btn.text = String(cd.get("text", ""))
		btn.custom_minimum_size = Vector2(420, 40)
		btn.pressed.connect(_on_choice.bind(cd))
		_choices_box.add_child(btn)
	_close_btn.visible = not _mode_event

func _title_text() -> String:
	if not _mode_event:
		return _follower.name if _follower != null else ""
	match String(_event.get("type", "")):
		"jealousy": return "Ревность"
		"conflict": return "Конфликт"
		"betrayal": return "Предательство"
		"proposal": return "Предложение"
		"marriage": return "Свадьба"
	return "Событие"

func _on_choice(cd: Dictionary) -> void:
	if not _mode_event:
		if _follower != null:
			TeamDialogSystem.apply_effects(_hero, _follower, cd.get("effects", []))
		_consequence.text = _effects_hint(cd.get("effects", []))
		_next(String(cd.get("next", "")))
		return
	var choice_id := String(cd.get("id", ""))
	if not _event_applied and _event_index >= 0 and EVENT_CHOICES.has(choice_id):
		var rel = _hero.relationships
		if rel != null:
			rel.resolve_pending(_event_index, choice_id)
		_event_applied = true
	_next(String(cd.get("next", "")))

func _next(node_id: String) -> void:
	if node_id.is_empty():
		_close()
	else:
		_node_id = node_id
		_consequence.text = ""
		_render()

func _on_close_pressed() -> void:
	if not _mode_event:
		_close()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and not _mode_event and event is InputEventKey \
			and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	_set_paused(false)
	hide()
	_mode_event = false
	_event = {}
	dialog_finished.emit()
	# Если в очереди ещё сцены (предложение после диалога, несколько событий) — открыть следующую.
	if ui_enabled and _hero != null:
		var rel = _hero.relationships
		if rel != null and not rel.pending_scenes.is_empty():
			open_event(_hero, 0)

func _set_paused(on: bool) -> void:
	if get_tree() != null:
		get_tree().paused = on

func _find_follower(uid: int):
	if _hero == null:
		return null
	for f in _hero.followers:
		if f != null and int(f.uid) == uid:
			return f
	return null

## Индикатор последствий выбора (5.2).
func _effects_hint(effects: Array) -> String:
	var parts: Array[String] = []
	for e in effects:
		if not (e is Dictionary):
			continue
		var ed: Dictionary = e
		if ed.has("bond"):
			parts.append("связь %d" % int(ed["bond"]))
		if ed.has("trust"):
			parts.append("верность %d" % int(ed["trust"]))
		if ed.has("romance"):
			parts.append("романтика %d" % int(ed["romance"]))
		if ed.has("stat"):
			parts.append("%s %d" % [String(ed["stat"]), int(ed.get("delta", 1))])
		if ed.has("buff"):
			parts.append("боевой дух +%d на %d ходов" % [int(ed.get("value", 1)), int(ed.get("turns", 5))])
		if ed.has("event"):
			parts.append("сцена: %s" % String(ed["event"]))
		if ed.has("item"):
			parts.append("предмет: %s" % String(ed["item"]))
	return ", ".join(parts)

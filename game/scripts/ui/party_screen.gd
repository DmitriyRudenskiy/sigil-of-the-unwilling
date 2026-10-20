class_name PartyScreen
extends Control

## mvp-ui-flow 3.1 (K-M8): экран партии — ТЕХНИЧЕСКАЯ/плейсхолдерная
## реализация (headless-тестируема). Визуальная раскладка/тема/иконки —
## ui-mockup-parity (зона владельца), здесь только структура и данные.
##
## Данные — PartyScreenModel (view model) поверх state.party. PartySystem —
## статические функции без сигналов → обновление ЯВНОЕ: хост (main.gd /
## CampaignUIManager) вызывает refresh(party, ...) при изменениях партии
## (после боя/хода/тренировки). Сигнал screen_updated — для визуального слоя.
##
## Структура (детерминированная, для тестов):
##   Root (VBox)
##     Header   (Label)  — «Партия: X/Y»
##     Slot<i>  (Panel)  — занятый слот (Line1: кто; Line2: XP/ветеран/статы/Удача)
##     EmptySlot<i> (Panel) — свободный слот
##     SlotHint (Label)  — подсказка 3.2 «что освободит слот» (видна, когда show)
##
## Инварианты: не больше capacity слотов; party > capacity → первые capacity
## (защита от невалидного состояния, не «лечение» данных).

const Model = preload("res://scripts/ui/party_screen_model.gd")
const PS = preload("res://scripts/campaign/party_system.gd")

signal screen_updated(model: Dictionary)

## Порядок атрибутов в строке (D&D 6).
const STAT_KEYS: Array[String] = ["str", "dex", "con", "int", "wis", "cha"]

var _model: Dictionary = {}
var _root: VBoxContainer


func _ready() -> void:
	_root = VBoxContainer.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)


## Обновить экран по данным партии. `training_options` — прокинут хостом из
## CampaignTrainingService.available_training_actions(); [] — без опций.
## Длина очереди тренировки в MVP всегда 0 (immediate, без прогресса).
func refresh(party: Array, capacity: int = Model.DEFAULT_CAPACITY, training_options: Array = []) -> void:
	_model = Model.build_model(party, capacity, 0, training_options)
	_rebuild()
	screen_updated.emit(_model)


## Последняя построенная модель (для тестов/внешнего слоя).
func get_model() -> Dictionary:
	return _model


func get_header_text() -> String:
	var roster: Dictionary = _model.get("roster", {})
	return "Партия: %d/%d" % [int(roster.get("alive_count", 0)), int(roster.get("capacity", 0))]


func get_hint_visible() -> bool:
	var hint: Dictionary = _model.get("slot_hint", {})
	return bool(hint.get("show", false))


func get_hint_text() -> String:
	var hint: Dictionary = _model.get("slot_hint", {})
	return str(hint.get("text", ""))


func get_slot_count() -> int:
	var roster: Dictionary = _model.get("roster", {})
	return int(roster.get("capacity", 0))


func _rebuild() -> void:
	for child in _root.get_children():
		child.queue_free()
	var roster: Dictionary = _model.get("roster", {})
	var header := Label.new()
	header.name = "Header"
	header.text = get_header_text()
	_root.add_child(header)
	var members: Array = roster.get("members", [])
	var capacity: int = int(roster.get("capacity", Model.DEFAULT_CAPACITY))
	# Инвариант: не больше capacity слотов (party > capacity → первые capacity).
	var shown: int = mini(members.size(), capacity)
	for i in range(capacity):
		if i < shown:
			_root.add_child(_member_row(i, members[i]))
		else:
			_root.add_child(_empty_slot_row(i))
	var hint := Label.new()
	hint.name = "SlotHint"
	hint.text = get_hint_text()
	hint.visible = get_hint_visible()
	_root.add_child(hint)


func _member_row(index: int, member: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Slot%d" % index
	var box := VBoxContainer.new()
	box.name = "Box"
	panel.add_child(box)
	var line1 := Label.new()
	line1.name = "Line1"
	var state_tag := ""
	if str(member.get("state", PS.STATE_READY)) == PS.STATE_DEAD:
		state_tag = " [МЁРТВ]"
	line1.text = "%s — %s, %s, ур. %d%s" % [
		str(member.get("id", "")),
		str(member.get("class", "")),
		str(member.get("race", "")),
		int(member.get("level", 1)),
		state_tag,
	]
	box.add_child(line1)
	var line2 := Label.new()
	line2.name = "Line2"
	line2.text = _stats_line(member)
	box.add_child(line2)
	return panel


func _stats_line(member: Dictionary) -> String:
	var parts: Array[String] = []
	var stats: Dictionary = member.get("stats", {})
	for key in STAT_KEYS:
		parts.append("%s %d" % [key, int(stats.get(key, 10))])
	var line: String = "XP %d · " % int(member.get("xp", 0)) + " ".join(parts)
	var luck: int = int(member.get("luck", 0))
	line += " · Удача %d" % luck
	if bool(member.get("is_veteran", false)):
		line += " · Ветеран"
	return line


func _empty_slot_row(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "EmptySlot%d" % index
	var label := Label.new()
	label.name = "Label"
	label.text = "Свободный слот"
	panel.add_child(label)
	return panel

class_name SaveLoadScreen
extends Control

signal load_requested(slot: int)
signal delete_requested(slot: int)
signal closed

## Т-110-проводка (раунд 11 §1.2): бэкенд — MvpSaveManager (кампанийные сейвы,
## 3 слота, MvpSaveSchema). Legacy SaveManager (SaveData, 5 слотов) — контракт
## замороженного world-слоя; меню пост-cutover ведёт кампанию, не мир.
const SLOT_COUNT := MvpSaveManager.SLOT_COUNT

var _mode: String = "load"
var _wired := false

@onready var _title: Label = $Panel/Box/Title
@onready var _slot_list: VBoxContainer = $Panel/Box/SlotList
@onready var _back_btn: Button = $Panel/Box/BottomRow/BackButton
@onready var _error_label: Label = $Panel/Box/ErrorLabel


func _ready() -> void:
	_wire()
	visible = false


func _wire() -> void:
	if _wired:
		return
	_wired = true
	_back_btn.pressed.connect(_on_back_pressed)
	for i in SLOT_COUNT:
		var load_btn: Button = _get_slot_node(i, "HBox/Buttons/LoadButton")
		var delete_btn: Button = _get_slot_node(i, "HBox/Buttons/DeleteButton")
		if load_btn != null:
			load_btn.pressed.connect(_on_load_pressed.bind(i))
		if delete_btn != null:
			delete_btn.pressed.connect(_on_delete_pressed.bind(i))
	# Сцена рисует 5 слотов (legacy); кампанийных — 3: лишние прячем (не правим сцену).
	for i in range(SLOT_COUNT, 5):
		var extra: Control = _slot_list.get_node_or_null("Slot%d" % i)
		if extra != null:
			extra.visible = false


func _get_slot_node(i: int, rel_path: String) -> Control:
	var slot_root: Control = _slot_list.get_node_or_null("Slot%d" % i)
	if slot_root == null:
		return null
	return slot_root.get_node_or_null(rel_path)


func open(mode: String = "load") -> void:
	_wire()
	_mode = mode
	_title.text = GameText.load_ok() if mode == "load" else GameText.save_ok()
	_error_label.text = ""
	_refresh_slots()
	visible = true
	if is_inside_tree():
		UIAnimator.animate_in(self)


func close() -> void:
	visible = false
	closed.emit()


func _refresh_slots() -> void:
	for i in SLOT_COUNT:
		var slot := i + 1
		var info_label: Label = _get_slot_node(i, "HBox/Info")
		var load_btn: Button = _get_slot_node(i, "HBox/Buttons/LoadButton")
		var delete_btn: Button = _get_slot_node(i, "HBox/Buttons/DeleteButton")
		var data: Dictionary = _read_slot(slot)
		if data.is_empty():
			if info_label != null:
				info_label.text = GameText.no_save_found()
			if load_btn != null:
				load_btn.disabled = true
			if delete_btn != null:
				delete_btn.disabled = true
		else:
			if info_label != null:
				info_label.text = _format_slot_info(data)
			if load_btn != null:
				load_btn.disabled = (_mode != "load")
			if delete_btn != null:
				delete_btn.disabled = false


func _read_slot(slot: int) -> Dictionary:
	var result: Dictionary = MvpSaveManager.load_slot(slot)
	if not bool(result.get("ok", false)):
		return {}
	return result.get("state", {}) as Dictionary


func _format_slot_info(state: Dictionary) -> String:
	var parts: Array[String] = []
	var party: Array = state.get("party", [])
	if party.size() > 0 and party[0] is Dictionary:
		var hero_name: String = str((party[0] as Dictionary).get("hero_name", ""))
		if not hero_name.is_empty():
			parts.append("🧙 %s" % hero_name)
	var turn: int = int((state.get("campaign", {}) as Dictionary).get("turn", 0))
	if turn > 0:
		parts.append("📅 ход %d" % turn)
	if parts.is_empty():
		return GameText.no_save_found()
	return "  ·  ".join(parts)


func _on_load_pressed(slot_index: int) -> void:
	var slot := slot_index + 1
	if not MvpSaveManager.has_save_in_slot(slot):
		_error_label.text = GameText.no_save_found()
		return
	load_requested.emit(slot)


func _on_delete_pressed(slot_index: int) -> void:
	var slot := slot_index + 1
	delete_requested.emit(slot)
	perform_delete(slot)


func _on_back_pressed() -> void:
	close()


func perform_load(slot: int) -> void:
	var result: Dictionary = MvpSaveManager.load_slot(slot)
	if not bool(result.get("ok", false)):
		_error_label.text = GameText.load_failed()
		GameLogger.warn("SaveLoadScreen: load error %s" % str(result.get("message", "")), "SaveLoad")
		return
	var state: Dictionary = result.get("state", {}) as Dictionary
	var persistence: WorldPersistence = Services.resolve(&"persistence")
	if persistence != null:
		# Т-110-проводка (раунд 11 §1.2): main.gd → load_save_state.
		persistence.pending_campaign_save = state
	# Cutover-акт (D-157, раунд 10 §1.1): Continue/Load → campaign-сцена.
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func perform_delete(slot: int) -> void:
	if MvpSaveManager.delete_slot(slot):
		GameLogger.info("SaveLoadScreen: deleted slot %d" % slot, "SaveLoad")
	_refresh_slots()

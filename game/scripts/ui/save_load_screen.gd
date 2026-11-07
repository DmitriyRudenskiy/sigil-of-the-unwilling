class_name SaveLoadScreen
extends Control

signal load_requested(slot: int)
signal delete_requested(slot: int)
signal closed

## Число слотов берётся у носителя сейва. Экран держал свои пять кнопок при
## трёх слотах системы (T-307, D-301): два ряда физически не могли заполниться,
## и игрок читал «нет сохранений» там, где слота не существует.
const SLOT_COUNT := MvpSaveManager.SLOT_COUNT

## Загрузка меняет сцену на кампанийный носитель — тот же путь, что у «Продолжить»
## (`main_menu.SCENE_CONTINUE`); константа своя, чтобы не зациклить preload
## (`MainMenu` → экран → `MainMenu`).
const SCENE_ADVENTURE := "res://scenes/ui/adventure_ui.tscn"

var _wired := false

@onready var _title: Label = $Panel/Box/Title
@onready var _slot_list: VBoxContainer = $Panel/Box/SlotList
@onready var _back_btn: Button = $Panel/Box/BottomRow/BackButton
@onready var _error_label: Label = $Panel/Box/ErrorLabel


func _ready() -> void:
	_wire()
	_explain_scene_defaults()
	visible = false


## Столп 1 (mvp-ui-flow 3.3): слоты выключены самим `.tscn` — до первого `open()`
## экран показывал ряды серых кнопок без объяснения. Причина ставится сразу при
## монтировании, а `_refresh_slots` дальше ведёт её по состоянию данных.
func _explain_scene_defaults() -> void:
	for i in SLOT_COUNT:
		for rel in ["HBox/Buttons/LoadButton", "HBox/Buttons/DeleteButton"]:
			var button: Button = _get_slot_node(i, rel)
			if button != null and button.disabled and button.tooltip_text == "":
				button.tooltip_text = GameText.save_slot_empty_unavailable()


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


func _get_slot_node(i: int, rel_path: String) -> Control:
	var slot_root: Control = _slot_list.get_node_or_null("Slot%d" % i)
	if slot_root == null:
		return null
	return slot_root.get_node_or_null(rel_path)


## Режим `save` снят (T-307, D-301): в сцене нет кнопки записи, и «режим
## сохранения» показывал список, в котором нельзя было сделать ничего — ни
## записать, ни загрузить. Запись кампанийного слота делает носитель кампания
## (`main.save_campaign_slot()`), а не этот список.
func open() -> void:
	_wire()
	_title.text = GameText.menu_load_game()
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
		var state := _read_state(slot)
		if state.is_empty():
			if info_label != null:
				info_label.text = GameText.no_save_found()
			# Столп 1 (mvp-ui-flow 3.3): в пустом слоте обе кнопки выключены — игрок
			# читает причину на месте, а не гадает, живой ли это экран.
			_set_unavailable(load_btn, GameText.save_slot_empty_unavailable())
			_set_unavailable(delete_btn, GameText.save_slot_empty_unavailable())
		else:
			if info_label != null:
				info_label.text = _format_slot_info(state)
			_set_available(load_btn)
			_set_available(delete_btn)


## Пара «состояние + причина» ставится одним вызовом: выключить контрол и не
## назвать причину теперь нельзя (столп 1, mvp-ui-flow 3.3).
static func _set_unavailable(button: Button, reason: String) -> void:
	if button == null:
		return
	button.disabled = true
	button.tooltip_text = reason


static func _set_available(button: Button) -> void:
	if button == null:
		return
	button.disabled = false
	button.tooltip_text = ""


## Только что записанный слот, не проходящий схему, — норма, а не авария: экран
## обязан показать «пусто», а не упасть. Отличие отсутствующего файла от битого
## сейва видно в журнале (`MvpSaveManager.load_slot` возвращает код ошибки).
func _read_state(slot: int) -> Dictionary:
	var result: Dictionary = MvpSaveManager.load_slot(slot)
	if not bool(result.get("ok", false)):
		return {}
	return result.get("state", {}) as Dictionary


## Мера строки — то, что лежит в сейве: ход кампании и имя героя. Дату, отряд и
## города показывала легаси-верстка (`SaveData.hero/.cities`) по сейвам, которые
## игра больше не пишет.
func _format_slot_info(state: Dictionary) -> String:
	var campaign := state.get("campaign", {}) as Dictionary
	var parts: Array[String] = [GameText.campaign_goal_day(int(campaign.get("turn", 1)))]
	var hero_name := str(campaign.get("hero_name", ""))
	if not hero_name.is_empty():
		parts.append(hero_name)
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
		GameLogger.warn(
			"SaveLoadScreen: slot %d не загружен: %s" % [slot, str(result.get("message", ""))],
			"SaveLoad")
		return
	var persistence: WorldPersistence = Services.resolve(&"persistence")
	if persistence != null:
		# Тот же вход, что у «Продолжить»: слот читает уже кампанийный носитель
		# (`main.gd` → `composition.load_save_state`).
		persistence.pending_campaign_slot = slot
	get_tree().change_scene_to_file(SCENE_ADVENTURE)


func perform_delete(slot: int) -> void:
	if MvpSaveManager.delete_slot(slot):
		GameLogger.info("SaveLoadScreen: deleted slot %d" % slot, "SaveLoad")
	_refresh_slots()

extends BaseTest

## D-281 (задачи 3.3–3.7) — блоки макета 10, заведённые этим срезом: медальон,
## каркас способностей, повозка, малые кнопки узла хода, миникарта, сброс выбора.
##
## Проверки идут от UI (emit `pressed`, чтение узлов кадра), а не от вызовов
## методов слоя: урок T-131 — тест, дергающий системный метод напрямую, зелёный
## и при отсутствующем проводе, а именно провода здесь и есть предмет.
##
## Плита Знака и панель целей проверяются своими файлами; здесь только то, что
## медальон с ними связан (бейдж и вход в журнал).

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const CalendarScript := preload("res://scripts/campaign/campaign_calendar.gd")
const HUD_PATH := "CampaignHUD/CampaignHud"
const MEDALLION_PATH := HUD_PATH + "/Medallion"
const GOALS_PANEL_PATH := HUD_PATH + "/GoalsPanel"
const ABILITY_FRAME_PATH := HUD_PATH + "/AbilityFrame"
const CITY_SCREEN_PATH := HUD_PATH + "/CityScreen"

var _main: Node = null
var _window_size := Vector2i.ZERO


func _root() -> Node:
	return Engine.get_main_loop().root


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame
	(_root() as Window).size = _window_size
	super.after_test()


## Кампейн поднимается игроковым путём (`main.tscn` → `_init_campaign`), окно —
## 1920×1080, как в съёмке: место элемента вне кадра мерится только в кадре.
func _boot_campaign() -> Node:
	var window := _root() as Window
	_window_size = window.size
	window.size = Vector2i(1920, 1080)
	_main = load(MAIN_SCENE_PATH).instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	var overlay := _main.get_node_or_null(
		NodePath(HUD_PATH + "/TutorialOverlay")) as TutorialOverlay
	if overlay != null and overlay.is_open():
		overlay.dismiss()
		await get_tree().process_frame
	return _main


func _hud() -> CampaignHud:
	return _main.get_node(HUD_PATH) as CampaignHud


## ── 3.3 медальон ────────────────────────────────────────────────────────────

## Кольцо = прожитая доля месяца, бейдж = цели с `done == false`. Число доли
## сверяется с календарём, а не с половиной кадра: длину месяца задаёт
## `CampaignCalendar`, и расхождение видно именно здесь.
func test_medallion_shows_month_fraction_and_pending_goals() -> void:
	var main := await _boot_campaign()
	var day := int(main.game_manager.get_current_day())
	var ring := main.get_node(MEDALLION_PATH + "/MedallionRing") as RingProgress
	assert_that(ring).is_not_null()
	var expected := float(CalendarScript.date_of(day).day) / float(CalendarScript.days_per_month())
	assert_float(ring.fraction).is_equal(expected)
	var badge := main.get_node(MEDALLION_PATH + "/MedallionBadge") as Label
	var pending: Array = (main.composition.goals as CampaignGoalTracker).pending()
	assert_that(badge).is_not_null()
	assert_bool(badge.visible).is_true()
	assert_str(badge.text).is_equal(str(pending.size()))
	# Закрытые цели снимаются с бейджа, а не складываются с ним.
	for goal in (main.composition.goals as CampaignGoalTracker).goals:
		goal["done"] = true
	_hud().refresh_campaign(day)
	await get_tree().process_frame
	assert_bool(badge.visible).is_false()


## Клик по медальону — вход в журнал целей (D-241) и выход из него. Панель
## скрывается, а не пересоздаётся: пересчёт целей у слоя один.
func test_medallion_click_toggles_goals_journal() -> void:
	var main := await _boot_campaign()
	var medallion := main.get_node(MEDALLION_PATH) as Button
	var panel := main.get_node(GOALS_PANEL_PATH) as PanelContainer
	assert_that(medallion).is_not_null()
	assert_bool(panel.visible).is_true()
	medallion.pressed.emit()
	await get_tree().process_frame
	assert_bool(panel.visible).is_false()
	medallion.pressed.emit()
	await get_tree().process_frame
	assert_bool(panel.visible).is_true()


## ── 3.4 каркас способностей и повозка ───────────────────────────────────────

## Восемь пустых ячеек и метка задачи. Ячейки — не кнопки: нажатие без действия
## (T-244) было бы обещанием, а метка «задача» отличает незакрытый блок от
## пустого по носителя.
func test_ability_frame_has_eight_inert_cells_and_todo_note() -> void:
	var main := await _boot_campaign()
	var frame := main.get_node(ABILITY_FRAME_PATH) as Control
	assert_that(frame).is_not_null()
	assert_bool(frame.visible).is_true()
	var cells := frame.find_child("AbilityCells", true, false)
	assert_that(cells).is_not_null()
	assert_int(cells.get_child_count()).is_equal(8)
	assert_int(frame.find_child("AbilityCell_7", true, false).get_child_count()).is_equal(0)
	for cell in cells.get_children():
		assert_bool(cell is Button).is_false()
	var note := frame.find_child("AbilityTodoNote", true, false) as Label
	assert_that(note).is_not_null()
	assert_str(note.text).is_equal(GameText.campaign_todo_abilities())


## Повозка ведёт в городской экран существующим путём — второго носителя города
## слой не заводит: после нажатия открыт тот же `CityScreen`.
func test_cart_button_opens_the_same_city_screen() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	var cart := main.get_node_or_null(HUD_PATH + "/CartButton") as Button
	assert_that(cart).is_not_null()
	# Доступность = доступность городского экрана: `bind_city` поднят хостом.
	assert_bool(cart.disabled).is_false()
	assert_bool(hud.is_city_screen_open()).is_false()
	cart.pressed.emit()
	await get_tree().process_frame
	assert_bool(hud.is_city_screen_open()).is_true()
	assert_bool(main.get_node(CITY_SCREEN_PATH).visible).is_true()


## ── 3.5 малые кнопки узла хода ──────────────────────────────────────────────

## Мечи и глобус нарисованы и выключены (T-245): экрана-носителя у них нет.
func test_turn_side_buttons_are_drawn_and_inert() -> void:
	var main := await _boot_campaign()
	for entry in [["TurnSwordsButton", &"turn_swords"], ["TurnGlobeButton", &"turn_globe"]]:
		var button := main.get_node_or_null(NodePath("%s/%s" % [HUD_PATH, entry[0]])) as Button
		assert_that(button).is_not_null()
		assert_bool(button.disabled).is_true()
		var rect := button.get_global_rect()
		assert_float(rect.size.x).is_greater(0.0)
		assert_float(rect.size.y).is_greater(0.0)
		# Подсказка обязана называть, чего не хватает: метка задачи видна только
		# в ней, а выключенная кнопка без объяснения = «сломано».
		assert_str(button.tooltip_text).is_equal(GameText.campaign_todo_hint())


## ── 3.7 миникарта и сброс выбора ────────────────────────────────────────────

## Миникарта читает тот же носитель, что и поле: состав точек сверяется с полем,
## а не с `RegionMap` напрямую — иначе тест не заметил бы второго раскладчика.
func test_minimap_shows_the_same_regions_as_the_field() -> void:
	var main := await _boot_campaign()
	var minimap := main.get_node_or_null(HUD_PATH + "/CampaignMinimap") as CampaignMinimap
	var field := main.campaign_map_field as CampaignMapField
	assert_that(minimap).is_not_null()
	assert_that(field).is_not_null()
	assert_bool(minimap.visible).is_true()
	# Сравнение по содержимому: у миникарты свой массив, и сверяется он с тем,
	# что рисует поле, а не с `RegionMap` напрямую.
	assert_array(minimap.shown_regions()).is_equal(field.visible_regions()) \
		.override_failure_message("миникарта и поле разошлись в составе регионов")
	assert_float(minimap.get_global_rect().size.x).is_greater(0.0)


## Четвёртый тайл: неактивен без выбора, снимает выбор и гаснет снова. Выбор
## читается у поля — второго носителя выбора в слое нет.
func test_reset_tile_needs_a_selection_and_clears_it() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	var field := main.campaign_map_field as CampaignMapField
	var tile := main.get_node_or_null(HUD_PATH + "/ResetTile") as Button
	assert_that(tile).is_not_null()
	assert_bool(tile.disabled).is_true()
	var regions: Array = field.visible_regions()
	assert_int(regions.size()).is_greater(0)
	field.select_region(String(regions[0]))
	await get_tree().process_frame
	assert_bool(tile.disabled).is_false()
	tile.pressed.emit()
	await get_tree().process_frame
	assert_str(field.selected_region()).is_equal("")
	assert_bool(tile.disabled).is_true()
	# Сброс не уронил выбор в «несуществующий регион»: поле по-прежнему рисует граф.
	assert_int(field.visible_regions().size()).is_equal(regions.size())
	assert_that(hud).is_not_null()

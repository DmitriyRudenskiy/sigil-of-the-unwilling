extends BaseTest

## mvp-ui-flow 2.3 (T-182, M3): панель целей первых трёх дней в живом кампейне.
##
## Носитель — полоса `CampaignHud` на `scenes/main/main.tscn`: панель поднимается
## вместе с кампанией и привязывается к трекеру композиции (`main.gd`). До T-182
## панели не было вовсе: `CampaignGoalTracker` жила с 5.2, но её никто не
## instantiate-ил в игровом пути, поэтому игрок три первых дня проходил без
## подсказки «что от него хотят» (канон M3, 07-ui-ux).
##
## Что гейтится:
## 1. панель есть и видна на старте, заголовок переведён;
## 2. список = закрытый набор целей M3, и каждая строка переведена (цель без
##    перевода показала бы игроку сырой ключ — тот же класс брака, что немой
##    ключ эффекта в каталоге событий, Q-M79);
## 3. закрытая цель уходит из списка по сигналу трекера, а не по следующему ходу;
## 4. выполненные все цели прячут панель целиком («всё сделано» — это отсутствие
##    панели, а не пустой список под заголовком);
## 5. перепривязка трекера (загрузка сейва приносит другой объект) переключает
##    панель на новый и обрывает связь со старым;
## 6. панель остаётся в кадре — она заякорена в левом верхнем углу и растёт вниз;
## 7. заголовки дней не дублируются, если трекер пришёл из сейва вразноброс (группировка по дню, а не по порядку списка).


const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const HUD_PATH := "CampaignHUD/CampaignHud"
const PANEL_PATH := HUD_PATH + "/GoalsPanel"
const LIST_PATH := PANEL_PATH + "/GoalsColumn/GoalsList"

const GOAL_IDS := ["farm", "barracks", "train_warrior", "ruins"]

var _main: Node = null
var _window_size := Vector2i.ZERO
var _window_saved := false


func _root() -> Node:
	return Engine.get_main_loop().root


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame
	if _window_saved:
		(_root() as Window).size = _window_size
		_window_saved = false


## Кампания поднимается так же, как её поднимает игра (`_ready` → `_init_campaign`
## → привязка слоя), окно — явным размером 1920×1080 (headless-окно 64×64 ловило
## бы компактную форму шапки; приём снят с `test_campaign_city_carrier.gd`).
func _boot_campaign() -> Node:
	var window := _root() as Window
	_window_size = window.size
	_window_saved = true
	window.size = Vector2i(1920, 1080)
	_main = load(MAIN_SCENE_PATH).instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	return _main


func _hud() -> CampaignHud:
	return _main.get_node(HUD_PATH) as CampaignHud


func _panel() -> Control:
	return _main.get_node_or_null(PANEL_PATH) as Control


## Панель видна по-настоящему: с учётом видимости предков (скрытый предок дал бы
## зелёный тест при пустом кадре).
func _panel_shown() -> bool:
	var panel := _panel()
	return panel != null and panel.visible and panel.is_visible_in_tree()


func test_panel_is_visible_on_campaign_start() -> void:
	var main := await _boot_campaign()
	var panel := _panel()
	assert_that(panel).is_not_null()
	assert_bool(_panel_shown()).is_true()
	var title := panel.get_node("GoalsColumn/GoalsTitle") as Label
	assert_str(title.text).is_equal(GameText.campaign_goals_title())
	assert_str(title.text).is_not_equal("campaign.goals_title")


## Список показывает все четыре цели M3, и каждая — переведённой. Проверка
## «не совпадает с ключом» — сторож закрытого набора: `GameText.campaign_goal()`
## строит ключ из id цели, а TranslationServer на неизвестный ключ возвращает сам
## ключ, так что опечатка в id ушла бы в кадр текстом «campaign.goal.barracks».
func test_panel_lists_every_goal_of_the_m3_set() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	for goal_id in GOAL_IDS:
		var text := hud.get_goal_text(goal_id)
		# id цели дописан к значению: у assert_str в этом GdUnit нет параметра
		# сообщения, а по одному только тексту непонятно, какая из четырёх целей
		# не переведена.
		assert_str(text + "|" + goal_id).is_not_equal("|" + goal_id)
		assert_str(text + "|" + goal_id).is_not_equal("campaign.goal.%s|%s" % [goal_id, goal_id])
	for day in [1, 2, 3]:
		var head := _main.get_node_or_null("%s/GoalDay%d" % [LIST_PATH, day]) as Label
		assert_that(head).is_not_null()
		assert_str(head.text).is_equal(GameText.campaign_goal_day(day))


## Закрытая цель исчезает в тот же момент, а не на следующем ходе: панель
## подключена к `goal_completed`, и тест это и проверяет — хода между вызовом и
## проверкой нет.
func test_closed_goal_leaves_the_list() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	main.composition.goals.note_building_built("campaign_farm")
	assert_str(hud.get_goal_text("farm")).is_equal("")
	assert_str(hud.get_goal_text("barracks")).is_not_equal("")
	assert_bool(_panel_shown()).is_true()


## Все цели закрыты — панели нет целиком (не «пустая карточка с заголовком»).
func test_panel_hides_when_all_goals_are_done() -> void:
	var main := await _boot_campaign()
	var goals: CampaignGoalTracker = main.composition.goals
	for building_id in ["campaign_farm", "campaign_barracks"]:
		goals.note_building_built(building_id)
	goals.note_training_completed("fighter")
	goals.note_region_visited("R03")
	assert_bool(goals.all_complete()).is_true()
	assert_bool(_panel_shown()).is_false()


## Загрузка сейва приносит другой трекер (`CampaignGoalTracker.from_dict`), и
## панель обязана переключиться на него: связь со старым объектом оставила бы на
## экране цели вчерашней кампании.
func test_rebinding_switches_to_the_new_tracker() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	var loaded := CampaignGoalTracker.new()
	for building_id in ["campaign_farm", "campaign_barracks"]:
		loaded.note_building_built(building_id)
	loaded.note_training_completed("fighter")
	loaded.note_region_visited("R03")
	hud.bind_goals(loaded)
	assert_bool(_panel_shown()).is_false()
	# Старый трекер больше не слушается: его сигнал не должен ничего менять.
	main.composition.goals.goal_completed.emit("farm")
	assert_bool(_panel_shown()).is_false()
	hud.bind_goals(main.composition.goals)
	assert_bool(_panel_shown()).is_true()
	assert_str(hud.get_goal_text("farm")).is_not_equal("")


## Панель заякорена в левом верхнем углу и растёт вниз по числу целей; в кадре
## она обязана оставаться и на одном дне, и на всех трёх (иначе `PanelCard`
## уехал бы за границу, а адаптивный гейт ловит только переполнение скролла).
## Заголовки дней не дублируются, даже если трекер пришёл из сейва вразноброс:
## панель группирует по дню, а не по порядку списка (`pending()` сохраняет
## порядок трекера, а `from_dict` приносит его любым).
func test_day_headers_do_not_duplicate_on_scrambled_tracker() -> void:
	var main := await _boot_campaign()
	var hud := _hud()
	var loaded := CampaignGoalTracker.new([
		{"id": "train_warrior", "day": 2, "type": "train", "target": "fighter", "done": false},
		{"id": "farm", "day": 1, "type": "building", "target": "campaign_farm", "done": false},
		{"id": "barracks", "day": 1, "type": "building", "target": "campaign_barracks", "done": false},
	])
	hud.bind_goals(loaded)
	await get_tree().process_frame
	assert_int(_header_count(1)).is_equal(1)
	assert_int(_header_count(2)).is_equal(1)
	assert_str(hud.get_goal_text("barracks")).is_not_equal("")


## Сколько заголовков данного дня в списке целей.
func _header_count(day: int) -> int:
	var list := _main.get_node_or_null(LIST_PATH) as Container
	if list == null:
		return -1
	var n := 0
	for child in list.get_children():
		if child.name == "GoalDay%d" % day:
			n += 1
	return n


func test_panel_stays_inside_the_frame() -> void:
	var main := await _boot_campaign()
	var panel := _panel()
	var rect := panel.get_global_rect()
	assert_bool(rect.position.x >= 0.0).is_true()
	assert_bool(rect.position.y >= 0.0).is_true()
	assert_bool(rect.end.x <= 1920.0).is_true()
	assert_bool(rect.end.y <= 1080.0).is_true()
	assert_bool(rect.size.y > 0.0).is_true()
	main.composition.goals.note_building_built("campaign_farm")
	assert_bool(panel.get_global_rect().end.y <= 1080.0).is_true()

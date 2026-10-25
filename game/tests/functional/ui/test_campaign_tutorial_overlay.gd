extends BaseTest

## mvp-ui-flow 2.2 (T-186): туториал-оверлей первых ходов в живом кампейне.
##
## Носитель — `TutorialOverlay` (CanvasLayer, слой выше хроники), поднимаемый
## вместе с `CampaignHud` на `scenes/main/main.tscn`. Проводка:
## `CampaignNavigation.show_screen` → `tutorial_requested` (первый вход в экран,
## один раз, `CampaignNavigation._tutorial_shown`) → `CampaignUIManager` ретранслирует
## → `CampaignHud._on_tutorial_requested` → оверлей показывает директиву текущего
## дня из `campaign.json → tutorial`.
##
## До T-186 существовала только первая половина: сигнал генерировался и умирал —
## «потребителя `tutorial_requested` у носителя ещё нет» было записано прямо в
## комментарии `begin_campaign()`. Игровой путь «первый вход в экран → подсказка»
## был написан в спеке и отсутствовал в игре.
##
## Что гейтится:
## 1. оверлей поднят вместе с кампанией и скрыт на старте (`begin_campaign`
##    намеренно не запрашивает туториал карты — HUD монтируется после него);
## 2. первый вход в экран показывает директиву **текущего дня**, текстом из
##    конфига (тест сверяется с `composition.tutorial_directives()`, а не с
##    копией строки: проверяется проводка, а не редактура);
## 3. кнопка закрывает оверлей, экран под ним остаётся открытым;
## 4. второй экран (и возврат на карту при закрытии экрана) в тот же день ту же
##    директиву не повторяет (дедупликация потребителя; пер-экранную «один раз»
##    держит навигация);
## 5. следующий день приносит свою директиву;
## 6. после третьего дня директив нет → оверлей молчит;
## 7. канон: директива дня 2 — тренировка, не наём (Q18/K-M15; поправка T-101
##    зафиксирована в GAP-LIST, а в append-only TICKETS старой строки не
##    правится). Конфиг до T-186 говорил «найми ополченца» — писатель без
##    читателя не умирал, потому что его читал только инвариант по подстроке.

const MAIN_SCENE_PATH := "res://scenes/main/main.tscn"
const HUD_PATH := "CampaignHUD/CampaignHud"
const OVERLAY_PATH := HUD_PATH + "/TutorialOverlay"
const DISMISS_BUTTON_PATH := OVERLAY_PATH + "/Root/Card/DirectiveColumn/DismissButton"
const TURN_BUTTON_PATH := HUD_PATH + "/TopButtons/TurnButton"

var _main: Node = null


func _root() -> Node:
	return Engine.get_main_loop().root


func after_test() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	await get_tree().process_frame
	await get_tree().process_frame


## Кампания поднимается так же, как её поднимает игра (`_ready` → `_init_campaign`
## → `_mount_campaign_hud` → привязка директив), окно — явным 1920×1080 (приём
## снят с `test_campaign_goals_panel.gd`).
func _boot_campaign() -> void:
	(_root() as Window).size = Vector2i(1920, 1080)
	_main = load(MAIN_SCENE_PATH).instantiate()
	_root().add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame


func _hud() -> CampaignHud:
	return _main.get_node(HUD_PATH) as CampaignHud


func _composition() -> CampaignComposition:
	return _main.composition as CampaignComposition


func _directive(day: int) -> String:
	return String(_composition().tutorial_directives().get("day_%d" % day, ""))


func _overlay() -> TutorialOverlay:
	return _main.get_node_or_null(OVERLAY_PATH) as TutorialOverlay


func _press(node_path: String) -> void:
	var button := _main.get_node_or_null(node_path) as Button
	assert_that(button).is_not_null()
	# Головный ввод до обработчиков не доходит (проверено на этом носителе),
	# поэтому нажатие — прямой сигнал кнопки.
	button.pressed.emit()


## 1. Оверлей поднят и скрыт: на старте кампании никто никуда не входил. И он
# именно **оверлей, а не экран** (K-M8): в машине навигации его нет, поэтому он
# не участвует в переходе экранов и не может остаться «висящим открытым».
func test_overlay_is_mounted_and_hidden_on_start() -> void:
	await _boot_campaign()
	assert_that(_overlay()).is_not_null()
	assert_bool(_hud().is_tutorial_open()).is_false()
	assert_bool(_overlay().visible).is_false()
	assert_str(_hud().get_tutorial_text()).is_empty()
	var mgr: Object = _main.get("campaign_ui_manager")
	assert_bool(bool(mgr.call("has_screen", &"tutorial"))).is_false()


## 2. Первый вход в экран = директива текущего дня, текстом конфига (не копией
# строки в тесте: иначе тест проверял бы свою же константу).
func test_first_screen_entry_shows_days_directive() -> void:
	await _boot_campaign()
	var hud := _hud()
	assert_str(_directive(1)).is_not_empty()
	hud.open_city_screen()
	await get_tree().process_frame
	assert_bool(hud.is_tutorial_open()).is_true()
	assert_str(hud.get_tutorial_text()).is_equal(_directive(1))
	var title := _overlay().directive_title()
	assert_str(title).is_equal(GameText.campaign_goal_day(1))


## 3. Кнопка «Закрыть» (существующая строка `ui.close`) гасит оверлей, экран под
# ним остаётся: оверлей — намёк, а не уход из экрана.
func test_dismiss_button_closes_overlay_and_keeps_screen() -> void:
	await _boot_campaign()
	var hud := _hud()
	hud.open_city_screen()
	await get_tree().process_frame
	assert_bool(hud.is_tutorial_open()).is_true()
	_press(DISMISS_BUTTON_PATH)
	await get_tree().process_frame
	assert_bool(hud.is_tutorial_open()).is_false()
	assert_str(hud.get_tutorial_text()).is_empty()
	assert_bool(
		(_main.get_node(HUD_PATH + "/CityScreen") as Control).is_visible_in_tree()
	).is_true()


## 4. Дедупликация потребителя: закрыл директиву, вернулся на карту (это тоже
# «первый вход» — CITY → MAP при закрытии экрана) и зашёл в другой экран в тот
# же день — второй модалки с той же строкой нет. Пер-экранную «один раз» держит
# навигация, здесь — «одна директива за день».
func test_same_day_does_not_repeat_the_directive() -> void:
	await _boot_campaign()
	var hud := _hud()
	hud.open_city_screen()
	await get_tree().process_frame
	_press(DISMISS_BUTTON_PATH)
	hud.close_city_screen()
	await get_tree().process_frame
	assert_bool(hud.is_tutorial_open()).is_false()
	hud.open_party_screen()
	await get_tree().process_frame
	assert_bool(hud.is_tutorial_open()).is_false()
	assert_str(str(_overlay().shown_days())).is_equal("[1]")


## 5. Новый день — новая директива (игрок закрыл день 1, сходил ходом дальше,
# зашёл в хронику: получает день 2). Ход недоступен, пока кампейн-экран открыт
# (время стоит, 7.13), поэтому перед кнопкой хода экран закрывается.
func test_next_day_gets_its_own_directive() -> void:
	await _boot_campaign()
	var hud := _hud()
	hud.open_city_screen()
	await get_tree().process_frame
	_press(DISMISS_BUTTON_PATH)
	hud.close_city_screen()
	await get_tree().process_frame
	_press(TURN_BUTTON_PATH)
	await get_tree().process_frame
	assert_int(_composition().campaign.current_turn).is_equal(2)
	assert_str(_directive(2)).is_not_empty()
	hud.open_chronicle_screen()
	await get_tree().process_frame
	assert_bool(hud.is_tutorial_open()).is_true()
	assert_str(hud.get_tutorial_text()).is_equal(_directive(2))
	assert_str(_overlay().directive_title()).is_equal(GameText.campaign_goal_day(2))


## 6. Директив больше нет (после третьего дня) — оверлей молчит, а не показывает
# пустую карточку и не изобретает текст.
func test_no_directive_after_the_third_day() -> void:
	await _boot_campaign()
	var hud := _hud()
	for _turn in range(3):
		_press(TURN_BUTTON_PATH)
		await get_tree().process_frame
	assert_int(_composition().campaign.current_turn).is_equal(4)
	assert_str(_directive(4)).is_empty()
	hud.open_settings_screen()
	await get_tree().process_frame
	assert_bool(hud.is_tutorial_open()).is_false()


## 7. Канон директивы дня 2: тренировка воина, не наём (Q18/K-M15; поправка
# T-101 — GAP-LIST). Строка в конфиге до этого среза противоречила канону, и
# это было незаметно: читал её только инвариант reachability, по подстроке «руин».
func test_day_two_directive_is_training_not_hiring() -> void:
	await _boot_campaign()
	var text := _directive(2)
	assert_bool(
		not text.contains("найм") and not text.contains("ополчен")
	).override_failure_message("директива дня 2 про наём: «%s» (канон: тренировка, Q18)" % text) \
		.is_true()
	assert_bool(text.contains("тренируй")) \
		.override_failure_message("директива дня 2 не про тренировку: «%s»" % text) \
		.is_true()

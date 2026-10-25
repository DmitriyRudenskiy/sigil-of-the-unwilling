extends BaseTest

## mvp-ui-flow 2.2 (T-186): туториал-оверлей первых ходов — юнит-уровень самого
## оверлея (проводку слоя и живой путь проверяет
## `tests/functional/ui/test_campaign_tutorial_overlay.gd`).
##
## Что здесь закреплено и почему именно так:
##
## 1. Оверлей — **оверлей, а не экран** (K-M8): у него нет своего состояния,
##    он только показывает директиву дня и закрывается.
## 2. Содержимое — `campaign.json → tutorial.day_N` («строка-директива»);
##    пустой строке неоткуда взяться из изобретённого текста: дней после третьего
##    директивы нет → оверлей молчит (кейс 2). Это же снимает соблазн «показать
##    хоть что-нибудь» при пустом конфиге.
## 3. «Один раз» живёт на двух уровнях: `CampaignNavigation` не показывает
##    туториал **экрана** дважды (спека, персистится в сейве), а оверлей не
##    показывает **ту же директиву** дважды за день (кейс 3). Без второго уровня
##    первое же возвращение на карту (CITY → MAP — тоже «первый вход») второй раз
##    выкинуло бы модалку с той же строкой.
## 4. Кегль и цвета — носителями темы, не оверрайдами (theme-type-hygiene,
##    UI-AC7): кейс 5 сторожит это по собранному дереву. `separation` у колонки —
##    сознательное исключение: оверрайды констант — отдельная корзина 6.5 того же
##    цикла, и кодостроенные слои (панель целей T-182) делают так же.
## 5. Минимальное разрешение (mvp-ui-flow 4.1: 1280×720) — карточка целиком в
##    кадре (кейс 6).

const _OVERLAY_SCRIPT := "res://scripts/ui/tutorial_overlay.gd"

## Директивы как в campaign.json → tutorial (значения здесь — фикстура, а не
## копия конфига: живой конфиг проверяет функциональный тест).
const _DAY_ONE := "построй ферму и барраки"
const _DAY_TWO := "потренируй воина"


func _overlay() -> TutorialOverlay:
	return make_node(load(_OVERLAY_SCRIPT) as GDScript) as TutorialOverlay


func _label(overlay: TutorialOverlay, child_name: String) -> Label:
	var label := overlay.find_child(child_name, true, false) as Label
	assert_that(label).is_not_null()
	return label


## 1. Показ: заголовок — день, тело — директива, кнопка — существующая строка
# `ui.close` (новых строк срез не вводит, поэтому `.po` не тронуты).
func test_try_show_renders_day_and_directive() -> void:
	var overlay := _overlay()
	await get_tree().process_frame
	assert_bool(overlay.is_open()).is_false()
	assert_bool(overlay.try_show(1, _DAY_ONE)).is_true()
	assert_bool(overlay.is_open()).is_true()
	assert_int(overlay.directive_day()).is_equal(1)
	assert_str(_label(overlay, "DirectiveDay").text).is_equal(GameText.campaign_goal_day(1))
	assert_str(_label(overlay, "DirectiveText").text).is_equal(_DAY_ONE)
	var button := overlay.find_child("DismissButton", true, false) as Button
	assert_that(button).is_not_null()
	assert_str(button.text).is_equal(GameText.ui_close())


## 2. Показывать нечего — оверлей не открывается: пустая директива (после третьего
# дня) и несуществующий день. Молчание вместо «покажем хоть что-нибудь» —
# тот же принцип, что немой ключ эффекта в каталоге событий (Q-M79).
func test_nothing_to_show_when_directive_is_missing() -> void:
	var overlay := _overlay()
	await get_tree().process_frame
	assert_bool(overlay.try_show(4, "")).is_false()
	assert_bool(overlay.try_show(0, _DAY_ONE)).is_false()
	assert_bool(overlay.try_show(-1, _DAY_ONE)).is_false()
	assert_bool(overlay.is_open()).is_false()
	assert_str(overlay.directive_text()).is_empty()
	assert_str(overlay.directive_title()).is_empty()


## 3. Одна директива — один показ. Закрыл, вернулся на другой экран в тот же
# день — модалки с той же строкой больше нет; на следующий день — новая.
func test_directive_is_not_shown_twice_for_one_day() -> void:
	var overlay := _overlay()
	await get_tree().process_frame
	assert_bool(overlay.try_show(1, _DAY_ONE)).is_true()
	overlay.dismiss()
	assert_bool(overlay.try_show(1, _DAY_ONE)).is_false()
	assert_bool(overlay.is_open()).is_false()
	assert_bool(overlay.try_show(2, _DAY_TWO)).is_true()
	assert_str(overlay.directive_text()).is_equal(_DAY_TWO)
	assert_int(overlay.shown_days().size()).is_equal(2)


## 4. Закрытие: оверлей гаснет, сигнал уходит один раз с дном директивы.
# Второй dismiss (уже закрытого) сигнала не даёт — хост не должен ловить
# фантомные закрытия.
func test_dismiss_hides_and_emits_once() -> void:
	var overlay := _overlay()
	await get_tree().process_frame
	var seen: Array = []
	overlay.dismissed.connect(func(day: int) -> void: seen.append(day))
	assert_bool(overlay.try_show(3, "сходи в руины")).is_true()
	overlay.dismiss()
	assert_bool(overlay.is_open()).is_false()
	assert_int(overlay.directive_day()).is_equal(-1)
	overlay.dismiss()
	assert_str(str(seen)).is_equal("[3]")


## 5. Гигиена темы (theme-type-hygiene, UI-AC7): кегль и цвет — ролями, не
# оверрайдами. Обход собранного дерева, а не текста файла: оверлей строится
# кодом, и «оверрайда нет в сцене» тут ничего не значило бы.
func test_theme_comes_from_carriers_not_overrides() -> void:
	var overlay := _overlay()
	await get_tree().process_frame
	assert_bool(overlay.try_show(1, _DAY_ONE)).is_true()
	var offenders: Array[String] = []
	_walk(overlay, offenders)
	assert_str(", ".join(offenders)).is_empty()
	assert_str(str(_label(overlay, "DirectiveDay").theme_type_variation)).is_equal("LabelStrong")
	assert_str(str(_label(overlay, "DirectiveText").theme_type_variation)).is_equal("LabelBody")


## 6. Минимальное разрешение (mvp-ui-flow 4.1): карточка целиком в кадре и на
# 1280×720, и на 1920×1080, и лежит по центру кадра. Stretch-mode canvas_items
# держит layout 16:9, но модалка обязана влезать и в кадр покороче.
#
# Центрация проверяется числом, а не только кадром: первый вариант карточки
# был центрирован `size_flags_*` без контейнера-родителя — ux-review показал её
# в левом верхнем углу, а проверки «влезает в кадр» оставались зелёными.
func test_card_is_centered_and_fits_the_frame() -> void:
	var original := get_tree().root.size
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_tree().root.size = size
		var overlay := _overlay()
		await get_tree().process_frame
		assert_bool(overlay.try_show(1, _DAY_ONE)).is_true()
		await get_tree().process_frame
		var card := overlay.find_child("Card", true, false) as Control
		assert_that(card).is_not_null()
		var rect: Rect2 = card.get_global_rect()
		var frame: Rect2 = get_tree().root.get_visible_rect()
		assert_bool(frame.encloses(rect)) \
			.override_failure_message("карточка директивы не влезла в %s: %s в %s" % [size, rect, frame]) \
			.is_true()
		var off := rect.get_center() - frame.get_center()
		assert_bool(absf(off.x) < 2.0 and absf(off.y) < 2.0) \
			.override_failure_message("карточка не по центру %s: смещение %s" % [size, off]) \
			.is_true()
	get_tree().root.size = original


func _walk(node: Node, offenders: Array[String]) -> void:
	if node is Control:
		var control := node as Control
		if control.has_theme_font_size_override("font_size"):
			offenders.append("%s:kegl" % control.name)
		if control.has_theme_color_override("font_color"):
			offenders.append("%s:color" % control.name)
	for child in node.get_children():
		_walk(child, offenders)

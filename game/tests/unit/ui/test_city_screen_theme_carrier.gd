extends BaseTest

# T-147, подсрез 1 города: чипы ресурсов `city_screen` (Еда / Дерево / Железо).
#
# Четыре состояния каждого чипа рисовались стилем, который код собирал на ходу
# (_resource_metric_style → _panel_style + поля 8/5). Перенесены в тему носителем
# CityResourceMetric (base_type = "Button"), значения — float-в-float.
#
# Почему резолв проверяется на живом экране, а не на теме: тема может хранить вариант,
# который узел не использует (не тот base_type для типа узла), и проверка уровня темы
# это промолчит — замер test_battle_theme_carrier.gd. Экран при этом обязан быть живым:
# у него нет сценевой половины (city_screen.tscn — оболочка из 11 строк, всё дерево
# строит _build_shell), поэтому гард строит дерево из настоящего экземпляра экрана.
#
# Нулевая дельта кадра доказывает только отсутствие визуального сдвига; власть темы
# доказывает смена носителя (замер съёмки 2026-10-20: «до» смена носителя кадр НЕ
# меняла, «после» меняет). Тесты ниже — про значения и про то, что вариант не
# перекрыл лишнего.
const _THEME := preload("res://assets/theme/game_theme.tres")
const _SCREEN := preload("res://scenes/ui/city_screen.tscn")
const _CHIP_PATH := "ScreenMargin/ScreenLayout/ScreenHeader/HeaderRow/ResourceHud/%sMetric"

## Снятые переопределения: ровно те значения, что возвращал _resource_metric_style.
# Рамка hover/pressed бралась из локального словаря экрана; с подсреза 3 (T-300) он живёт
# в модуле стиля — сравниваем с тем же источником, что и код, а не с продублированной
# шестнадцатеричной строкой.
const _STATES := {
	"normal": [Color("#30291d"), Color("#9a804d")],
	"hover": [Color("#3b3120"), null],
	"pressed": [Color("#45391f"), null],
	"disabled": [Color("#211e18"), Color("#665638")],
}

## Сколько add_theme_stylebox_override обязано остаться в city_screen.gd после
# подсреза 3: 16 было, 4 снято подсрезом 1 (чипы), 6 — подсрезом 2 (панели
# оболочки), 5 — подсрезом 3 (каталог зданий). Один оставшийся — фокус клавиатуры
# (подсрез 4), он ждёт решения владельца про Button/focus.
const _REMAINING_OVERRIDES := 1

## Документированный остаток: override клавиатурного фокуса на Button-узлах города
# (подсрез 4.8, ждёт Q-M95). Предикат считает обходом любой stylebox-override, кроме
# имён из этого списка — иначе гард падал бы на легитимном остатке.
const _FOCUS_ALLOWED := ["focus"]

## Снятые подсрезом 2 панели оболочки: имя узла → [носитель, фон, рамка]. Значения
# — те же выражения, что стояли в снятом коде (_panel_style(Color("#211e18"), …)),
# поэтому перенос «на глаз» падает. Фон доски — Color("#171915", 0.45): альфа
# перенесена как есть, и проверка сравнивает с тем же выражением.
const _SHELL := {
	"ScreenHeader": ["CityPanelGold", Color("#211e18"), Color("#92743b")],
	"CityInspector": ["CityPanelGold", Color("#211e18"), Color("#92743b")],
	"TerrainLegend": ["CityPanelGold", Color("#211e18"), Color("#92743b")],
	"BuildSidebar": ["CityPanelDark", Color("#1b1915"), Color("#665638")],
	"LegacyActionsPanel": ["CityPanelDark", Color("#1b1915"), Color("#665638")],
	"CityBoardPanel": ["CityBoardPanel", Color("#171915", 0.45), Color("#665638")],
}

const _CARD_IDLE := ["CityCard", Color("#211e18"), Color("#665638")]
const _CARD_SELECTED := ["CityCardSelected", Color("#29241b"), Color("#d3ae5d")]
const _TAB_IDLE_BG := Color("#211e18", 0.45)
const _TAB_IDLE_BORDER := Color("#665638")
const _TAB_ACTIVE_BG := Color("#392f1d")
const _COST_BG := Color("#392f1d")
const _COST_BORDER := Color("#b28b42")

var _hero: Node = null


var _screen: Node = null


func after_test() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.free()
	_screen = null


func _mk_screen() -> Node:
	_screen = _SCREEN.instantiate()
	get_tree().root.add_child(_screen)
	return _screen


func _chip(screen: Node, id: String) -> Button:
	var chip := screen.get_node_or_null(_CHIP_PATH % id) as Button
	assert_that(chip).is_not_null()
	return chip


## AC3 (а): все три чипа переведены на носитель темы, а не остались с override'ом.
func test_chips_carry_theme_variation() -> void:
	var screen := _mk_screen()
	await get_tree().process_frame
	for id in ["Food", "Wood", "Iron"]:
		var chip := _chip(screen, id)
		assert_str(chip.get_class()).is_equal("Button") \
			.override_failure_message(
				"чип %s сменил тип: носитель заявлен с base_type = \"Button\", " % id
				+ "для другого типа резолв уйдёт на стили его типа"
			)
		assert_str(str(chip.theme_type_variation)).is_equal("CityResourceMetric") \
			.override_failure_message("чип %s не переведён на носитель темы" % id)
		var ov := ThemeCarrierGuard.stylebox_overrides(chip, _FOCUS_ALLOWED)
		assert_int(ov.size()).is_equal(0) \
			.override_failure_message(
				"чип %s всё ещё несёт override — он сильнее темы: %s" % [id, ", ".join(ov.keys())]
			)


## AC3 (б): резолв из темы даёт ровно снятые значения, а не «что-то похожее».
# Сверка точная: цвет сравнивается с тем же Color(...), что стоял в коде, поэтому
# перенос с округлением до 4 знаков (0.1882 вместо 0.1882352977991104) падает.
func test_chips_resolve_transcribed_values() -> void:
	var screen := _mk_screen()
	await get_tree().process_frame
	for id in ["Food", "Wood", "Iron"]:
		var chip := _chip(screen, id)
		for state in _STATES:
			var want: Array = _STATES[state]
			var want_border: Color = want[1] if want[1] != null else ThemeConfig.C_CITY_GOLD
			var got: StyleBoxFlat = chip.get_theme_stylebox(state) as StyleBoxFlat
			assert_that(got).is_not_null()
			assert_bool(ThemeCarrierGuard.resolves_carrier(chip, _THEME, state, "CityResourceMetric")).is_true() \
				.override_failure_message(
					"чип %s в состоянии %s резолвит не CityResourceMetric " % [id, state]
					+ "(носитель не применился)"
				)
			assert_bool(got.bg_color == (want[0] as Color)).is_true() \
				.override_failure_message(
					"чип %s/%s: фон %s ≠ перенесённый %s" % [id, state, got.bg_color, want[0]]
				)
			assert_bool(got.border_color == want_border).is_true() \
				.override_failure_message(
					"чип %s/%s: рамка %s ≠ перенесённая %s" % [id, state, got.border_color, want_border]
				)
			# Общие свойства собирались в _panel_style, поля — в _resource_metric_style.
			assert_int(got.border_width_left).is_equal(1)
			assert_int(got.border_width_top).is_equal(1)
			assert_int(got.border_width_right).is_equal(1)
			assert_int(got.border_width_bottom).is_equal(1)
			assert_int(got.corner_radius_top_left).is_equal(6)
			assert_int(got.corner_radius_top_right).is_equal(6)
			assert_int(got.corner_radius_bottom_right).is_equal(6)
			assert_int(got.corner_radius_bottom_left).is_equal(6)
			assert_int(got.shadow_size).is_equal(5)
			assert_that(got.shadow_offset).is_equal(Vector2(0, 2))
			assert_bool(got.shadow_color == Color(0, 0, 0, 0.34)).is_true() \
				.override_failure_message("чип %s/%s потерял тень" % [id, state])
			assert_that(got.get_content_margin(SIDE_LEFT)).is_equal(8.0)
			assert_that(got.get_content_margin(SIDE_TOP)).is_equal(5.0)
			assert_that(got.get_content_margin(SIDE_RIGHT)).is_equal(8.0)
			assert_that(got.get_content_margin(SIDE_BOTTOM)).is_equal(5.0)


## Вариант объявляет четыре состояния. Остальные состояния Button (hover_pressed,
# selected) обязаны резолвиться от базового типа: если бы вариант объявил их «на
# всякий случай», чип поменял бы вид при нажатии с зажатой кнопкой — и кадр «после»
# разошёлся бы с «до». Прецедент — test_tail_screens_theme_carrier.gd про hover.
#
# Про терминалы: `assert_bool(x)` без `.is_true()`/`.is_false()` **ничего не проверяет**
# — мутация фона чипа на округлённый Color(0.1882, …) проходила зелёным, пока у
# проверок не появились терминалы. Каждый assert ниже обязан его иметь.
func test_chips_keep_states_outside_variation() -> void:
	var screen := _mk_screen()
	await get_tree().process_frame
	for id in ["Food", "Wood", "Iron"]:
		var chip := _chip(screen, id)
		assert_bool(ThemeCarrierGuard.resolves_carrier(chip, _THEME, "hover_pressed", "Button")).is_true() \
			.override_failure_message(
				"чип %s потерял hover_pressed от типа Button " % id
				+ "— вариант объявил состояние, которого в снятом коде не было"
			)



func _panel(screen: Node, node_name: String) -> PanelContainer:
	var node := screen.find_child(node_name, true, false) as PanelContainer
	assert_that(node).is_not_null()
	assert_str(node.get_class()).is_equal("PanelContainer") \
		.override_failure_message(
			"узел %s сменил тип: носители заявлены с base_type = \"PanelContainer\", " % node_name
			+ "для другого типа резолв уйдёт на стили его типа"
		)
	return node


## AC3 (а): все шесть панелей переведены на носители темы, override'ов не осталось.
func test_shell_panels_carry_theme_variation() -> void:
	var screen := _mk_screen()
	await get_tree().process_frame
	for node_name in _SHELL:
		var panel := _panel(screen, node_name)
		var want_variation: String = _SHELL[node_name][0]
		assert_str(str(panel.theme_type_variation)).is_equal(want_variation) \
			.override_failure_message("панель %s не переведена на носитель %s" % [node_name, want_variation])
		var ov := ThemeCarrierGuard.stylebox_overrides(panel, _FOCUS_ALLOWED)
		assert_int(ov.size()).is_equal(0) \
			.override_failure_message(
				"панель %s всё ещё несёт override — он сильнее темы: %s" % [node_name, ", ".join(ov.keys())]
			)


## AC3 (б): резолв даёт ровно снятые значения (цвета и геометрия _panel_style).
func test_shell_panels_resolve_transcribed_values() -> void:
	var screen := _mk_screen()
	await get_tree().process_frame
	for node_name in _SHELL:
		var spec: Array = _SHELL[node_name]
		var panel := _panel(screen, node_name)
		var variation: String = spec[0]
		var got: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		assert_that(got).is_not_null()
		assert_bool(ThemeCarrierGuard.resolves_carrier(panel, _THEME, "panel", variation)).is_true() \
			.override_failure_message(
				"панель %s резолвит не %s (носитель не применился)" % [node_name, variation]
			)
		assert_bool(got.bg_color == (spec[1] as Color)).is_true() \
			.override_failure_message(
				"панель %s: фон %s ≠ перенесённый %s" % [node_name, got.bg_color, spec[1]]
			)
		assert_bool(got.border_color == (spec[2] as Color)).is_true() \
			.override_failure_message(
				"панель %s: рамка %s ≠ перенесённая %s" % [node_name, got.border_color, spec[2]]
			)
		assert_int(got.border_width_left).is_equal(1)
		assert_int(got.border_width_top).is_equal(1)
		assert_int(got.border_width_right).is_equal(1)
		assert_int(got.border_width_bottom).is_equal(1)
		assert_int(got.corner_radius_top_left).is_equal(6)
		assert_int(got.corner_radius_top_right).is_equal(6)
		assert_int(got.corner_radius_bottom_right).is_equal(6)
		assert_int(got.corner_radius_bottom_left).is_equal(6)
		assert_int(got.shadow_size).is_equal(5)
		assert_that(got.shadow_offset).is_equal(Vector2(0, 2))
		assert_bool(got.shadow_color == Color(0, 0, 0, 0.34)).is_true() \
			.override_failure_message("панель %s потеряла тень" % node_name)
		assert_that(got.get_content_margin(SIDE_LEFT)).is_equal(12.0)
		assert_that(got.get_content_margin(SIDE_TOP)).is_equal(10.0)
		assert_that(got.get_content_margin(SIDE_RIGHT)).is_equal(12.0)
		assert_that(got.get_content_margin(SIDE_BOTTOM)).is_equal(10.0)


## Фон доски — единственная полупрозрачная панель экрана: под ней видно карту, поэтому
# альфа переносилась float-в-float и проверяется отдельно от непрозрачных панелей.
# Мутация «альфа 0.5 вместо 0.45» обязана падать здесь, а не ждать кадра.
func test_board_background_alpha_is_the_removed_float() -> void:
	var screen := _mk_screen()
	await get_tree().process_frame
	var board := _panel(screen, "CityBoardPanel")
	var got: StyleBoxFlat = board.get_theme_stylebox("panel") as StyleBoxFlat
	assert_that(got).is_not_null()
	assert_that(got.bg_color.a).is_equal(Color("#171915", 0.45).a) \
		.override_failure_message(
			"альфа фона доски %s ≠ снятой 0.45 — под полупрозрачным фоном видна карта, "
			% got.bg_color.a + "сдвиг альфы виден глазами"
		)
	assert_bool(got.bg_color.a < 1.0).is_true() \
		.override_failure_message("фон доски стал непрозрачным — кадр «до» был с просветом")
	var flat := Color(got.bg_color.r, got.bg_color.g, got.bg_color.b, 1.0)
	assert_bool(flat == Color("#171915")).is_true() \
		.override_failure_message("тон фона доски уехал: %s" % flat)


## Легаси-панель скрыта (visible = false) и показывается переключателем. Это
# негативный контроль кадра (её смена носителя в кадре не видна), но НЕ мёртвый узел:
# стиль обязан резолвиться, иначе при включении панель выйдет без рамки.
func test_legacy_panel_hidden_but_still_carries_style() -> void:
	var screen := _mk_screen()
	await get_tree().process_frame
	var legacy := _panel(screen, "LegacyActionsPanel")
	assert_bool(legacy.visible).is_false() \
		.override_failure_message("легаси-панель перестала быть скрытой — кадр «до» её не содержал")
	var sidebar := _panel(screen, "BuildSidebar")
	var got: StyleBoxFlat = legacy.get_theme_stylebox("panel") as StyleBoxFlat
	var want: StyleBoxFlat = sidebar.get_theme_stylebox("panel") as StyleBoxFlat
	assert_bool(got.get_instance_id() == want.get_instance_id()).is_true() \
		.override_failure_message(
			"легаси-панель резолвит не CityPanelDark — при включении она выйдет без рамки"
		)


func _open_catalog() -> Node:
	var screen := _mk_screen()
	var city := City.new()
	city.center = Vector2i(18, 20)
	_hero = auto_free(HeroController.new())
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	screen.setup(city, _hero, Vector2i(18, 20), rng, Vector2i(48, 48))
	screen.open()
	await get_tree().process_frame
	await get_tree().process_frame
	# та же строка, что CAPTURE_SETUP съёмки: кадр «с выбранной карточкой» без неё
	# не существует, и гард выделения проверял бы пустое состояние
	screen._on_building_card_pressed("campaign_farm")
	await get_tree().process_frame
	return screen


func _cards(screen: Node) -> Array[Node]:
	var scroll := screen.find_child("CatalogScroll", true, false)
	assert_that(scroll).is_not_null()
	var list := scroll.get_child(0)
	assert_int(list.get_child_count()).is_greater(3) \
		.override_failure_message("каталог не отрисовался — гард проверял пустой экран")
	var cards: Array[Node] = []
	for child in list.get_children():
		if String(child.name).begins_with("BuildingCard_"):
			cards.append(child)
	return cards


## AC3 (а): карточки переведены на носители, override'ов нет; выбранная — на CityCardSelected.
func test_catalog_cards_carry_theme_variation() -> void:
	var screen := await _open_catalog()
	var cards := _cards(screen)
	var selected_seen := 0
	for card in cards:
		assert_str(card.get_class()).is_equal("PanelContainer") \
			.override_failure_message(
				"карточка %s сменила тип: носители заявлены с base_type = \"PanelContainer\"" % card.name
			)
		var variation := str(card.theme_type_variation)
		assert_bool(variation in ["CityCard", "CityCardSelected"]).is_true() \
			.override_failure_message(
				"карточка %s несёт носитель %s — ожидались CityCard / CityCardSelected"
				% [card.name, variation]
			)
		var ov := ThemeCarrierGuard.stylebox_overrides(card, _FOCUS_ALLOWED)
		assert_int(ov.size()).is_equal(0) \
			.override_failure_message(
				"карточка %s всё ещё несёт override — он сильнее темы: %s" % [card.name, ", ".join(ov.keys())]
			)
		if variation == "CityCardSelected":
			selected_seen += 1
	assert_int(selected_seen).is_equal(1) \
		.override_failure_message(
			"выбранных карточек %d вместо одной — состояние выделения рисует не носитель" % selected_seen
		)


## AC3 (б): резолв даёт ровно снятые значения покоя и выделения.
func test_catalog_card_states_resolve_transcribed_values() -> void:
	var screen := await _open_catalog()
	var cards := _cards(screen)
	var idle: PanelContainer = null
	var selected: PanelContainer = null
	for card in cards:
		if str(card.theme_type_variation) == "CityCardSelected":
			selected = card as PanelContainer
		else:
			idle = card as PanelContainer
	assert_that(idle).is_not_null()
	assert_that(selected).is_not_null()
	# Рамки — литералы снятого кода (`Color("#d3ae5d") if selected else Color("#665638")`).
	# accent_gold (#e0bd67) здесь ошибкой: он у вкладок, и путаница двух золотых
	# меняла бы кадр на глазах, но не совпала бы с «до».
	_check_card_style(idle, "CityCard", Color("#211e18"), Color("#665638"))
	_check_card_style(selected, "CityCardSelected", Color("#29241b"), Color("#d3ae5d"))


func _check_card_style(
	node: PanelContainer, variation: String, want_bg: Color, want_border: Color
) -> void:
	var got: StyleBoxFlat = node.get_theme_stylebox("panel") as StyleBoxFlat
	assert_that(got).is_not_null()
	assert_bool(ThemeCarrierGuard.resolves_carrier(node, _THEME, "panel", variation)).is_true() \
		.override_failure_message(
			"карточка %s резолвит не %s (носитель не применился)" % [node.name, variation]
		)
	assert_bool(got.bg_color == want_bg).is_true() \
		.override_failure_message(
			"карточка %s: фон %s ≠ перенесённый %s" % [node.name, got.bg_color, want_bg]
		)
	assert_bool(got.border_color == want_border).is_true() \
		.override_failure_message(
			"карточка %s: рамка %s ≠ перенесённая %s" % [node.name, got.border_color, want_border]
		)
	assert_int(got.border_width_left).is_equal(1)
	assert_int(got.corner_radius_top_left).is_equal(6)
	assert_int(got.shadow_size).is_equal(5)
	assert_that(got.shadow_offset).is_equal(Vector2(0, 2))
	assert_bool(got.shadow_color == Color(0, 0, 0, 0.34)).is_true() \
		.override_failure_message("карточка %s потеряла тень" % node.name)
	assert_that(got.get_content_margin(SIDE_LEFT)).is_equal(12.0)
	assert_that(got.get_content_margin(SIDE_TOP)).is_equal(10.0)


## Рантайм-мутация: нажатие переносит выделение, отмена возвращает всех в покой.
# Это проверка поведения, а не стилей: если бы миграция оставила старый override или
# забыла сбросить носитель, кадр «до» и «после» разошлись бы, но тест ниже ловит
# конкретную поломку (какое именно карточка осталась золотой), а не пиксел.
func test_selection_switches_carrier_both_ways() -> void:
	var screen := await _open_catalog()
	var cards := _cards(screen)
	var first := String(cards[0].name).trim_prefix("BuildingCard_")
	var second := String(cards[1].name).trim_prefix("BuildingCard_")
	screen._on_building_card_pressed(first)
	assert_str(str(cards[0].theme_type_variation)).is_equal("CityCardSelected") \
		.override_failure_message("нажатая карточка не стала CityCardSelected")
	assert_str(str(cards[1].theme_type_variation)).is_equal("CityCard") \
		.override_failure_message("сосед нажатой карточки не остался в покое")
	screen._on_building_card_pressed(second)
	assert_str(str(cards[1].theme_type_variation)).is_equal("CityCardSelected") \
		.override_failure_message("вторая карточка не получила выделение")
	assert_str(str(cards[0].theme_type_variation)).is_equal("CityCard") \
		.override_failure_message(
			"первая карточка осталась золотой: выделение не снимается — раньше это делал override"
		)
	screen.cancel_placement()
	for card in cards:
		assert_str(str(card.theme_type_variation)).is_equal("CityCard") \
			.override_failure_message(
				"после cancel_placement карточка %s несёт %s" % [card.name, card.theme_type_variation]
			)
	assert_str(str(screen.get("_selected_building_id"))).is_empty() \
		.override_failure_message(
			"cancel_placement не сбросил выбранный id — следующий кадр "
			+ "каталога выйдет выделенным"
		)


## Вкладки: один носитель на четыре состояния. Активной вкладка становилась сменой
# button_pressed, поэтому второго носителя нет — состояние выбирает стиль само.
func test_catalog_tabs_carry_four_states() -> void:
	var screen := await _open_catalog()
	var tabs_node := screen.find_child("CategoryTabs", true, false)
	assert_that(tabs_node).is_not_null()
	var tabs := tabs_node.get_children()
	assert_int(tabs.size()).is_equal(5) \
		.override_failure_message("вкладок %d вместо пяти — гард проверял не каталог" % tabs.size())
	# idle_hover и active_hover_pressed нужны кросс-проверкам «normal == hover» и
	# «pressed == hover_pressed» (в снятом коде это были одни StyleBoxFlat); резолв
	# самого носителя — через предикат.
	var idle_hover: StyleBoxFlat = _THEME.get_stylebox("hover", "CityTab") as StyleBoxFlat
	var active_hover_pressed: StyleBoxFlat = (
		_THEME.get_stylebox("hover_pressed", "CityTab") as StyleBoxFlat
	)
	for tab in tabs:
		var button := tab as Button
		assert_that(button).is_not_null()
		assert_str(str(button.theme_type_variation)).is_equal("CityTab") \
			.override_failure_message("вкладка %s не переведена на носитель CityTab" % button.name)
		var ov := ThemeCarrierGuard.stylebox_overrides(button, _FOCUS_ALLOWED)
		assert_int(ov.size()).is_equal(0) \
			.override_failure_message(
				"вкладка %s несёт override — он сильнее темы: %s" % [button.name, ", ".join(ov.keys())]
			)
		var got_normal: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
		var got_pressed: StyleBoxFlat = button.get_theme_stylebox("pressed") as StyleBoxFlat
		assert_bool(ThemeCarrierGuard.resolves_carrier(button, _THEME, "normal", "CityTab")).is_true() \
			.override_failure_message("покой вкладки резолвит не CityTab/normal")
		assert_bool(ThemeCarrierGuard.resolves_carrier(button, _THEME, "pressed", "CityTab")).is_true() \
			.override_failure_message("активная вкладка резолвит не CityTab/pressed")
		# normal и hover — один и тот же стиль (в снятом коде их красил один StyleBoxFlat)
		assert_bool(got_normal.get_instance_id() == idle_hover.get_instance_id()).is_true() \
			.override_failure_message(
				"hover вкладки отличается от normal — в снятом коде "
				+ "они были одним стилем"
			)
		assert_bool(got_pressed.get_instance_id() == active_hover_pressed.get_instance_id()).is_true() \
			.override_failure_message("hover_pressed вкладки отличается от pressed")
		assert_bool(got_normal.bg_color == _TAB_IDLE_BG).is_true() \
			.override_failure_message(
				"фон покоя вкладки %s ≠ перенесённого %s" % [got_normal.bg_color, _TAB_IDLE_BG]
			)
		assert_that(got_normal.bg_color.a).is_equal(_TAB_IDLE_BG.a) \
			.override_failure_message("альфа покоя вкладки уехала: %s" % got_normal.bg_color.a)
		assert_bool(got_normal.border_color == _TAB_IDLE_BORDER).is_true() \
			.override_failure_message("рамка покоя вкладки %s ≠ перенесённой" % got_normal.border_color)
		assert_bool(got_pressed.bg_color == _TAB_ACTIVE_BG).is_true() \
			.override_failure_message("фон активной вкладки %s ≠ перенесённого" % got_pressed.bg_color)
		assert_bool(got_pressed.border_color == ThemeConfig.C_CITY_GOLD).is_true() \
			.override_failure_message(
				"рамка активной вкладки %s ≠ ThemeConfig.C_CITY_GOLD" % got_pressed.border_color
			)
		assert_int(got_normal.corner_radius_top_left).is_equal(4)
		assert_int(got_normal.border_width_left).is_equal(1)
		# StyleBoxFlat.new() в снятом коде полей не имел — приписать им нули значило бы
		# сдвинуть текст вкладок относительно кадра «до».
		assert_that(got_normal.get_content_margin(SIDE_LEFT)).is_equal(-1.0) \
			.override_failure_message("у стиля вкладки появились поля содержимого — текст сдвинется")


## Панель стоимости — отдельный PanelContainer внутри карточки: у него свои поля (8/5)
# и радиус (4), поэтому он не мог унаследовать носитель карточки.
func test_cost_panel_carries_theme_variation() -> void:
	var screen := await _open_catalog()
	var cards := _cards(screen)
	var checked := 0
	for card in cards:
		var cost := card.find_child("BuildingCostPanel", true, false) as PanelContainer
		if cost == null:
			continue
		checked += 1
		assert_str(str(cost.theme_type_variation)).is_equal("CityCostPanel") \
			.override_failure_message("панель стоимости карточки %s не на носителе" % card.name)
		var ov := ThemeCarrierGuard.stylebox_overrides(cost, _FOCUS_ALLOWED)
		assert_int(ov.size()).is_equal(0) \
			.override_failure_message(
				"панель стоимости всё ещё несёт override: %s" % ", ".join(ov.keys())
			)
		var got: StyleBoxFlat = cost.get_theme_stylebox("panel") as StyleBoxFlat
		assert_that(got).is_not_null()
		assert_bool(got.bg_color == _COST_BG).is_true() \
			.override_failure_message("фон стоимости %s ≠ перенесённого %s" % [got.bg_color, _COST_BG])
		assert_bool(got.border_color == _COST_BORDER).is_true() \
			.override_failure_message(
				"рамка стоимости %s ≠ перенесённой %s" % [got.border_color, _COST_BORDER]
			)
		assert_that(got.get_content_margin(SIDE_LEFT)).is_equal(8.0)
		assert_that(got.get_content_margin(SIDE_TOP)).is_equal(5.0)
		assert_int(got.corner_radius_top_left).is_equal(4)
		assert_int(got.shadow_size).is_equal(0) \
			.override_failure_message("у стоимости появилась тень — в снятом StyleBoxFlat её не было")
	assert_int(checked).is_greater(0) \
		.override_failure_message("ни одной панели стоимости не найдено — гард проверял пустоту")


# T-227 (С-2): проверки «в исходниках нет обхода темы» и «несуществующий тип не
# резолвит» переехали в res://tests/unit/ui/test_theme_source_scan.gd (скан всего
# production-кода, а не «своих» файлов) и res://tests/unit/ui/test_theme_variation_matrix.gd
# (контракт от носителя: все 70 вариантов темы, а не три экрана, которым завели файл).
# Здесь остались только проверки, привязанные к этому экрану: что ТЕМА отдаёт ровно те
# значения, которые рисовал снятый override (AC2), и что живой узел экрана не получает
# переопределений в рантайме.

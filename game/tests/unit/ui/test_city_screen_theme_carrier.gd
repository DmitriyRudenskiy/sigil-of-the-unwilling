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
# Рамка hover/pressed бралась из PALETTE.accent_gold — сравниваем с тем же источником,
# а не с продублированной шестнадцатеричной строкой.
const _STATES := {
	"normal": [Color("#30291d"), Color("#9a804d")],
	"hover": [Color("#3b3120"), null],
	"pressed": [Color("#45391f"), null],
	"disabled": [Color("#211e18"), Color("#665638")],
}

## Сколько add_theme_stylebox_override обязано остаться в city_screen.gd после
# подсреза 2: 16 было, 4 снято подсрезом 1 (чипы), 6 — подсрезом 2 (панели оболочки).
# Остальное — подрез 3 (каталог зданий, 5) и 4 (фокус клавиатуры, 1).
const _REMAINING_OVERRIDES := 6

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
		assert_bool(chip.has_theme_stylebox_override("normal")) \
			.override_failure_message("чип %s всё ещё несёт override — он сильнее темы" % id) \
			.is_false()


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
			var want_border: Color = want[1] if want[1] != null else CityScreen.PALETTE["accent_gold"]
			var got: StyleBoxFlat = chip.get_theme_stylebox(state) as StyleBoxFlat
			assert_that(got).is_not_null()
			var theme_style: StyleBoxFlat = _THEME.get_stylebox(state, "CityResourceMetric") as StyleBoxFlat
			assert_bool(got.get_instance_id() == theme_style.get_instance_id()).is_true() \
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
	var want_hover_pressed: StyleBox = _THEME.get_stylebox("hover_pressed", "Button")
	for id in ["Food", "Wood", "Iron"]:
		var chip := _chip(screen, id)
		var got: StyleBox = chip.get_theme_stylebox("hover_pressed")
		assert_bool(
			got != null and got.get_instance_id() == want_hover_pressed.get_instance_id()
		).is_true() \
			.override_failure_message(
				"чип %s потерял hover_pressed от типа Button " % id
				+ "— вариант объявил состояние, которого в снятом коде не было"
			)


## AC1 для подсреза: в чипах обходов не осталось, и счётчик по экрану не отрос.
# Файл целиком нулём быть не может — в нём ещё подсрезы 2–4, — поэтому проверка
# рэтчетом: ровно 12 вызовов, и ни одного на снятый хелпер.
func test_chip_overrides_removed_and_counter_ratcheted() -> void:
	var f := FileAccess.open("res://scripts/ui/city_screen.gd", FileAccess.READ)
	assert_that(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	var offenders := PackedStringArray()
	var live := 0
	for line in text.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("#") or t.begins_with(";"):
			continue
		if "_resource_metric_style" in t:
			offenders.append("снятый хелпер всё ещё упоминается: " + t.left(70))
		if "add_theme_stylebox_override" in t:
			live += 1
			offenders.append("остался override: " + t.left(70))
	assert_bool("_resource_metric_style" in text).is_false() \
		.override_failure_message("хелпер _resource_metric_style обязан быть удалён вместе с вызовами")
	assert_int(live).is_equal(_REMAINING_OVERRIDES) \
		.override_failure_message(
			"в city_screen.gd %d stylebox-override вместо %d (подсрез 1 снял 4 из 16):\n%s"
			% [live, _REMAINING_OVERRIDES, "\n".join(offenders)]
		)


## Негативный контроль силы гарда: несуществующий носитель не должен резолвить
# стиль чипа — иначе проверка резолва выше была бы пустой.
func test_unknown_variation_does_not_resolve_chip_style() -> void:
	var b := Button.new()
	b.theme_type_variation = "CityResourceMetricMissing"
	get_tree().root.add_child(b)
	await get_tree().process_frame
	var got: StyleBox = b.get_theme_stylebox("normal")
	var want: StyleBox = _THEME.get_stylebox("normal", "CityResourceMetric")
	assert_bool(got != null and got.get_instance_id() == want.get_instance_id()).is_false() \
		.override_failure_message("несуществующий носитель резолвит стиль чипа — проверка пуста")
	b.free()


# ── Подсрез 2: панели оболочки города ────────────────────────────────────────────
#
# Шесть панелей (шапка, инспектор, легенда, сайдбар, легаси-панель, фон доски)
# красились стилем, который код собирал в _panel_style. Перенесены в тему тремя
# носителями: CityPanelGold, CityPanelDark, CityBoardPanel (base_type = "PanelContainer").
#
# Про точность цвета: Godot сравнивает Color с epsilon ~1.19e-7 (float-точность),
# поэтому гард ловит перенос с осмысленным дрейфом (0.1882 вместо 0.1882352977991104 —
# это 3.5e-5) и не ловит различия ниже бита растра. Для пиксела это и есть «то же
# значение»; контроль чувствительности кадра (съёмка 2026-10-20) подтверждает, что
# властвует тема.

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
		assert_bool(panel.has_theme_stylebox_override("panel")).is_false() \
			.override_failure_message(
				"панель %s всё ещё несёт override на \"panel\" — он сильнее темы" % node_name
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
		var theme_style: StyleBoxFlat = _THEME.get_stylebox("panel", variation) as StyleBoxFlat
		assert_bool(got.get_instance_id() == theme_style.get_instance_id()).is_true() \
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


## AC1 для подсреза: шесть обходов сняты, счётчик по файлу — 6, и ни один из
# оставшихся не относится к панелям оболочки.
func test_shell_overrides_removed_and_counter_ratcheted() -> void:
	var f := FileAccess.open("res://scripts/ui/city_screen.gd", FileAccess.READ)
	assert_that(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	var live := 0
	var shell_offenders := PackedStringArray()
	for line in text.split("\n"):
		var t := line.strip_edges()
		if t.begins_with("#") or t.begins_with(";"):
			continue
		if "add_theme_stylebox_override" not in t:
			continue
		live += 1
		for node_name in _SHELL:
			if t.begins_with(node_name + ".add_theme_stylebox_override") \
					or t.begins_with("_" + node_name + ".add_theme_stylebox_override"):
				shell_offenders.append(t.left(70))
	assert_int(live).is_equal(_REMAINING_OVERRIDES) \
		.override_failure_message(
			"в city_screen.gd %d stylebox-override вместо %d (подсрез 2 снял 6 из 12)"
			% [live, _REMAINING_OVERRIDES]
		)
	assert_int(shell_offenders.size()).is_equal(0) \
		.override_failure_message(
			"у панелей оболочки остался override — он сильнее темы:\n%s" % "\n".join(shell_offenders)
		)


## Негативный контроль: несуществующий носитель не резолвит стиль панели — иначе
# проверка резолва выше была бы пустой (то же требование, что и для чипов).
func test_unknown_variation_does_not_resolve_shell_style() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "CityPanelGoldMissing"
	get_tree().root.add_child(panel)
	await get_tree().process_frame
	var got: StyleBox = panel.get_theme_stylebox("panel")
	var want: StyleBox = _THEME.get_stylebox("panel", "CityPanelGold")
	assert_bool(got != null and got.get_instance_id() == want.get_instance_id()).is_false() \
		.override_failure_message("несуществующий носитель резолвит стиль панели — проверка пуста")
	panel.free()

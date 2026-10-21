extends BaseTest

# T-147 (хвост: по одному stylebox-переопределению на экран — adventure_ui,
# info_panel, resource_collect_popup, artifact_chest_dialog).
#
# Хвост неоднороден, и это главное, что проверяют тесты ниже:
#   • adventure_ui изобретал стиль кодом (StyleBoxFlat.new() + цвета из ThemeConfig) —
#     такого стиля в теме не было; он перенесён в тему как StyleBoxFlat_adventure_column
#     и повешен на носитель PanelAdventureColumn;
#   • info_panel клал копию Panel/slot на восемь слотов типа Panel — носитель
#     PanelInfoSlot обязан быть заявлен с base_type = "Panel";
#   • resource_collect_popup клал на корень-Panel тот же стиль, что Panel резолвит
#     по своему типу, — переопределение было избыточным, снят без переноса;
#   • artifact_chest_dialog клал "panel" на голый Control, который вообще ничего не
#     рисует, — переопределение было мёртвым, снят без переноса.
#
# Резолв проверяется **на узле в реальной сцене**, а не на теме: тема может хранить
# вариант, который узел не использует (не тот base_type для типа узла), и проверка
# уровня темы это промолчит. Замер 2026-10-20: на живой сцене витрины 24/24 варианта
# резолвят на узле; автономный промт с узлом вне сцены — врёт.
#
# Каждый assert_* здесь и во всех гардах темы обязан иметь терминал (is_true, is_equal,
# …). Семь проверок этого файла были написаны как `assert_bool(x)`
# `.override_failure_message(...)` — без терминала GdUnit их не выполняет, проверка
# есть в коде и её нет в прогоне (класс T-123, повтор 2026-10-20; сканер
# `scripts/ci2_vacuous_asserts.py`). Зелёный прогон о таком не сообщает: силу гарда
# надо проверять мутацией, а не доверять её наличию терминалов.
const _THEME := preload("res://assets/theme/game_theme.tres")
const _SCENES := {
	"adventure_ui": preload("res://scenes/ui/adventure_ui.tscn"),
	"info_panel": preload("res://scenes/ui/info_panel.tscn"),
	"resource_collect_popup": preload("res://scenes/ui/resource_collect_popup.tscn"),
	"artifact_chest_dialog": preload("res://scenes/ui/artifact_chest_dialog.tscn"),
}

## Экраны этого хвоста — скрипт + сцена: переопределение живёт и в .gd, и в .tscn
# (в info_panel.tscn их было десять). Проверка по исходникам, а не обходом дерева:
# обход не отличает «узел этого экрана» от вложенной чужой сцены (внутри adventure_ui
# сидят ArmyPanel, MinimapPanel — у них свои хвосты и своя ответственность).
const _SOURCES := [
	"res://scripts/ui/adventure_ui.gd",
	"res://scenes/ui/adventure_ui.tscn",
	"res://scripts/ui/info_panel.gd",
	"res://scenes/ui/info_panel.tscn",
	"res://scripts/ui/resource_collect_popup.gd",
	"res://scenes/ui/resource_collect_popup.tscn",
	"res://scripts/ui/artifact_chest_dialog.gd",
	"res://scenes/ui/artifact_chest_dialog.tscn",
]

var _spawned: Array[Node] = []


func after_test() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


## Корни сцен неоднородны: adventure_ui — CanvasLayer, остальные — Control.
func _mk(key: String) -> Node:
	var scene: Node = (_SCENES[key] as PackedScene).instantiate()
	_spawned.append(scene)
	get_tree().root.add_child(scene)
	return scene


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_that(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	return text


## AC1: в исходниках четырёх экранов нет ни add_theme_stylebox_override, ни
# theme_override_styles (строк .tscn). Закомментированные упоминания не считаются —
# они не исполняются, но их тоже видно: тест режет «#» с начала строки.
func test_tail_sources_have_no_stylebox_overrides() -> void:
	var offenders := PackedStringArray()
	for path in _SOURCES:
		for line in _read(path).split("\n"):
			var t := line.strip_edges()
			if t.begins_with("#") or t.begins_with(";"):
				continue
			if "add_theme_stylebox_override" in t or "theme_override_styles/" in t:
				offenders.append("%s: %s" % [path.get_file(), t.left(70)])
	assert_str("\n".join(offenders)).is_empty() \
		.override_failure_message("остались stylebox-override:\n" + "\n".join(offenders))


## adventure_ui: стиль правой колонки был изобретён кодом — проверяем, что в теме
# лежит ровно он же, узел его резолвит, и значения перенесены без потерь.
func test_adventure_column_carries_transcribed_style() -> void:
	var scene := _mk("adventure_ui")
	await get_tree().process_frame
	var col := scene.get_node_or_null("RightColumn") as PanelContainer
	assert_that(col).is_not_null()
	assert_str(str(col.theme_type_variation)).is_equal("PanelAdventureColumn") \
		.override_failure_message("правая колонка не переведена на носитель темы")
	var got: StyleBoxFlat = col.get_theme_stylebox("panel") as StyleBoxFlat
	assert_that(got).is_not_null()
	assert_bool(ThemeCarrierGuard.resolves_carrier(col, _THEME, "panel", "PanelAdventureColumn")) \
		.override_failure_message("узел не резолвит носитель PanelAdventureColumn").is_true()
	# Значения снятого переопределения: ThemeConfig.C_PANEL_BG / C_PANEL_BORDER,
	# бордер 2 со всех сторон, поля 10.
	var bg := got.bg_color
	var bd := got.border_color
	assert_bool(bg == ThemeConfig.C_PANEL_BG) \
		.override_failure_message("фон %s ≠ перенесённый %s" % [bg, ThemeConfig.C_PANEL_BG]).is_true()
	assert_bool(bd == ThemeConfig.C_PANEL_BORDER) \
		.override_failure_message("рамка %s ≠ перенесённая %s" % [bd, ThemeConfig.C_PANEL_BORDER]) \
		.is_true()
	assert_int(got.border_width_left).is_equal(2)
	assert_int(got.border_width_top).is_equal(2)
	assert_int(got.border_width_right).is_equal(2)
	assert_int(got.border_width_bottom).is_equal(2)
	assert_that(got.get_content_margin(SIDE_LEFT)).is_equal(10.0)
	assert_that(got.get_content_margin(SIDE_TOP)).is_equal(10.0)
	assert_that(got.get_content_margin(SIDE_RIGHT)).is_equal(10.0)
	assert_that(got.get_content_margin(SIDE_BOTTOM)).is_equal(10.0)


## info_panel: восемь слотов обязаны резолвить ровно Panel/slot. Слоты имеют тип
# Panel, поэтому носитель заявлен с base_type = "Panel"; с чужим base_type резолв
# ушёл бы на Panel/panel (другая картинка) — этот тест это и ловит.
func test_info_panel_slots_resolve_slot_style() -> void:
	var scene := _mk("info_panel")
	await get_tree().process_frame
	var seen := 0
	for cols in [["hero_col", "hero_slot_"], ["town_col", "town_slot_"]]:
		for i in 4:
			var slot := scene.get_node_or_null("columns/%s/%s%d" % [cols[0], cols[1], i]) as Panel
			assert_that(slot).is_not_null()
			seen += 1
			assert_str(str(slot.theme_type_variation)).is_equal("PanelInfoSlot") \
				.override_failure_message("слот %s%d не на носителе темы" % [cols[1], i])
			assert_that(slot.get_theme_stylebox("panel")).is_not_null()
			assert_bool(ThemeCarrierGuard.resolves_carrier(slot, _THEME, "panel", "PanelInfoSlot")) \
				.override_failure_message(
					"слот %s%d резолвит не Panel/slot (носитель не применился)" % [cols[1], i]
				).is_true()
	assert_int(seen).is_equal(8)


## resource_collect_popup: корень — Panel, он резолвит Panel/panel по своему типу.
# Снятое переопределение клало тот же ресурс, поэтому носитель не нужен: проверяем,
# что стиль по-прежнему тот же (иначе «сняли и потеряли фон»).
func test_resource_popup_resolves_plate_by_type() -> void:
	var root := _mk("resource_collect_popup") as Control
	await get_tree().process_frame
	assert_str(root.get_class()).is_equal("Panel")
	assert_str(str(root.theme_type_variation)).is_empty()
	assert_that(root.get_theme_stylebox("panel")).is_not_null()
	assert_bool(ThemeCarrierGuard.resolves_carrier(root, _THEME, "panel", "Panel")) \
		.override_failure_message("попап потерял фон Panel/panel, который резолвится по типу").is_true()


## artifact_chest_dialog: корень — голый Control. Он не рисует "panel" ни при каком
# переопределении, поэтому снятый override был мёртвым и переносить нечего.
func test_chest_dialog_root_cannot_paint_panel() -> void:
	var root := _mk("artifact_chest_dialog")
	await get_tree().process_frame
	assert_str(root.get_class()).is_equal("Control") \
		.override_failure_message(
			"корень диалога сменил тип: при Control override 'panel' не рисовался, "
			+ "если это Panel/PanelContainer — снятый стиль надо возвращать в тему"
		)


## info_panel: десять кнопок действий несли theme_override_styles/normal в самом
# .tscn (не в коде) — тот же болезненный узор, что и вызовы в скриптах. Проверка
# резолвит ли вариант тот же стиль, и что hover/pressed остались от типа Button
# (вариант объявляет один normal — иначе снятие override молча сменило бы весь вид).
func test_info_panel_action_buttons_resolve_action_style() -> void:
	var scene := _mk("info_panel")
	await get_tree().process_frame
	var seen := 0
	for col in ["btn_col_left", "btn_col_right"]:
		for btn in scene.get_node("columns/%s" % col).get_children():
			if not (btn is Button):
				continue
			seen += 1
			assert_str(str(btn.theme_type_variation)).is_equal("ButtonAction") \
				.override_failure_message("%s не на носителе темы" % btn.name)
			assert_bool(ThemeCarrierGuard.resolves_carrier(btn, _THEME, "normal", "ButtonAction")) \
				.override_failure_message("%s резолвит не ButtonAction/normal" % btn.name).is_true()
			assert_bool(ThemeCarrierGuard.resolves_carrier(btn, _THEME, "hover", "Button")) \
				.override_failure_message(
					"%s потерял hover от типа Button (вариант его перекрыл)" % btn.name
				).is_true()
	assert_int(seen).is_equal(10)


## adventure_ui: у OptionsPopup (VBoxContainer) в .tscn висел theme_override_styles/panel.
# VBoxContainer стиль "panel" не рисует — override был мёртвый, снят без переноса.
# Живой проверки нет (рисовать нечего); ловится проверкой исходников (AC1).
func test_options_popup_had_dead_override_only() -> void:
	var scene := _mk("adventure_ui")
	await get_tree().process_frame
	var popup := scene.get_node_or_null("OptionsPopup") as Control
	assert_that(popup).is_not_null()
	assert_str(str(popup.theme_type_variation)).is_empty()
	assert_str(popup.get_class()).is_equal("VBoxContainer") \
		.override_failure_message(
			"узел сменил тип: для VBoxContainer снятый override был мёртвым, "
			+ "для рисующего типа его надо возвращать в тему"
		)


## Негативный контроль: незарегистрированный носитель не должен резолвить стиль
# PanelInfoSlot — иначе тест выше был бы пустым.
func test_unknown_variation_does_not_resolve_slot_style() -> void:
	var p := Panel.new()
	p.theme_type_variation = "PanelInfoSlotMissing"
	get_tree().root.add_child(p)
	_spawned.append(p)
	await get_tree().process_frame
	assert_bool(ThemeCarrierGuard.resolves_carrier(p, _THEME, "panel", "PanelInfoSlot")).is_false() \
		.override_failure_message("несуществующий носитель резолвит Panel/slot — проверка пуста")

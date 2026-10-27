extends BaseTest

# T-147 (миникарта): рамка `Frame` (Panel) в minimap_panel.tscn.
#
# Стиль жил локальным `sub_resource StyleBoxFlat_frame` в самой сцене и был посажен
# через `theme_override_styles/panel`. У `Panel` носитель `panel` законный, поэтому
# перенос прямой: носитель `MinimapFrame` (`base_type = "Panel"`) в общей теме,
# назначение — сценевое (`theme_type_variation`), узел объявлен там же.
#
# Этот срез закрывает ВТОРУЮ половину T-147 — сценевые `theme_override_styles/*`.
# После него их в `game/scenes` ноль (проверяется обходом ниже, а не grep в отчёте),
# и обход обратно не вернётся: гард считает строки по всем сценам.
#
# Нулевая дельта кадра (MANIFEST: before_a == after_a) доказывает только отсутствие
# визуального сдвига. Власть темы доказывает смена носителя: до переноса чужой
# носитель кадр не менял (override сильнее темы), после — меняет.
const _THEME := preload("res://assets/theme/game_theme.tres")
const _SCENE := preload("res://scenes/ui/minimap_panel.tscn")

## Сколько theme_override_styles обязано остаться во всём game/scenes: ноль.
# Растёт — значит в сцену вернулся стиль, который сильнее темы.
const _REMAINING_IN_SCENES := 0

var _panel: Control = null


func after_test() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.free()
	_panel = null


func _mk_panel() -> Control:
	_panel = _SCENE.instantiate() as Control
	get_tree().root.add_child(_panel)
	return _panel


func _frame(panel: Control) -> Panel:
	var frame := panel.get_node_or_null("Frame") as Panel
	assert_that(frame).is_not_null()
	return frame


## Стиль, каким его хранила сцена до переноса — те же литералы, что стояли в
# `theme_override_styles/panel`. Сверка свойство в свойство, а не «похоже, цвет тот же».
func _reference_frame_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.290196, 0.0509804, 0.0509804, 1)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.788235, 0.635294, 0.352941, 1)
	return sb


## Сравнение StyleBoxFlat свойство в свойство. Возвращает список разошедшихся имён.
func _diff(got: StyleBoxFlat, want: StyleBoxFlat) -> PackedStringArray:
	var bad := PackedStringArray()
	if got.bg_color != want.bg_color:
		bad.append("bg_color %s ≠ %s" % [got.bg_color, want.bg_color])
	if got.border_color != want.border_color:
		bad.append("border_color %s ≠ %s" % [got.border_color, want.border_color])
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		var gw := got.get_border_width(side)
		var vw := want.get_border_width(side)
		if gw != vw:
			bad.append("border_width[%d] %d ≠ %d" % [side, gw, vw])
		var gr := int(got.get_corner_radius(side))
		var vr := int(want.get_corner_radius(side))
		if gr != vr:
			bad.append("corner_radius[%d] %d ≠ %d" % [side, gr, vr])
		var gm := got.get_content_margin(side)
		var vm := want.get_content_margin(side)
		if not is_equal_approx(gm, vm):
			bad.append("content_margin[%d] %s ≠ %s" % [side, gm, vm])
		var ge := got.get_expand_margin(side)
		var ve := want.get_expand_margin(side)
		if not is_equal_approx(ge, ve):
			bad.append("expand_margin[%d] %s ≠ %s" % [side, ge, ve])
	if got.shadow_size != want.shadow_size:
		bad.append("shadow_size %d ≠ %d" % [got.shadow_size, want.shadow_size])
	if got.shadow_color != want.shadow_color:
		bad.append("shadow_color %s ≠ %s" % [got.shadow_color, want.shadow_color])
	if got.shadow_offset != want.shadow_offset:
		bad.append("shadow_offset %s ≠ %s" % [got.shadow_offset, want.shadow_offset])
	if got.draw_center != want.draw_center:
		bad.append("draw_center %s ≠ %s" % [got.draw_center, want.draw_center])
	if got.corner_detail != want.corner_detail:
		bad.append("corner_detail %d ≠ %d" % [got.corner_detail, want.corner_detail])
	return bad


## AC3 (а): `Frame` переведён на носитель темы и не несёт override.
func test_frame_carries_theme_variation() -> void:
	var panel := _mk_panel()
	await get_tree().process_frame
	var frame := _frame(panel)
	assert_str(str(frame.theme_type_variation)).is_equal("MinimapFrame") \
		.override_failure_message("`Frame` не переведён на носитель MinimapFrame")
	assert_bool(frame.has_theme_stylebox_override("panel")).is_false() \
		.override_failure_message("`Frame` всё ещё несёт theme_override_styles/panel — он сильнее темы")


## AC3 (б): резолв живого узла даёт ровно снятые значения — и именно тот ресурс,
# который заявлен в носителе (инстанс-идентичность ловит подмену id в теме).
func test_frame_resolves_transcribed_values() -> void:
	var panel := _mk_panel()
	await get_tree().process_frame
	var got: StyleBoxFlat = _frame(panel).get_theme_stylebox("panel") as StyleBoxFlat
	assert_that(got).is_not_null()
	var declared: StyleBoxFlat = _THEME.get_stylebox("panel", "MinimapFrame") as StyleBoxFlat
	assert_that(declared).is_not_null()
	assert_bool(got.get_instance_id() == declared.get_instance_id()).is_true() \
		.override_failure_message("`Frame` резолвит не MinimapFrame/styles/panel")
	var bad := _diff(got, _reference_frame_style())
	assert_int(bad.size()).is_equal(0) \
		.override_failure_message("стиль рамки разошёлся со снятого значения: %s" % ", ".join(bad))


## Рамка обязана получить стиль носителя, а не дефолт типа Panel: иначе носитель
# заявлен, но до резолва не доходит (не тот base_type — и проверка резолва выше была бы пуста).
func test_frame_does_not_fall_back_to_panel_default() -> void:
	var panel := _mk_panel()
	await get_tree().process_frame
	var fallback: StyleBox = _THEME.get_stylebox("panel", "Panel")
	var got: StyleBox = _frame(panel).get_theme_stylebox("panel")
	assert_that(fallback).is_not_null()
	assert_bool(got.get_instance_id() != fallback.get_instance_id()).is_true() \
		.override_failure_message("`Frame` резолвит Panel/styles/panel — носитель не применился")




func test_carrier_declares_panel_base_type() -> void:
	var f := FileAccess.open("res://assets/theme/game_theme.tres", FileAccess.READ)
	assert_that(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	var declared := 'MinimapFrame/base_type = "Panel"'
	assert_str(text).contains(declared) \
		.override_failure_message(
			"в теме нет строки `MinimapFrame/base_type = \"Panel\"` — носитель описан "
			+ "над другим классом (или удалён); узел `Frame` — Panel"
		)


func _tscn_files(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(path)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var full := path.path_join(name)
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_tscn_files(full))
		elif name.ends_with(".tscn"):
			out.append(full)
		name = d.get_next()
	d.list_dir_end()
	return out
# T-227 (С-2): проверки «в исходниках нет обхода темы» и «несуществующий тип не
# резолвит» переехали в res://tests/unit/ui/test_theme_source_scan.gd (скан всего
# production-кода, а не «своих» файлов) и res://tests/unit/ui/test_theme_variation_matrix.gd
# (контракт от носителя: все 70 вариантов темы, а не три экрана, которым завели файл).
# Здесь остались только проверки, привязанные к этому экрану: что ТЕМА отдаёт ровно те
# значения, которые рисовал снятый override (AC2), и что живой узел экрана не получает
# переопределений в рантайме.

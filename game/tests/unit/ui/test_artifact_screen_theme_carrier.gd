extends BaseTest

# T-147 (экран артефактов): `Center/Window/Outline` и `Center/Window/Bottom`.
#
# Код экрана вызывал обход в двух местах (`_style`, `_set_style_slot`), но это два
# ВЫЗЫВАЮЩИХ обёрнутых хелпера, а не два узла: из разворачивались ~20 вызовов
# примерно на 60 узлов. Пиксельная сверка (кадр + погрупповая раскраска малиновым,
# MANIFEST каталога sigil-reserve/t147-artifact) показала, что имя `panel` рисуют
# ровно два узла — оба PanelContainer. Остальные 58 (40 TextureRect, 16 Button,
# 4 Control) это имя не рисуют вовсе: для них оно не носитель, а мёртвая запись.
#
# Поэтому переносит в тему только живое: носители `ArtifactOutline` и
# `ArtifactBottom` (`base_type = "PanelContainer"`), назначение — сценевое
# (`theme_type_variation`). Мёртвые вызовы сняты как мёртвый код, а не перенесены.
#
# Нулевая дельта кадра (MANIFEST: before_state == after_state) доказывает только
# отсутствие визуального сдвига. Власть темы доказывает смена носителя: до переноса
# чужой носитель кадр не менял (override сильнее темы), после — меняет.
const _THEME := preload("res://assets/theme/game_theme.tres")
const _SCENE := preload("res://scenes/ui/artifact_inventory_screen.tscn")

## Сколько add_theme_stylebox_override обязано остаться в этом скрипте: ноль.
# Живые узлы переведены на носители темы, мёртвые сняты вместе с хелперами.
const _REMAINING_IN_SCRIPT := 0

var _screen: Control = null


func after_test() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.free()
	_screen = null


func _mk_screen() -> Control:
	_screen = _SCENE.instantiate() as Control
	get_tree().root.add_child(_screen)
	return _screen


func _node(screen: Control, path: String) -> Control:
	var n := screen.get_node_or_null(path) as Control
	assert_that(n).is_not_null()
	return n


## Стиль рамки окна таким, каким его хранила тема до переноса (`Panel/outline`) —
# те же литералы. Сверка свойство в свойство, а не «похоже, цвет тот же».
func _reference_outline_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(2)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.541176, 0.415686, 0.227451, 1)
	sb.bg_color = Color(0, 0, 0, 0)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	return sb


## Стиль нижней панели таким, каким его хранила тема до переноса (`Panel/panel`):
# девятичастичная текстура panel_bg.png, маржа текстуры = рамка (К-8). Литералы
# сняты с живого ресурса (Godot 4.7: `margin_*` из .tres — легаси-ключ, в движке
# его отдаёт content_margin, поэтому сверяются texture / texture_margin / content_margin).
func _reference_bottom_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://assets/ui/widgets/panels/panel_bg.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 12.0)
		sb.set_content_margin(side, 16.0)
	return sb


## Сравнение StyleBoxFlat свойство в свойство. Возвращает список разошедшихся имён.
func _diff_flat(got: StyleBoxFlat, want: StyleBoxFlat) -> PackedStringArray:
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
	if got.shadow_size != want.shadow_size:
		bad.append("shadow_size %d ≠ %d" % [got.shadow_size, want.shadow_size])
	if got.shadow_color != want.shadow_color:
		bad.append("shadow_color %s ≠ %s" % [got.shadow_color, want.shadow_color])
	if got.shadow_offset != want.shadow_offset:
		bad.append("shadow_offset %s ≠ %s" % [got.shadow_offset, want.shadow_offset])
	return bad


## Сравнение StyleBoxTexture свойство в свойство (текстура, маржа текстуры,
# контент-маржа, draw_center). Возвращает список разошедшихся имён.
func _diff_texture(got: StyleBoxTexture, want: StyleBoxTexture) -> PackedStringArray:
	var bad := PackedStringArray()
	if got.texture != want.texture:
		bad.append("texture %s ≠ %s" % [
			got.texture.resource_path if got.texture != null else "null",
			want.texture.resource_path if want.texture != null else "null",
		])
	if got.draw_center != want.draw_center:
		bad.append("draw_center %s ≠ %s" % [got.draw_center, want.draw_center])
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		var gt := got.get_texture_margin(side)
		var wt := want.get_texture_margin(side)
		if not is_equal_approx(gt, wt):
			bad.append("texture_margin[%d] %s ≠ %s" % [side, gt, wt])
		var gc := got.get_content_margin(side)
		var wc := want.get_content_margin(side)
		if not is_equal_approx(gc, wc):
			bad.append("content_margin[%d] %s ≠ %s" % [side, gc, wc])
	return bad


## (а) `Outline` переведён на носитель темы и не несёт override.
func test_outline_carries_theme_variation() -> void:
	var screen := _mk_screen()
	await get_tree().process_frame
	var outline := _node(screen, "Center/Window/Outline")
	assert_str(str(outline.theme_type_variation)).is_equal("ArtifactOutline") \
		.override_failure_message("`Outline` не переведён на носитель ArtifactOutline")
	var ov := ThemeCarrierGuard.stylebox_overrides(outline)
	assert_int(ov.size()).is_equal(0) \
		.override_failure_message(
			"`Outline` всё ещё несёт override — он сильнее темы: %s" % ", ".join(ov.keys())
		)


## (а) `Bottom` переведён на носитель темы и не несёт override.
func test_bottom_carries_theme_variation() -> void:
	var screen := _mk_screen()
	await get_tree().process_frame
	var bottom := _node(screen, "Center/Window/Bottom")
	assert_str(str(bottom.theme_type_variation)).is_equal("ArtifactBottom") \
		.override_failure_message("`Bottom` не переведён на носитель ArtifactBottom")
	var ov := ThemeCarrierGuard.stylebox_overrides(bottom)
	assert_int(ov.size()).is_equal(0) \
		.override_failure_message(
			"`Bottom` всё ещё несёт override — он сильнее темы: %s" % ", ".join(ov.keys())
		)


## (б) резолв живого узла даёт ровно снятые значения — и именно тот ресурс, который
# заявлен в носителе (инстанс-идентичность ловит подмену id в теме).
func test_outline_resolves_transcribed_values() -> void:
	var screen := _mk_screen()
	await get_tree().process_frame
	var outline := _node(screen, "Center/Window/Outline")
	var got: StyleBoxFlat = outline.get_theme_stylebox("panel") as StyleBoxFlat
	assert_that(got).is_not_null() \
		.override_failure_message("`Outline` резолвит не StyleBoxFlat — класс стиля часть снятого значения")
	assert_bool(ThemeCarrierGuard.resolves_carrier(outline, _THEME, "panel", "ArtifactOutline")).is_true() \
		.override_failure_message("`Outline` резолвит не ArtifactOutline/styles/panel")
	var bad := _diff_flat(got, _reference_outline_style())
	assert_int(bad.size()).is_equal(0) \
		.override_failure_message("стиль рамки разошёлся со снятого значения: %s" % ", ".join(bad))


## (б) то же для нижней панели: StyleBoxTexture, а не StyleBoxFlat — класс стиля
# тоже часть снятого значения, подмена класса падает здесь, а не на кадре.
func test_bottom_resolves_transcribed_values() -> void:
	var screen := _mk_screen()
	await get_tree().process_frame
	var bottom := _node(screen, "Center/Window/Bottom")
	var got: StyleBoxTexture = bottom.get_theme_stylebox("panel") as StyleBoxTexture
	assert_that(got).is_not_null() \
		.override_failure_message("`Bottom` резолвит не StyleBoxTexture — класс стиля часть снятого значения")
	assert_bool(ThemeCarrierGuard.resolves_carrier(bottom, _THEME, "panel", "ArtifactBottom")).is_true() \
		.override_failure_message("`Bottom` резолвит не ArtifactBottom/styles/panel")
	var bad := _diff_texture(got, _reference_bottom_style())
	assert_int(bad.size()).is_equal(0) \
		.override_failure_message("стиль нижней панели разошёлся со снятого значения: %s" % ", ".join(bad))


## Узлы обязаны получить стиль носителя, а не дефолт типа PanelContainer: иначе
# носитель заявлен, но до резолва не доходит (не тот base_type — и проверка резолва
# выше была бы пуста).
func test_nodes_do_not_fall_back_to_panel_container_default() -> void:
	# Замечено (2026-07-06, design.md): тема не имеет записи PanelContainer, поэтому
	# эта проверка пуста по инстансам (узел и theme.get_stylebox дают встроенный
	# дефолт движка разными инстансами) — защита экрана несёт проверка резолва.
	# Функция сохранена как регрессивный якорь на семантику предиката.
	var screen := _mk_screen()
	await get_tree().process_frame
	for path in ["Center/Window/Outline", "Center/Window/Bottom"]:
		assert_bool(
			ThemeCarrierGuard.falls_back_to_type_default(_node(screen, path), _THEME, "panel", "PanelContainer")
		).is_false() \
			.override_failure_message("`%s` резолвит дефолт PanelContainer — носитель не применился" % path)


func test_carriers_declare_panel_container_base_type() -> void:
	var f := FileAccess.open("res://assets/theme/game_theme.tres", FileAccess.READ)
	assert_that(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	for declared in [
		'ArtifactOutline/base_type = "PanelContainer"',
		'ArtifactBottom/base_type = "PanelContainer"',
	]:
		assert_str(text).contains(declared) \
			.override_failure_message(
				"в теме нет строки `%s` — носитель описан над другим классом (или удалён); "
				% declared + "узлы `Outline` и `Bottom` — PanelContainer"
			)


# T-227 (С-2): проверки «в исходниках нет обхода темы» и «несуществующий тип не
# резолвит» переехали в res://tests/unit/ui/test_theme_source_scan.gd (скан всего
# production-кода, а не «своих» файлов) и res://tests/unit/ui/test_theme_variation_matrix.gd
# (контракт от носителя: все 70 вариантов темы, а не три экрана, которым завели файл).
# Здесь остались только проверки, привязанные к этому экрану: что ТЕМА отдаёт ровно те
# значения, которые рисовал снятый override (AC2), и что живой узел экрана не получает
# переопределений в рантайме.

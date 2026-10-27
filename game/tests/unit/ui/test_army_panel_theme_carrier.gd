extends BaseTest

# T-147 (army_panel): стили корня панели и восьми слотов юнитов.
#
# Оба рисовались StyleBoxFlat, который `_ready` собирал на ходу, и сажал через
# add_theme_stylebox_override. У PanelContainer и Panel носитель "panel" законный,
# поэтому перенос прямой: два носителя (ArmyPanel, ArmySlot), назначенные в сцене,
# а не в коде — узлы объявлены там же.
#
# Почему резолв проверяется на живом экземпляре, а не только на теме: первое же
# написание носителя слота резолвилось НЕ туда — sub_resource с id="StyleBoxFlat_army_slot"
# в game_theme.tres уже существовал (алый стиль армейского слота из kitchen-sink,
# носитель `PanelArmySlot`), и ссылка на него молча взяла старый ресурс: тема
# читалась без ошибки, кадр бы это показал, а проверка уровня темы — нет. Отсюда
# два гарда ниже: резолв живого узла и уникальность id в файле темы.
#
# Нулевая дельта кадра (MANIFEST: before_a == after_a) доказывает только отсутствие
# визуального сдвига. Власть темы доказывает смена носителя: до переноса чужой
# носитель кадр не менял (override сильнее), после — меняет.
const _THEME := preload("res://assets/theme/game_theme.tres")
const _SCENE := preload("res://scenes/ui/army_panel.tscn")

## Сколько add_theme_stylebox_override обязано остаться во всём game/scripts:
# city_screen.gd — 1 (фокус клавиатуры, подрез 4 ждёт решения владельца про
# Button/focus). Растёт — значит обход вернулся туда, где его уже убрали; после
# каждого снятого подреза константа уменьшается, иначе гард молчит на новом нуле.
const _REMAINING_IN_SCRIPTS := 1

var _panel: Control = null


func after_test() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.free()
	_panel = null


func _mk_panel() -> Control:
	_panel = _SCENE.instantiate() as Control
	get_tree().root.add_child(_panel)
	return _panel


func _slot(panel: Control, i: int) -> Panel:
	var slot := panel.get_node_or_null("Grid/Slot%d" % i) as Panel
	assert_that(slot).is_not_null()
	return slot


## Стиль, каким его собирал снятый код _ready. Сверка свойства в свойство, а не
# «похоже, цвет тот же»: перенос с округлением или потеря радиуса падают.
func _reference_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeConfig.C_PANEL_MID
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(2)
	sb.border_color = ThemeConfig.C_PANEL_BORDER
	return sb


func _reference_slot_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeConfig.C_SLOT_BG
	sb.set_corner_radius_all(3)
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


## AC3 (а): корень и все восемь слотов идут на носители темы, а не на override.
func test_panel_and_slots_carry_theme_variations() -> void:
	var panel := _mk_panel()
	await get_tree().process_frame
	assert_str(str(panel.theme_type_variation)).is_equal("ArmyPanel") \
		.override_failure_message("корень панели не переведён на носитель ArmyPanel")
	var pov := ThemeCarrierGuard.stylebox_overrides(panel)
	assert_int(pov.size()).is_equal(0) \
		.override_failure_message("корень всё ещё несёт override — он сильнее темы: %s" % ", ".join(pov.keys()))
	for i in 8:
		var slot := _slot(panel, i)
		assert_str(str(slot.theme_type_variation)).is_equal("ArmySlot") \
			.override_failure_message("слот %d не переведён на носитель ArmySlot" % i)
		var sov := ThemeCarrierGuard.stylebox_overrides(slot)
		assert_int(sov.size()).is_equal(0) \
			.override_failure_message("слот %d всё ещё несёт override: %s" % [i, ", ".join(sov.keys())])


## AC3 (б): резолв живого узла даёт ровно снятые значения — и именно тот ресурс,
# который заявлен в носителе (инстанс-идентичность ловит подмену id в теме).
func test_panel_resolves_transcribed_values() -> void:
	var panel := _mk_panel()
	await get_tree().process_frame
	var got: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_that(got).is_not_null()
	assert_bool(ThemeCarrierGuard.resolves_carrier(panel, _THEME, "panel", "ArmyPanel")).is_true() \
		.override_failure_message("корень резолвит не ArmyPanel/styles/panel")
	var bad := _diff(got, _reference_panel_style())
	assert_int(bad.size()).is_equal(0) \
		.override_failure_message("стиль корня разошёлся со снятого кода: %s" % ", ".join(bad))


func test_slots_resolve_transcribed_values() -> void:
	var panel := _mk_panel()
	await get_tree().process_frame
	var want := _reference_slot_style()
	for i in 8:
		var got: StyleBoxFlat = _slot(panel, i).get_theme_stylebox("panel") as StyleBoxFlat
		assert_that(got).is_not_null()
		assert_bool(ThemeCarrierGuard.resolves_carrier(_slot(panel, i), _THEME, "panel", "ArmySlot")).is_true() \
			.override_failure_message("слот %d резолвит не ArmySlot/styles/panel" % i)
		var bad := _diff(got, want)
		assert_int(bad.size()).is_equal(0) \
			.override_failure_message("стиль слота %d разошёлся со снятого кода: %s" % [i, ", ".join(bad)])


## Слот обязан получить стиль носителя, а не дефолт типа Panel: иначе носитель
# заявлен, но до резолва не доходит (тот же base_type не тот, и проверка резолва
# выше была бы пустой).
func test_slots_do_not_fall_back_to_panel_default() -> void:
	var panel := _mk_panel()
	await get_tree().process_frame
	for i in 8:
		assert_bool(
			ThemeCarrierGuard.falls_back_to_type_default(_slot(panel, i), _THEME, "panel", "Panel")
		).is_false() \
			.override_failure_message(
				"слот %d резолвит Panel/styles/panel — носитель ArmySlot не применился" % i
			)




func test_theme_sub_resource_ids_are_unique() -> void:
	var f := FileAccess.open("res://assets/theme/game_theme.tres", FileAccess.READ)
	assert_that(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	var seen := {}
	var dupes := PackedStringArray()
	var re := RegEx.create_from_string("id=\"([^\"]+)\"")
	assert_that(re).is_not_null()
	for m in re.search_all(text):
		var id: String = m.get_string(1)
		if seen.has(id):
			dupes.append(id)
		seen[id] = true
	assert_int(dupes.size()).is_equal(0) \
		.override_failure_message("дубли sub_resource id в теме: %s" % ", ".join(dupes))


func _gd_files(path: String) -> PackedStringArray:
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
				out.append_array(_gd_files(full))
		elif name.ends_with(".gd"):
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

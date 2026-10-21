extends BaseTest

# Прямые тесты общего предиката ThemeCarrierGuard (chore/theme-type-hygiene,
# задача 2.2): семейство гардов test_*_theme_carrier.gd ходит через него, но
# предикат обязан иметь собственное покрытие — иначе тихий сбой предиката
# (например, get_property_list перестанет отдавать theme_override_styles)
# сделает все восемь гардов ложными по одному месту.

const _THEME := preload("res://assets/theme/game_theme.tres")

var _nodes: Array[Node] = []


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


## Проба — PanelContainer с темой игры: у типа есть стиль `panel`, носители
## города/армии/артефактов заявлены с base_type = "PanelContainer".
func _probe() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme = _THEME
	_nodes.append(p)
	get_tree().root.add_child(p)
	return p


func test_stylebox_overrides_empty_on_clean_node() -> void:
	var p := _probe()
	assert_int(ThemeCarrierGuard.stylebox_overrides(p).size()).is_equal(0) \
		.override_failure_message("у чистого узла нашлись override'ы — предикат врёт")


func test_stylebox_overrides_detects_code_set_override() -> void:
	var p := _probe()
	p.set("theme_override_styles/panel", StyleBoxFlat.new())
	var ov := ThemeCarrierGuard.stylebox_overrides(p)
	assert_int(ov.size()).is_equal(1) \
		.override_failure_message("кодовый override не найден предикатом")
	assert_object(ov.get("panel")).is_not_null() \
		.override_failure_message("override найден, но значение не отдано")


func test_stylebox_overrides_respects_allowlist() -> void:
	var p := _probe()
	p.set("theme_override_styles/panel", StyleBoxFlat.new())
	assert_int(ThemeCarrierGuard.stylebox_overrides(p, ["panel"]).size()).is_equal(0) \
		.override_failure_message("allowlist не исключил имя — документированный остаток падёт")


func test_resolves_carrier_true_for_registered_carrier() -> void:
	var p := _probe()
	p.theme_type_variation = &"PanelPlate"
	assert_bool(ThemeCarrierGuard.resolves_carrier(p, _THEME, "panel", "PanelPlate")).is_true() \
		.override_failure_message("реальный носитель не резолвится — предикат сломан")


func test_resolves_carrier_false_for_unregistered_name() -> void:
	var p := _probe()
	p.theme_type_variation = &"PanelPlateMissing"
	assert_bool(ThemeCarrierGuard.resolves_carrier(p, _THEME, "panel", "PanelPlate")).is_false() \
		.override_failure_message(
			"незарегистрированное имя резолвит носитель — негативный контроль пуст"
		)


func test_resolves_carrier_false_when_carrier_absent() -> void:
	var p := _probe()
	assert_bool(ThemeCarrierGuard.resolves_carrier(p, _THEME, "panel", "NoSuchCarrier")).is_false() \
		.override_failure_message("несуществующий носитель засчитан как резолв")


## Фоллбэк-проверка инстанс-идентична только для типов, имеющих запись в теме
# (Panel — есть: Panel/styles/panel). PanelContainer записи не имеет: узел и
# theme.get_stylebox дают встроенный дефолт движка разными инстансами
# (замерено, см. doc-комментарий предиката) — на нём проверка пуста.
func test_falls_back_to_type_default_true_for_plain_node() -> void:
	var p := Panel.new()
	p.theme = _THEME
	_nodes.append(p)
	get_tree().root.add_child(p)
	assert_bool(
		ThemeCarrierGuard.falls_back_to_type_default(p, _THEME, "panel", "Panel")
	).is_true() \
		.override_failure_message("обычный узел не резолвит дефолт типа — замер устарел")


## Носитель с base_type = "Panel" (PanelInfoSlot): узел резолвит ресурс носителя,
# а не Panel/panel — проверка обязана сказать «не фоллбэк».
func test_falls_back_to_type_default_false_with_carrier() -> void:
	var p := Panel.new()
	p.theme = _THEME
	p.theme_type_variation = &"PanelInfoSlot"
	_nodes.append(p)
	get_tree().root.add_child(p)
	assert_bool(ThemeCarrierGuard.falls_back_to_type_default(p, _THEME, "panel", "Panel")).is_false() \
		.override_failure_message("узел с носителем резолвит дефолт типа — носитель не применился")

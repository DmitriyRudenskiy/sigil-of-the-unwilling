extends BaseTest

# T-147 (перенос носителей стиля витрины kitchen_sink в тему). Витрина брала стиль
# из темы и клала его на узел через add_theme_stylebox_override — переопределение
# сильнее темы, поэтому кит шага 4 не имел над этими узлами власти (а тикет требует,
# чтобы витрина показывала тему, а не перекрашивала её). Перенос технический: вариант
# темы ссылается на тот же SubResource, значения не меняются.
#
# Проверки:
#   1) на узлах витрины нет ни одного stylebox-переопределения (AC1, по всему дереву);
#   2) узлы переведены на зарегистрированные варианты темы (AC3);
#   3) вариант резолвит ровно тот же стиль, что клался кодом (AC2 как «не хуже»:
#      тот же StyleBox → тот же пиксел);
#   4) снятый override фокуса был мёртвым: Button резолвит focus сам;
#   5) негативный контроль: незарегистрированный тип носителя не резолвит.

const _SCENE := preload("res://scenes/ui/kitchen_sink.tscn")
const _THEME := preload("res://assets/theme/game_theme.tres")

# вариант темы → [имя стиля, тип-источник, стиль-элемент носителя]. Левая часть —
# то, что узел получает из темы; правая — откуда брал стиль снятый
# add_theme_stylebox_override.
const _CARRIERS := {
	"PanelWindow": ["window", "Panel", "panel"],
	"PanelSlot": ["slot", "Panel", "panel"],
	"PanelSlotThin": ["slot_thin", "Panel", "panel"],
	"PanelArmySlot": ["army_slot", "Panel", "panel"],
	"PanelArmySlotHover": ["army_slot_hover", "Panel", "panel"],
	"PanelArmySlotSelected": ["army_slot_selected", "Panel", "panel"],
	"PanelArmySlotDisabled": ["army_slot_disabled", "Panel", "panel"],
	"PanelChip": ["chip", "Panel", "panel"],
	"SwatchButtonNormal": ["normal", "Button", "panel"],
	"SwatchButtonHover": ["hover", "Button", "panel"],
	"SwatchButtonPressed": ["pressed", "Button", "panel"],
	"SwatchButtonDisabled": ["disabled", "Button", "panel"],
	"DangerButton": ["button_red", "Panel", "normal"],
}

# Сколько раз вариант обязан встретиться в дереве витрины. PanelPlate — фон экрана
# и образец «panel» в §4.2; PanelSlotThin — образец «slot_thin» и три страницы вкладок.
const _EXPECTED_COUNTS := {
	"PanelPlate": 2,
	"PanelSlotThin": 4,
}

var _nodes: Array[Node] = []


func after_test() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _mk_sink() -> Control:
	var scene: Control = _SCENE.instantiate()
	_nodes.append(scene)
	get_tree().root.add_child(scene)
	return scene


## Обход дерева: (узел, вариант темы) для всех Control с вариантом.
func _walk(root: Node) -> Array[Control]:
	var out: Array[Control] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			if c is Control:
				out.append(c as Control)
			stack.append(c)
	return out


func _variation_counts(controls: Array[Control]) -> Dictionary:
	var counts := {}
	for c in controls:
		var v := str(c.theme_type_variation)
		counts[v] = int(counts.get(v, 0)) + 1
	return counts


## AC1: ни одного локального stylebox-переопределения во всём дереве витрины —
# не только на пяти перенесённых узлах, иначе следующая правка вернёт их молча.
func test_sink_has_no_stylebox_overrides() -> void:
	var scene := _mk_sink()
	for c in _walk(scene):
		for prop in c.get_property_list():
			var pname: String = prop["name"]
			if not pname.begins_with("theme_override_styles/"):
				continue
			assert_object(c.get(pname)).is_null() \
				.override_failure_message(
					"на %s (%s) висит stylebox-override %s"
					% [c.name, c.theme_type_variation, pname.trim_prefix("theme_override_styles/")]
				)


## AC3: витрина переведена на варианты темы — каждый заявленный носитель встречается
# в дереве, а не существует только в теме.
func test_sink_nodes_carry_theme_variations() -> void:
	var counts := _variation_counts(_walk(_mk_sink()))
	for variation in _CARRIERS.keys():
		assert_int(int(counts.get(variation, 0))).is_greater_equal(1) \
			.override_failure_message("витрина не использует вариант темы %s" % variation)
	for variation in _EXPECTED_COUNTS.keys():
		assert_int(int(counts.get(variation, 0))).is_equal(_EXPECTED_COUNTS[variation]) \
			.override_failure_message("вариант %s должен встречаться %d раз" % [
				variation, _EXPECTED_COUNTS[variation]])


## AC2 как «не хуже»: вариант резолвит тот же StyleBox, что клал снятый override.
# Совпадает не цвет, а ресурс целиком — вместе с полями, которых мы не касались.
func test_carriers_resolve_the_same_stylebox_as_the_removed_overrides() -> void:
	for variation in _CARRIERS.keys():
		var source: Array = _CARRIERS[variation]
		var from_variation: StyleBox = _THEME.get_stylebox(source[2], StringName(variation))
		var from_source: StyleBox = _THEME.get_stylebox(source[0], source[1])
		assert_object(from_variation).is_not_null() \
			.override_failure_message("%s не резолвит носитель" % variation)
		assert_bool(from_variation == from_source).is_true() \
			.override_failure_message("%s ведёт не на %s/%s" % [variation, source[1], source[0]])


## Снятый override `focused.add_theme_stylebox_override("focus", ...)` клал на кнопку
# тот же focus, что Button резолвит сам: проверка фиксирует, что удаление мёртвого
# кода не меняет пиксел.
func test_removed_focus_override_was_dead() -> void:
	var btn := Button.new()
	_nodes.append(btn)
	btn.theme = _THEME
	get_tree().root.add_child(btn)
	assert_bool(btn.get_theme_stylebox("focus") == _THEME.get_stylebox("focus", "Button")).is_true() \
		.override_failure_message("Button резолвит focus не из темы — удаление override меняло пиксел")


## Негативный контроль: вариант обязан быть зарегистрирован с base_type. На
# несуществующем типе движок отдаёт стиль базового PanelContainer, и узел молча
# теряет носитель.
func test_unregistered_type_does_not_resolve_carrier() -> void:
	var p := PanelContainer.new()
	_nodes.append(p)
	p.theme = _THEME
	p.theme_type_variation = &"PanelWindowMissing"
	get_tree().root.add_child(p)
	assert_bool(p.get_theme_stylebox("panel") == _THEME.get_stylebox("panel", "PanelWindow")) \
		.is_false() \
		.override_failure_message("несуществующий тип резолвит носитель — проверка ничего не стоит")

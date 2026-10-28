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
		var ov := ThemeCarrierGuard.stylebox_overrides(c)
		assert_int(ov.size()).is_equal(0) \
			.override_failure_message(
				"на %s (%s) висит stylebox-override: %s"
				% [c.name, c.theme_type_variation, ", ".join(ov.keys())]
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
	assert_bool(ThemeCarrierGuard.resolves_carrier(btn, _THEME, "focus", "Button")).is_true() \
		.override_failure_message("Button резолвит focus не из темы — удаление override меняло пиксел")


## T-228: любой надетый на узел витрины вариант обязан быть зарегистрирован в теме
# именно для базового типа этого узла. Литеральный скан source-scan таких назначений
# не видит: витрина надевает варианты из словарей (PANEL_VARIATIONS, _label(v, v)),
# поэтому здесь — обход живого дерева. Молчаливое ничего (вариант без base_type или
# вариант чужого типа) на дереве витрины краснеет.
func test_every_variation_on_the_sink_tree_is_live_for_its_node() -> void:
	var sections := {}
	for s in _THEME.get_type_list():
		sections[String(s)] = true
	var dead := PackedStringArray()
	var wrong_base := PackedStringArray()
	var wearing := 0
	for c in _walk(_mk_sink()):
		var variation := String(c.theme_type_variation)
		if variation == "":
			continue
		wearing += 1
		var base := String(_THEME.get_type_variation_base(StringName(variation)))
		if base == "":
		# Не зарегистрированный вариант сам по себе не дефект: Godot резолвит секцию по
		# имени (замер T-228), поэтому TooltipPanel/TooltipLabel на витрине живые. Мёртвы
		# два других случая: имени нет среди секций темы, и вариант равен типу узла.
			if not sections.has(variation):
				dead.append("%s (%s) надета секция %s — её нет в теме" % [
					c.name, c.get_class(), variation])
			elif variation == String(c.get_class()):
				dead.append("%s (%s): вариант равен типу узла — самоприсваивание" % [
					c.name, c.get_class()])
			continue
		if not ClassDB.is_parent_class(c.get_class(), StringName(base)):
			wrong_base.append("%s (%s) не наследник базового типа варианта %s (%s)" % [
				c.name, c.get_class(), variation, base])
	assert_int(dead.size() + wrong_base.size()).is_equal(0) \
		.override_failure_message(
			"варианты темы на дереве витрины не работают:\n%s\n%s"
			% ["\n".join(dead), "\n".join(wrong_base)])
	# Пустой обход = молчаливый зелёный: витрина обязана что-то надевать.
	assert_bool(wearing >= 20).is_true() \
		.override_failure_message("на дереве витрины вариантов почти нет: %d" % wearing)


## T-228: раздел §4.8 обязан показывать и настоящий механизм подсказки (tooltip_text),
## и её пластину/текст — иначе витрина теряет единственное визуальное доказательство К-6
## (пластину подсказки больше нигде не снять: на живых экранах она не рисуется).
# Проверка привязана к разделу, а не к дереву целиком: tooltip_text есть и в других
# секциях (слайдер, §4.6), и глобальное «хотя бы один узел» краснеет лишь когда
# подсказок не осталось вовсе — мутант M6 это и показал.
func test_tooltip_section_uses_the_engine_mechanism() -> void:
	var scene := _mk_sink()
	var section: Node = null
	for c in _walk(scene):
		var lbl := c as Label
		if lbl != null and String(lbl.text).contains("§4.8"):
			section = lbl.get_parent()
	assert_object(section).is_not_null() \
		.override_failure_message("на витрине не найден раздел §4.8 — проверка подсказки нечего не проверяет")
	var with_tip: Array[Control] = []
	for c in _walk(section):
		if String(c.tooltip_text) != "":
			with_tip.append(c)
	assert_bool(with_tip.size() >= 1).is_true() \
		.override_failure_message(
			"в разделе §4.8 нет ни одного узла с tooltip_text — витрина рисует имитацию подсказки")
	var plate: StyleBox = _THEME.get_stylebox("panel", "TooltipPanel")
	assert_object(plate).is_not_null().override_failure_message(
		"тема не держит TooltipPanel/panel — пластину подсказки рисует дефолт движка")
	for c in with_tip:
		assert_bool(c.get_theme_stylebox("panel", "TooltipPanel") == plate).is_true() \
			.override_failure_message("живой узел резолвит не нашу пластину подсказки")
	# Кадр-ловушка (ux-review T-228): первый вариант правки снял с панели витрины
	# `theme_type_variation = "TooltipPanel"` «как с не-вариантом» — и на кадре пластина
	# подсказки исчезла (7330 px, золотая рамка). Регресс стоит ровно столько, сколько
	# стоит проверка: раздел обязан надевать секцию пластины и тип её текста.
	var plate_worn := 0
	var text_worn := 0
	for c in _walk(section):
		match String(c.theme_type_variation):
			"TooltipPanel":
				plate_worn += 1
			"TooltipLabel":
				text_worn += 1
	assert_bool(plate_worn >= 1).is_true() \
		.override_failure_message("в разделе §4.8 никто не надел TooltipPanel — пластина подсказки с кадра ушла")
	assert_bool(text_worn >= 1).is_true() \
		.override_failure_message("в разделе §4.8 никто не надел TooltipLabel — текст подсказки рисуется не каноном")


# T-227 (С-2): проверки «в исходниках нет обхода темы» и «несуществующий тип не
# резолвит» переехали в res://tests/unit/ui/test_theme_source_scan.gd (скан всего
# production-кода, а не «своих» файлов) и res://tests/unit/ui/test_theme_variation_matrix.gd
# (контракт от носителя: все 70 вариантов темы, а не три экрана, которым завели файл).
# Здесь остались только проверки, привязанные к этому экрану: что ТЕМА отдаёт ровно те
# значения, которые рисовал снятый override (AC2), и что живой узел экрана не получает
# переопределений в рантайме.

class_name ThemeCarrierGuard
extends RefCounted

## Общий предикат семейства гардов темы-носителя (test_*_theme_carrier.gd).
##
## Обход темы — три механизма (каноническое определение: docs/mvp/TICKETS.md,
## уточнение AC1 тикета T-147; docs/mvp/CAPTURE-HELPER.md):
##   1) add_theme_stylebox_override в .gd;
##   2) theme_override_styles/* в .tscn;
##   3) любой из двух во вложенной чужой сцене.
## Механизмы 1 и 2 ложатся в одно псевдосвойство узла theme_override_styles/<имя>
## — предикат проверяет их отсутствие по ЛЮБОМУ имени. Механизм 3 — правило
## области: каждый гард формулирует AC1 по исходникам экрана (.gd + .tscn),
## а не обходом дерева (обход не отличает чужую вложенную сцену от своей).
##
## «Резолвит носитель» — инстанс-идентичность (get_instance_id), а не равенство:
## носитель, указывающий на другой ресурс с теми же значениями, — это дельта.
## Прецедент: sub_resource-дубль id в game_theme.tres молча отдавал чужой ресурс
## (подсрез «армия», test_army_panel_theme_carrier.gd).

## Все локальные stylebox-переопределения узла (любое имя), «имя -> StyleBox».
## Механизмы 1 и 2 обхода темы видны здесь одинаково: и кодовый вызов, и
## сценевая запись ложатся в псевдосвойство theme_override_styles/<имя>.
## `allowed` — имена, не считающиеся обходом (документированный остаток; сейчас
## единственный — `focus` города, ждёт Q-M95, подсрез 4.8).
static func stylebox_overrides(node: Control, allowed: Array = []) -> Dictionary:
	var out := {}
	for p in node.get_property_list():
		var pname: String = p["name"]
		if not pname.begins_with("theme_override_styles/"):
			continue
		var value = node.get(pname)
		if value == null:
			continue  # свойство существует, но не задано (дефолт null)
		var item := pname.trim_prefix("theme_override_styles/")
		if allowed.has(item):
			continue
		out[item] = value
	return out

## Носитель резолвится: стиль узла непустой и это ресурс именно носителя
## (инстанс-идентичность). Ложь — если стиль пуст, носитель не описан в теме
## или узел резолвит что-то другое (дефолт типа, чужой ресурс).
static func resolves_carrier(node: Control, theme: Theme, style: String, carrier: String) -> bool:
	var got: StyleBox = node.get_theme_stylebox(style)
	if got == null:
		return false
	var declared: StyleBox = theme.get_stylebox(style, carrier)
	if declared == null:
		return false
	return got.get_instance_id() == declared.get_instance_id()

## Узел резолвит дефолтный стиль базового типа — носитель заявлен, но не
## применился (не тот base_type; без этой проверки «резолв совпал» было бы
## пустым, прецедент MinimapFrame, правило 8 docs/mvp/CAPTURE-HELPER.md).
## Ограничение (замерено 2026-07-06): работает, только если базовый тип имеет
## запись в теме (Panel, Button — да; PanelContainer — нет). У типа без записи
## и узел, и theme.get_stylebox дают встроенный дефолт движка, но РАЗНЫМИ
## инстансами — сравнение ложно и проверка пуста (текущий случай: гард
## артефактов, его защита — проверка резолва). Замечено в design.md.
static func falls_back_to_type_default(
	node: Control, theme: Theme, style: String, base_type: String
) -> bool:
	var got: StyleBox = node.get_theme_stylebox(style)
	if got == null:
		return false
	var fallback: StyleBox = theme.get_stylebox(style, base_type)
	if fallback == null:
		return false
	return got.get_instance_id() == fallback.get_instance_id()

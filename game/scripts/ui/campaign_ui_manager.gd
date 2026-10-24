class_name CampaignUIManager
extends Node

## mvp-ui-flow (K-M8): campaign-менеджер 8 экранов — проводка SM навигации
## (CampaignNavigation) к слоям-экранам. Дизайн mvp-ui-flow: «новый
## campaign_ui_manager.gd» (world_ui_manager — legacy hex, не campaign).
##
## Ответственность (headless-слой):
##   - show/hide экранов по решению SM (nav.request);
##   - инвариант «≤2 клика до причины» (3.3): can_show -> {available, reason};
##   - сигналы screen_changed / tutorial_requested для визуального слоя.
##
## Визуальный слой (.tscn с реальными экранами, раскладка) — отдельно
## (ux-review); здесь экраны — зарегистрированные Node (CanvasItem).

signal screen_changed(screen: StringName)
signal tutorial_requested(screen: StringName)

## SM навигации (модель). Порядок enum CampaignNavigation.Screen:
## PREGAME=0, MENU=1, MAP=2, CITY=3, BATTLE=4, PARTY=5, CHRONICLE=6, SETTINGS=7.
var nav: CampaignNavigation = CampaignNavigation.new()

## StringName -> узел экрана (CanvasItem). Регистрируется рантаймом.
var _screens: Dictionary = {}

## Имена экранов — в ПОРЯДКЕ enum CampaignNavigation.Screen (индекс = enum).
const SCREEN_NAMES: Array[StringName] = [
	&"pregame", &"menu", &"map", &"city",
	&"battle", &"party", &"chronicle", &"settings",
]


func _ready() -> void:
	nav.transitioned.connect(_on_transitioned)
	nav.tutorial_requested.connect(_on_tutorial_requested)
	# Все зарегистрированные экраны скрыты до первого show.
	for id in _screens:
		_set_visible(id, false)


## Зарегистрировать слой-экран (id из SCREEN_NAMES).
## Узел — `Node`, а не `CanvasItem`: хроника поселения (D-240) — `CanvasLayer`
## (у неё свой слой поверх HUD), и `CanvasItem`-тип отсек бы её на входе.
func register_screen(id: StringName, node: Node) -> void:
	_screens[id] = node
	_set_visible(id, false)


func has_screen(id: StringName) -> bool:
	return _screens.has(id)


## Текущий экран (StringName) по состоянию SM.
func current_screen() -> StringName:
	return _id_of(nav.current)


## Инвариант «≤2 клика до причины» (3.3): можно ли показать экран сейчас
## и почему. {available, reason} — reason пуст, если доступно.
func can_show(id: StringName) -> Dictionary:
	var to := _enum_of(id)
	if to < 0:
		return {"available": false, "reason": "unknown_screen"}
	if nav.current == to:
		return {"available": true, "reason": "current"}
	if nav.can_go(to):
		return {"available": true, "reason": ""}
	return {"available": false, "reason": "not_allowed_from_%s" % current_screen()}


## Показать экран (переход по SM). Возвращает {ok, reason, tutorial}.
## При успешном переходе — show/hide слоёв + screen_changed.
func show_screen(id: StringName) -> Dictionary:
	var to := _enum_of(id)
	if to < 0:
		return {"ok": false, "reason": "unknown_screen"}
	var result: Dictionary = nav.request(to)
	if not bool(result.get("ok", false)):
		return {"ok": false, "reason": str(result.get("reason", "not_allowed"))}
	_apply_current()
	return {"ok": true, "reason": "", "tutorial": bool(result.get("tutorial", false))}


## Видимы ли сейчас только текущий экран (инвариант одного активного экрана).
func visible_screens() -> Array:
	var out: Array = []
	for id in _screens:
		if _is_visible(_screens[id]):
			out.append(id)
	return out


## Кампания стартует на карте: машина начинается с PREGAME, а предигра
## (персонаж → подпись) отыграна до неё. Обходной путь, а не show_screen(&"map"):
## переход PREGAME→MENU→MAP выдал бы два туториала экранов (меню и карты),
## которых в кампании нет. Из кампейн-экранов не трогает ничего — повторный
## вход в кампанию не сбрасывает открытый экран. Туториал карты здесь не
## запрашивается: потребителя `tutorial_requested` у носителя ещё нет, запрос
## ушёл бы в никуда, а отметка «показан» уже сжгла бы единственный показ.
func begin_campaign() -> void:
	if nav.current != CampaignNavigation.Screen.PREGAME \
			and nav.current != CampaignNavigation.Screen.MENU:
		return
	nav.current = CampaignNavigation.Screen.MAP
	_apply_current()
	screen_changed.emit(current_screen())


func _apply_current() -> void:
	var cur := current_screen()
	for id in _screens:
		_set_visible(id, id == cur)


func _set_visible(id: StringName, visible: bool) -> void:
	var node: Node = _screens.get(id)
	if node is CanvasItem:
		(node as CanvasItem).visible = visible
	elif node is CanvasLayer:
		(node as CanvasLayer).visible = visible


## Видимость зарегистрированного слоя (у `CanvasItem` и `CanvasLayer` свой
## `visible`, общего интерфейса у них нет).
func _is_visible(node: Node) -> bool:
	if node is CanvasItem:
		return (node as CanvasItem).visible
	if node is CanvasLayer:
		return (node as CanvasLayer).visible
	return false


func _enum_of(id: StringName) -> int:
	return SCREEN_NAMES.find(id)  # порядок = enum; -1 если неизвестно


func _id_of(screen: int) -> StringName:
	if screen >= 0 and screen < SCREEN_NAMES.size():
		return SCREEN_NAMES[screen]
	return &""


func _on_transitioned(_from: int, _to: int) -> void:
	screen_changed.emit(current_screen())


func _on_tutorial_requested(screen: int) -> void:
	tutorial_requested.emit(_id_of(screen))

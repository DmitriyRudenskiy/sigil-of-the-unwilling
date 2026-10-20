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
func register_screen(id: StringName, node: CanvasItem) -> void:
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
		var node: Node = _screens[id]
		if node is CanvasItem and (node as CanvasItem).visible:
			out.append(id)
	return out


func _apply_current() -> void:
	var cur := current_screen()
	for id in _screens:
		_set_visible(id, id == cur)


func _set_visible(id: StringName, visible: bool) -> void:
	var node: Node = _screens.get(id)
	if node is CanvasItem:
		(node as CanvasItem).visible = visible


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

class_name CampaignNavigation
extends RefCounted

## mvp-ui-flow 2.1 (K-M8): SM навигации кампанийных экранов.
## Чистая логика (без сцены) — визуальный слой привязывается к request()/current
## и сигналам; headless-тестируемо (mvp-ui-flow 5.1).
##
## Канон: 07-ui-ux (8 экранов K-M8), mvp-ui-flow spec «Navigation state machine».
##   PREGAME → MENU → MAP → (CITY/BATTLE/PARTY/CHRONICLE/SETTINGS) → MAP.
##   BATTLE → MAP только («Продолжить», K-M8); MAP → CHRONICLE anytime;
##   * → TUTORIAL на первый вход в экран (1 раз).
## Инвариант: «закрыть в никуда» отсутствует — у каждого состояния есть выход.
## «Report» как экран аннулирован (результаты боя — финал боевого экрана).

signal transitioned(from: int, to: int)
signal tutorial_requested(screen: int)

enum Screen {
	PREGAME,
	MENU,
	MAP,
	CITY,
	BATTLE,
	PARTY,
	CHRONICLE,
	SETTINGS,
}

## Текущий экран SM.
var current: int = Screen.PREGAME

## Экраны, куда туториал уже показывался (screen -> true).
var _tutorial_shown: Dictionary = {}


## Разрешённые переходы из состояния (ориентированный граф; MAP — хаб).
func _allowed_from(from: int) -> Array:
	match from:
		Screen.PREGAME:
			return [Screen.MENU]
		Screen.MENU:
			return [Screen.MAP]
		Screen.MAP:
			return [
				Screen.CITY,
				Screen.BATTLE,
				Screen.PARTY,
				Screen.CHRONICLE,
				Screen.SETTINGS,
			]
		Screen.CITY, Screen.BATTLE, Screen.PARTY, Screen.CHRONICLE, Screen.SETTINGS:
			return [Screen.MAP]
		_:
			return []
	return []


## Можно ли перейти на экран сейчас.
func can_go(to: int) -> bool:
	return _allowed_from(current).has(to)


## Запрос перехода. Возвращает {ok, from, to, reason, tutorial}.
## При успешном переходе на экран, куда туториал ещё не показывался,
## эмитит tutorial_requested и помечает экран (гарантия «1 раз» — внутри SM).
func request(to: int) -> Dictionary:
	var from := current
	if not _allowed_from(from).has(to):
		return {"ok": false, "from": from, "to": to, "reason": "not_allowed", "tutorial": false}
	current = to
	transitioned.emit(from, to)
	var first_entry: bool = not _tutorial_shown.get(to, false)
	if first_entry:
		_tutorial_shown[to] = true
		tutorial_requested.emit(to)
	return {"ok": true, "from": from, "to": to, "reason": "", "tutorial": first_entry}


## Старт игры: туториал начального экрана (PREGAME) при первом входе.
## Возвращает true, если туториал нужен (и помечен).
func begin() -> bool:
	var first_entry: bool = not _tutorial_shown.get(current, false)
	if first_entry:
		_tutorial_shown[current] = true
		tutorial_requested.emit(current)
	return first_entry


## Нужен ли туториал для экрана (ещё не показывался).
func tutorial_needed(screen: int) -> bool:
	return not _tutorial_shown.get(screen, false)


## Пометить туториал экрана показанным (внешний вызов, напр. после закрытия оверлея).
func mark_tutorial_shown(screen: int) -> void:
	_tutorial_shown[screen] = true


## Инвариант «нет выхода в никуда»: у текущего состояния есть хотя бы один выход.
func has_exit() -> bool:
	return not _allowed_from(current).is_empty()


func to_dict() -> Dictionary:
	return {"current": current, "tutorial_shown": _tutorial_shown.duplicate(true)}


static func from_dict(data: Dictionary) -> CampaignNavigation:
	var nav := CampaignNavigation.new()
	nav.current = int(data.get("current", Screen.PREGAME))
	var shown: Variant = data.get("tutorial_shown", {})
	if shown is Dictionary:
		for k in shown:
			nav._tutorial_shown[int(k)] = bool(shown[k])
	return nav

class_name WorldClock
extends RefCounted
## T-010: каноническая модель времени кампании.
##
## Модель (владелец, round 7 §2.2; канон 02g K-M3 «ход = сезон»):
##   1 ход = 1 сезон, 4 хода = 1 год.
## Сезон: SPRING → SUMMER → AUTUMN → WINTER (класс Season), ход 1 = SPRING года 1.
##
## WorldClock — ЕДИНСТВЕННЫЙ источник числа хода в мире:
##   - TurnScheduler.execute_turn() — драйвер: 1 ход = 1 итерация конвейера фаз
##     (спецификация T-010: «Driver: 1 turn = 1 pipeline iteration»);
##   - WorldSeasons (климатическое давление) делегирует сюда свой счётчик.
##
## Серилизация (T-110): только базовое состояние (turn) — без производных;
## season/year — производные, пересчитываются при load.

static var _turn: int = 0


static func reset() -> void:
	_turn = 0


## Драйвер хода: 1 вызов = 1 ход (1 сезон). Возвращает номер завершённого хода.
static func advance_turn() -> int:
	_turn += 1
	return _turn


## Число завершённых ходов (0 = до первого хода).
static func get_turn() -> int:
	return _turn


static func set_turn(value: int) -> void:
	_turn = maxi(0, value)


## Сезон текущего хода (ход 1 = SPRING). До первого хода — SPRING (год 0).
static func season() -> Season.ID:
	if _turn <= 0:
		return Season.ID.SPRING
	match (_turn - 1) % 4:
		0:
			return Season.ID.SPRING
		1:
			return Season.ID.SUMMER
		2:
			return Season.ID.AUTUMN
		_:
			return Season.ID.WINTER


## Год (ход 1..4 = год 1; до первого хода = год 0).
static func year() -> int:
	if _turn <= 0:
		return 0
	return (_turn - 1) / 4 + 1


## T-110: сериализация — только базовое состояние (без производных).
static func serialize() -> Dictionary:
	return {"turn": _turn}


static func restore(data: Dictionary) -> void:
	_turn = maxi(0, int(data.get("turn", 0)))

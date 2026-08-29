class_name PopUnit
extends RefCounted
## Одна фигурка населения города (отображается как юнит, как в EL).
## Переключение состояний бесплатно, но требует полного хода:
## request_switch() переводит фигурку в pending (недоступна),
## apply_pending() применяется в конце текущего хода City.process_turn().

enum State { WORKER, FOLLOWER, MILITIA }

var uid := 0
var state: State = State.FOLLOWER
## Клетка, на которой работает рабочий (только для WORKER).
var tile := Vector2i(-1, -1)
## Патрулирует ли ополченец (только для MILITIA; +безопасность, без производства).
var patrol := false
## Отложенное переключение (-1 = нет) и его целевая клетка.
var pending_state: int = -1
var pending_tile := Vector2i(-1, -1)
## uid здания, за которым последователь закреплён (-1 = свободен).
var assigned_to := -1
## Ход (номер дня), в который фигурка родилась/прибыла.
var born_turn := -1
## Персонаж (M2: Демография), привязанный к фигурке (-1 = нет).
## Устанавливается CharacterRegistry.create(); сбрасывается при смерти.
var character_uid: int = -1


func is_available() -> bool:
	## Доступна ли фигурка для использования прямо сейчас.
	return pending_state == -1 and assigned_to == -1


func is_free_follower() -> bool:
	return state == State.FOLLOWER and is_available()


func request_switch(new_state: State, new_tile := Vector2i(-1, -1)) -> bool:
	## Ставит отложенное переключение. Возвращает false, если фигурка занята
	## (уже переключается или закреплена за зданием).
	if pending_state != -1 or assigned_to != -1:
		return false
	if new_state == State.WORKER and new_tile.x < 0:
		return false
	pending_state = new_state
	pending_tile = new_tile
	return true


func apply_pending() -> bool:
	## Вызывается City.process_turn() в конце хода. true — состояние изменилось.
	if pending_state == -1:
		return false
	state = pending_state
	tile = pending_tile if state == State.WORKER else Vector2i(-1, -1)
	patrol = patrol and state == State.MILITIA
	pending_state = -1
	pending_tile = Vector2i(-1, -1)
	return true

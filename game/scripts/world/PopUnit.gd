class_name PopUnit
extends RefCounted
## Одна фигурка населения города (отображается как юнит, как в EL).
## Переключение состояний бесплатно, но требует полного хода:
## request_switch() переводит фигурку в pending (недоступна),
## apply_pending() применяется в конце текущего хода City.process_turn().

enum State { WORKER, FOLLOWER, MILITIA, SCHOLAR }  # Спринт 6: +учёные

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


## ==================== СЕРИАЛИЗАЦИЯ (save v3) ====================
func serialize() -> Dictionary:
	return {
		"uid": uid,
		"state": state,
		"tile": {"x": tile.x, "y": tile.y},
		"patrol": patrol,
		"pending_state": pending_state,
		"pending_tile": {"x": pending_tile.x, "y": pending_tile.y},
		"assigned_to": assigned_to,
		"born_turn": born_turn,
		"character_uid": character_uid,
	}


static func deserialize(data: Dictionary) -> PopUnit:
	var u := PopUnit.new()
	u.uid = int(data.get("uid", 0))
	u.state = int(data.get("state", State.FOLLOWER))
	var t: Dictionary = data.get("tile", {})
	u.tile = Vector2i(int(t.get("x", -1)), int(t.get("y", -1)))
	u.patrol = bool(data.get("patrol", false))
	u.pending_state = int(data.get("pending_state", -1))
	var pt: Dictionary = data.get("pending_tile", {})
	u.pending_tile = Vector2i(int(pt.get("x", -1)), int(pt.get("y", -1)))
	u.assigned_to = int(data.get("assigned_to", -1))
	u.born_turn = int(data.get("born_turn", -1))
	u.character_uid = int(data.get("character_uid", -1))
	return u

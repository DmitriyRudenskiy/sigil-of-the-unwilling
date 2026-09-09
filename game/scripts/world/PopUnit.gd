class_name PopUnit
extends RefCounted

enum State { WORKER, FOLLOWER, MILITIA, SCHOLAR }

var uid := 0
var state: State = State.FOLLOWER
var tile := Vector2i(-1, -1)
var patrol := false
var pending_state: int = -1
var pending_tile := Vector2i(-1, -1)
var assigned_to := -1
var born_turn := -1
var character_uid: int = -1
var path_id: StringName = &""

func is_available() -> bool:
	return pending_state == -1 and assigned_to == -1

func is_free_follower() -> bool:
	return state == State.FOLLOWER and is_available()

func request_switch(new_state: State, new_tile := Vector2i(-1, -1)) -> bool:
	if pending_state != -1 or assigned_to != -1:
		return false
	if new_state == State.WORKER and new_tile.x < 0:
		return false
	pending_state = new_state
	pending_tile = new_tile
	return true

func apply_pending() -> bool:
	if pending_state == -1:
		return false
	state = pending_state
	tile = pending_tile if state == State.WORKER else Vector2i(-1, -1)
	patrol = patrol and state == State.MILITIA
	pending_state = -1
	pending_tile = Vector2i(-1, -1)
	return true

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
		"path_id": String(path_id),
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
	u.path_id = StringName(str(data.get("path_id", &"")))
	return u

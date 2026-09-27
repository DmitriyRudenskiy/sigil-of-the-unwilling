class_name GloryTracker
extends RefCounted

var _events: Array = []
var _window: int
var total := 0.0

func _init(window: int = GameNumbers.CITY_CYCLE_TURNS) -> void:
	_window = maxi(1, window)

func add_glory(amount: float, turn: int, reason: StringName = &"") -> void:
	if amount <= 0.0:
		return
	_events.append({"turn": turn, "amount": amount, "reason": reason})
	total += amount

func glory_last_window(current_turn: int) -> float:
	var total_ := 0.0
	var from_turn := current_turn - _window + 1
	for e in _events:
		if int(e.turn) >= from_turn:
			total_ += float(e.amount)
	return total_

func prune(current_turn: int) -> void:
	var cutoff := current_turn - _window
	_events = _events.filter(func(e): return int(e.turn) > cutoff)

## save-load-coverage-expansion 3.4: roundtrip через WorldStateDelta.glory_state.
func serialize() -> Dictionary:
	return {
		"events": _events.duplicate(true),
		"total": total,
		"window": _window,
	}

func deserialize(data: Dictionary) -> void:
	if data == null or data.is_empty():
		return
	var ev: Variant = data.get("events", [])
	_events = ev.duplicate(true) if ev is Array else []
	total = float(data.get("total", 0.0))
	_window = maxi(1, int(data.get("window", _window)))

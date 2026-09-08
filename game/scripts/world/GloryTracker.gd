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
	var total := 0.0
	var from_turn := current_turn - _window + 1
	for e in _events:
		if int(e.turn) >= from_turn:
			total += float(e.amount)
	return total


func prune(current_turn: int) -> void:
	var cutoff := current_turn - _window
	_events = _events.filter(func(e): return int(e.turn) > cutoff)

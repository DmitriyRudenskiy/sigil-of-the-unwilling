class_name GloryTracker
extends RefCounted
## Слава за скользящее окно в window ходов. События помечаются номером хода,
## которому они принадлежат; сумма берётся за [T - window + 1 .. T].

var _events: Array = []  # [{turn: int, amount: float, reason: StringName}]
var _window: int


func _init(window: int = CityBalance.CITY_CYCLE_TURNS) -> void:
	_window = maxi(1, window)


func add_glory(amount: float, turn: int, reason: StringName = &"") -> void:
	if amount <= 0.0:
		return
	_events.append({"turn": turn, "amount": amount, "reason": reason})


func glory_last_window(current_turn: int) -> float:
	var total := 0.0
	var from_turn := current_turn - _window + 1
	for e in _events:
		if int(e.turn) >= from_turn:
			total += float(e.amount)
	return total


func prune(current_turn: int) -> void:
	## Чистка событий, выпавших из окна. Вызывать в конце хода.
	var cutoff := current_turn - _window
	_events = _events.filter(func(e): return int(e.turn) > cutoff)

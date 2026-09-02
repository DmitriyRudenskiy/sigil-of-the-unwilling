extends RefCounted
class_name GameSession
## Single source of truth for run_seed and derived RNGs.

## endgame: состояние забега. Терминальные состояния липкие (sticky):
## один раз VICTORY/DEFEAT — навсегда (первая достигнутая причина wins).
enum GameState { RUNNING, VICTORY, DEFEAT }

var run_seed: int
var rng: RandomNumberGenerator
var state: GameState = GameState.RUNNING
var end_reason: String = ""
# endgame: счётчики для итогового отчёта (итог забега).
var battles_won := 0
var battles_lost := 0
var successions := 0


func _init(seed_value: int = -1) -> void:
	if seed_value < 0:
		run_seed = int(Time.get_unix_time_from_system()) & 0x7FFFFFFF
	else:
		run_seed = seed_value

	rng = RandomNumberGenerator.new()
	rng.seed = run_seed


## Derive a new seed by consuming the main RNG.
func next_seed() -> int:
	return rng.randi()


## Create a fresh RNG seeded from the main RNG (for independent subsystems).
func make_rng() -> RandomNumberGenerator:
	var child := RandomNumberGenerator.new()
	child.seed = next_seed()
	return child


func is_terminal() -> bool:
	return state != GameState.RUNNING


func serialize() -> Dictionary:
	return {
		"state": int(state),
		"end_reason": end_reason,
		"battles_won": battles_won,
		"battles_lost": battles_lost,
		"successions": successions,
	}


func deserialize(d: Dictionary) -> void:
	if d == null or d.is_empty():
		return
	# int → enum без вызова-конструктора (GDScript 4: enum не конструируется).
	var raw := int(d.get("state", int(GameState.RUNNING)))
	if raw == int(GameState.VICTORY):
		state = GameState.VICTORY
	elif raw == int(GameState.DEFEAT):
		state = GameState.DEFEAT
	else:
		state = GameState.RUNNING
	end_reason = str(d.get("end_reason", ""))
	battles_won = int(d.get("battles_won", 0))
	battles_lost = int(d.get("battles_lost", 0))
	successions = int(d.get("successions", 0))

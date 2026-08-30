extends RefCounted
class_name GameSession
## Single source of truth for run_seed and derived RNGs.

var run_seed: int
var rng: RandomNumberGenerator


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

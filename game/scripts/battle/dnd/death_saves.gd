class_name DNDDeathSaves

## D&D 5e Death Saving Throws
# When a creature drops to 0 HP it makes death saving throws.
#   - d20, no modifiers
#   - 10+ = success, 9- = failure
#   - natural 20 = regain 1 HP (immediately conscious)
#   - natural 1 = counts as two failures
#   - 3 successes = stable (unconscious, no more death saves)
#   - 3 failures = death
# Healing above 0 HP ends the death saves and wakes the creature.

enum State {
	HEALTHY,
	DYING,
	STABLE,
	DEAD
}

const MAX_SUCCESSES := 3
const MAX_FAILURES := 3

class DeathSaveResult:
	var d20: int = 0
	var new_state: State = State.DYING
	var regained_hp: bool = false
	var reason: String = ""


var state: State = State.HEALTHY
var successes: int = 0
var failures: int = 0


## Enter the dying state (HP reached 0).
func die_start() -> void:
	state = State.DYING
	successes = 0
	failures = 0


## Roll a death saving throw. Only valid while DYING.
func roll(rng: RandomNumberGenerator, p_d20: int = 0) -> DeathSaveResult:
	var r := DeathSaveResult.new()
	if state != State.DYING:
		r.new_state = state
		r.reason = "not dying"
		return r
	r.d20 = p_d20 if p_d20 > 0 else rng.randi_range(1, 20)

	if r.d20 == 20:
		# Regain 1 HP, wake up.
		r.new_state = State.HEALTHY
		r.regained_hp = true
		r.reason = "natural 20, regain 1 HP"
		state = State.HEALTHY
		successes = 0
		failures = 0
		return r

	if r.d20 == 1:
		failures += 2
	else:
		if r.d20 >= 10:
			successes += 1
		else:
			failures += 1

	if failures >= MAX_FAILURES:
		state = State.DEAD
		r.new_state = State.DEAD
		r.reason = "three failures, death"
	elif successes >= MAX_SUCCESSES:
		state = State.STABLE
		r.new_state = State.STABLE
		r.reason = "three successes, stable"
	else:
		r.new_state = State.DYING
		r.reason = "still dying"
	return r


## A Medicine check (or similar) stabilizes a dying creature.
func stabilize() -> void:
	if state == State.DYING:
		state = State.STABLE


## Healing above 0 HP ends death saves and wakes the creature.
func heal(p_amount: int) -> void:
	if p_amount <= 0:
		return
	if state == State.DYING or state == State.STABLE:
		state = State.HEALTHY
		successes = 0
		failures = 0


## True if the creature is stable (unconscious, out of immediate danger).
func is_stable() -> bool:
	return state == State.STABLE


## True if the creature is dead.
func is_dead() -> bool:
	return state == State.DEAD


## Serialize for save games.
func to_dict() -> Dictionary:
	return { "state": state, "successes": successes, "failures": failures }


## Deserialize from save data.
static func from_dict(data: Dictionary) -> DNDDeathSaves:
	var d = DNDDeathSaves.new()
	d.state = int(data.get("state", 0))
	d.successes = int(data.get("successes", 0))
	d.failures = int(data.get("failures", 0))
	return d

class_name BattleTrophyService
extends RefCounted
## scarce-crafting-system: трофеи боя → стратегическое сырьё.
## Победа в бою даёт герою 1–3 единицы редкого ресурса (детерминированно
## по seed). Единственный «не-узел» источник редких ресурсов.

const TROPHY_RESOURCES: Array[StringName] = [
	&"silver", &"turquoise", &"gold_ore", &"cinnabar", &"quartz",
]
const MIN_UNITS := 1
const MAX_UNITS := 3

static var _rng := RandomNumberGenerator.new()

static func set_rng(rng: RandomNumberGenerator) -> void:
	_rng = rng


## Выбор трофея: {resource: StringName, amount: int}. Детерминированно по seed.
static func roll_trophy() -> Dictionary:
	var res: StringName = TROPHY_RESOURCES[_rng.randi_range(0, TROPHY_RESOURCES.size() - 1)]
	var amount: int = _rng.randi_range(MIN_UNITS, MAX_UNITS)
	return {"resource": res, "amount": amount}

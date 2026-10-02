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

static var _roll_counter := 0


## Сброс последовательности (только для тестов).
static func reset_for_tests() -> void:
	_roll_counter = 0


## Выбор трофея: {resource: StringName, amount: int}.
## T17/D2: детерминированно (без ГСЧ) — фиксированная последовательность
## от счётчика бросков сессии.
static func roll_trophy() -> Dictionary:
	_roll_counter += 1
	var res: StringName = TROPHY_RESOURCES[absi(hash(_roll_counter)) % TROPHY_RESOURCES.size()]
	var amount: int = MIN_UNITS + absi(hash(_roll_counter * 3)) % (MAX_UNITS - MIN_UNITS + 1)
	return {"resource": res, "amount": amount}

class_name FactionReputation
extends RefCounted

const HeroFactions = preload("res://scripts/data/hero_factions.gd")
## quests-reputation-system: репутация героя с 6 фракциями (−100..+100).
## State: Dictionary {faction_id: int}. История: Array["<faction>|<delta>|<reason>"], последние 20.

const MIN := -100
const MAX := 100
const HISTORY_LIMIT := 20

enum Band {
	ENEMY = 0,    # −100..−50
	HOSTILE = 1,  # −49..−10
	NEUTRAL = 2,  # −9..+9
	FRIENDLY = 3, # +10..+49
	ALLY = 4,     # +50..+100
}

## Цены: Союзник −20%, Друг −10%, Нейтрал ×1.0, Недруг +25%, Враг +50%
const PRICE_MULT: Array[float] = [1.5, 1.25, 1.0, 0.9, 0.8]

static func band(value: int) -> int:
	if value <= -50:
		return Band.ENEMY
	if value <= -10:
		return Band.HOSTILE
	if value >= 50:
		return Band.ALLY
	if value >= 10:
		return Band.FRIENDLY
	return Band.NEUTRAL

static func band_name(value: int) -> String:
	match band(value):
		Band.ENEMY: return "Враг"
		Band.HOSTILE: return "Недруг"
		Band.FRIENDLY: return "Друг"
		Band.ALLY: return "Союзник"
	return "Нейтрал"

static func price_multiplier(value: int) -> float:
	return PRICE_MULT[band(value)]

## Найм юнитов фракции доступен с уровня Друг (+10)
static func can_hire(value: int) -> bool:
	return value >= 10

## Начальное состояние: 0 везде, +10 с родной расой, +5 религиозным классам.
## priest — жрец, paladin — паладин: бонус к фракции godlike.
static func initial_state(race: String, class_id: String) -> Dictionary:
	var state := {}
	for id: String in HeroFactions.FACTIONS:
		state[id] = 0
	if race != "" and state.has(race):
		state[race] = 10
	if class_id == "priest" or class_id == "paladin":
		state["godlike"] = int(state["godlike"]) + 5
	return state

## Применение дельты с расовым бонусом (+10% к приросту за родную фракцию).
## Возвращает новое значение.
static func apply(state: Dictionary, faction_id: String, delta: int, race: String = "") -> int:
	var d := float(delta)
	if race != "" and faction_id == race and d > 0.0:
		d *= 1.1
	var v: int = int(state.get(faction_id, 0)) + int(roundf(d))
	state[faction_id] = clampi(v, MIN, MAX)
	return int(state[faction_id])

## История изменений: push "<faction>|<delta>|<reason>", максимум 20 записей.
static func log(history: Array, faction_id: String, delta: int, reason: String) -> void:
	history.push_back("%s|%d|%s" % [faction_id, delta, reason])
	while history.size() > HISTORY_LIMIT:
		history.pop_front()

## События репутации (spec: События изменения репутации).
const EVENT_DELTAS := {
	"quest_done": 20,        # +10..+30 по сложности — берём среднее
	"quest_failed": -10,
	"escort_dead": -20,
	"combat_help": 10,       # +5..+15 — среднее
	"attack_faction": -20,
	"trade": 2,
}

static func event_delta(event: String) -> int:
	return int(EVENT_DELTAS.get(event, 0))

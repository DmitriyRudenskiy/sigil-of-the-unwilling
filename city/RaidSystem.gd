class_name RaidSystem
extends RefCounted
## Спринт 10: Рейды варваров. Каждый ход у города есть шанс стать целью
## рейда (чем ниже репутация — тем выше). Сила рейда определяется
## детерминированно от (uid, turn) — headless-тестируемо без RNG.
##
## Оборона = City.defense_strength(): ополчение × DEFENSE_PER_MILITIA
## + стены (level × DEFENSE_PER_WALL за здание).
##
## Отбит рейд: репутация +REP_RELIEF. Прорван: грабёж RAID_PILLAGE_FRACTION
## складов, репутация -REP_LOSS.
##
## Статический класс, без autoload. Сигнал эмитит CityTurnProcessor
## (raid_occurred), WorldBootstrap пробрасывает в GameEventBus.

const RAID_CHANCE_BASE := 0.10
const RAID_CHANCE_MIN := 0.02
const RAID_CHANCE_MAX := 0.30
## Репутация сдвигает шанс: chance = clamp(base - rep/500, min, max).
const REP_CHANCE_DIVISOR := 500.0

const DEFENSE_PER_MILITIA := 2
const DEFENSE_PER_WALL := 5

const RAID_STRENGTH_MIN := 5
const RAID_STRENGTH_SPAN := 11  # сила = MIN + (hash % SPAN) => 5..15

const REP_RELIEF := 5
const REP_LOSS := -10
const RAID_PILLAGE_FRACTION := 0.30
## Ресурсы resource_ctx, подвергающиеся грабежу (кроме еды и золота).
const PILLAGED_RESOURCES: Array[StringName] = [&"grain", &"flour", &"bread",
	&"ore", &"tools", &"dust", &"science", &"influence"]


## Шанс рейда при текущей репутации.
static func chance(city: City) -> float:
	return clampf(RAID_CHANCE_BASE - float(city.reputation) / REP_CHANCE_DIVISOR,
		RAID_CHANCE_MIN, RAID_CHANCE_MAX)


## Детерминированный бросок 0..1 от (uid, turn).
static func roll_value(city: City, turn: int) -> float:
	var h := hash([city.uid, turn, 0x5EA1D])
	return fmod(float(absi(h)), 10000.0) / 10000.0


## Происходит ли рейд на этом ходу.
static func occurs(city: City, turn: int) -> bool:
	return roll_value(city, turn) < chance(city)


## Сила рейда (детерминированная).
static func raid_strength(city: City, turn: int) -> int:
	var h := hash([city.uid, turn, 0x5E25D])
	return RAID_STRENGTH_MIN + absi(h) % RAID_STRENGTH_SPAN


## Разрешить рейд за ход. Возвращает
## {occurred, strength, defense, repelled, pillaged_food, pillaged_gold}.
## Мутации: food_stockpile, storage, репутация (только если occurred).
static func resolve(city: City, turn: int) -> Dictionary:
	if not occurs(city, turn):
		return {"occurred": false, "strength": 0, "defense": 0,
			"repelled": false, "pillaged_food": 0.0, "pillaged_gold": 0.0}

	var strength := raid_strength(city, turn)
	var defense := city.defense_strength()
	var repelled := defense >= strength

	if repelled:
		ReputationSystem.apply(city, float(REP_RELIEF))
		return {"occurred": true, "strength": strength, "defense": defense,
			"repelled": true, "pillaged_food": 0.0, "pillaged_gold": 0.0}

	# Прорван: грабёж складов.
	var food := city.food_stockpile * RAID_PILLAGE_FRACTION
	city.food_stockpile -= food
	var gold := float(city.storage.get(&"industry", 0.0)) * RAID_PILLAGE_FRACTION
	city.storage[&"industry"] = float(city.storage.get(&"industry", 0.0)) - gold
	var res := city.ensure_resource_ctx()
	for rid in PILLAGED_RESOURCES:
		if res.has(rid):
			res.remove(rid, float(res.amount(rid)) * RAID_PILLAGE_FRACTION)
	ReputationSystem.apply(city, float(REP_LOSS))
	return {"occurred": true, "strength": strength, "defense": defense,
		"repelled": false, "pillaged_food": food, "pillaged_gold": gold}

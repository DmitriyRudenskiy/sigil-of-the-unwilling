class_name RaidSystem
extends RefCounted

const PILLAGED_RESOURCES: Array[StringName] = [&"grain", &"flour", &"bread",
	&"ore", &"tools", &"dust", &"science", &"influence"]

static func chance(city: City) -> float:
	return clampf(GameNumbers.RAID_CHANCE_BASE - float(city.reputation) / GameNumbers.RAID_REP_DIVISOR,
		GameNumbers.RAID_CHANCE_MIN, GameNumbers.RAID_CHANCE_MAX)

static func roll_value(city: City, turn: int) -> float:
	var h := hash([city.uid, turn, 0x5EA1D])
	return fmod(float(absi(h)), 10000.0) / 10000.0

static func occurs(city: City, turn: int) -> bool:
	return roll_value(city, turn) < chance(city)

static func raid_strength(city: City, turn: int) -> int:
	var h := hash([city.uid, turn, 0x5E25D])
	return GameNumbers.RAID_STRENGTH_MIN + absi(h) % GameNumbers.RAID_STRENGTH_SPAN

static func resolve(city: City, turn: int) -> Dictionary:
	if not occurs(city, turn):
		return {"occurred": false, "strength": 0, "defense": 0,
			"repelled": false, "pillaged_food": 0.0, "pillaged_gold": 0.0}

	var strength := raid_strength(city, turn)
	var defense := city.defense_strength()
	var repelled := defense >= strength

	if repelled:
		ReputationSystem.apply(city, float(GameNumbers.RAID_REP_RELIEF))
		return {"occurred": true, "strength": strength, "defense": defense,
			"repelled": true, "pillaged_food": 0.0, "pillaged_gold": 0.0}

	var food := city.food_stockpile * GameNumbers.RAID_PILLAGE_FRACTION
	city.food_stockpile -= food
	var gold := float(city.storage.get(&"industry", 0.0)) * GameNumbers.RAID_PILLAGE_FRACTION
	city.storage[&"industry"] = float(city.storage.get(&"industry", 0.0)) - gold
	var res := city.ensure_resource_ctx()
	for rid in PILLAGED_RESOURCES:
		if res.has(rid):
			res.remove(rid, float(res.amount(rid)) * GameNumbers.RAID_PILLAGE_FRACTION)
	ReputationSystem.apply(city, float(GameNumbers.RAID_REP_LOSS))
	return {"occurred": true, "strength": strength, "defense": defense,
		"repelled": false, "pillaged_food": food, "pillaged_gold": gold}

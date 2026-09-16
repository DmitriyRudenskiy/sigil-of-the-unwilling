class_name ReputationSystem
extends RefCounted

const LeadershipCheck = preload("res://scripts/systems/LeadershipCheck.gd")

enum Band {
	REBELLION = 0,
	CRISIS = 1,
	DISCONTENT = 2,
	NORMAL = 3,
	PROSPERITY = 4,
	GOLDEN_AGE = 5,
}

static func band(value: int) -> int:
	if value >= GameNumbers.REP_BAND_GOLDEN_AGE:
		return Band.GOLDEN_AGE
	if value >= GameNumbers.REP_BAND_PROSPERITY:
		return Band.PROSPERITY
	if value >= 0:
		return Band.NORMAL
	if value >= GameNumbers.REP_BAND_DISCONTENT:
		return Band.DISCONTENT
	if value >= GameNumbers.REP_BAND_CRISIS:
		return Band.CRISIS
	return Band.REBELLION

static func band_name(value: int) -> String:
	return GameText.rep_band(band(value))

static func clamp_value(v: int) -> int:
	return clampi(v, GameNumbers.REP_MIN, GameNumbers.REP_MAX)

static func turn_factor(city: City) -> int:
	var f := 0
	if city.net_food() > 0.0:
		f += GameNumbers.REP_FOOD_SURPLUS
	if city.starving:
		f += GameNumbers.REP_STARVING
	f += GameNumbers.REP_OVERPOP_PER * city.over_limit()
	f += AdjacencySystem.reputation_bonus(city)
	return f

static func apply(city: City, delta: float) -> int:
	city.reputation = clamp_value(int(city.reputation) + int(roundf(delta)))
	return city.reputation

static func process_turn(city: City) -> int:
	return apply(city, turn_factor(city))

## cha — харизма героя, находящегося в городе (-1 = героя нет)
static var _rng := RandomNumberGenerator.new()
static func process_migration(city: City, cha: int = -1) -> Dictionary:
	var immigrants := 0
	var emigrants := 0
	var cha_mod: float = LeadershipCheck.immigration_modifier(cha) if cha >= 0 else 1.0
	if city.reputation >= GameNumbers.MIGRATE_IN_AT:
		if city.pop_capped() < city.pop_cap():
			var st: int = city.immigrant_state()
			if st >= 0:
				city.add_migrant(st)
				immigrants = GameNumbers.MIGRATE_IN_PER_TURN
				# множитель иммиграции: 50% шанс доп. иммигранта
				if cha_mod > 1.0 and _rng.chancei(int(cha_mod * 100.0)) < 100:
					city.add_migrant(st)
					immigrants += 1
	elif city.reputation <= GameNumbers.MIGRATE_OUT_AT:
		# cha <= 5: доп. отток +1 (недовольство правителем)
		if cha >= 0 and cha <= GameNumbers.SOCIAL_ATTRITION_CHA:
			if _emigrate_one(city):
				emigrants += 1

	if city.reputation <= GameNumbers.MIGRATE_OUT_AT:
		var per: int = GameNumbers.MIGRATE_CRISIS_PER_TURN \
			if city.reputation <= GameNumbers.MIGRATE_CRISIS_AT \
			else 1
		for i in per:
			if _emigrate_one(city):
				emigrants += 1
	if immigrants > 0 or emigrants > 0:
		city.population_changed.emit()
	return {"immigrants": immigrants, "emigrants": emigrants}

static func _emigrate_one(city: City) -> bool:
	var order: Array = [
		PopUnit.State.SCHOLAR,
		PopUnit.State.MILITIA,
		PopUnit.State.WORKER,
		PopUnit.State.FOLLOWER,
	]
	for st in order:
		for u in city.pop:
			if u.state == st and u.character_uid == -1:
				city.remove_pop(u.uid)
				return true
	return false

class_name CityEvents
extends RefCounted

const CHANCE := 0.08

const POOL: Array[Dictionary] = [
	{
		"id": &"harvest_festival",
		"text": "Жатвенный праздник: +5 еды, +3 репутации.",
		"food": 5.0,
		"rep": 3,
	},
	{
		"id": &"merchant_caravan",
		"text": "Караван купцов: +10 золота.",
		"gold": 10.0,
	},
	{
		"id": &"plague_outbreak",
		"text": "Эпидемия: -1 население, -5 репутации.",
		"pop_loss": 1,
		"rep": -5,
	},
	{
		"id": &"scholar_visit",
		"text": "Визит учёного: +5 науки, +2 репутации.",
		"science": 5.0,
		"rep": 2,
	},
	{
		"id": &"tax_inspector",
		"text": "Сборщик дани: -5 золота.",
		"gold": -5.0,
	},
]

static func roll_value(city: City, turn: int) -> float:
	var h := hash([city.uid, turn, 0x5EE1])
	return fmod(float(absi(h)), 10000.0) / 10000.0

static func occurs(city: City, turn: int) -> bool:
	return roll_value(city, turn) < CHANCE

static func pick_index(city: City, turn: int) -> int:
	var h := hash([city.uid, turn, 0x5EE2])
	return absi(h) % POOL.size()

static func resolve(city: City, turn: int) -> Dictionary:
	if not occurs(city, turn):
		return {"occurred": false, "event_id": &"", "text": ""}

	var evt: Dictionary = POOL[pick_index(city, turn)]
	if float(evt.get("food", 0.0)) != 0.0:
		city.food_stockpile = maxf(0.0, city.food_stockpile + float(evt.food))
	if float(evt.get("gold", 0.0)) != 0.0:
		city.storage[&"industry"] = maxf(0.0, float(city.storage.get(&"industry", 0.0))
			+ float(evt.gold))
	if float(evt.get("science", 0.0)) > 0.0:
		city.ensure_resource_ctx().add(&"science", float(evt.science))
	if int(evt.get("pop_loss", 0)) > 0 and city.pop.size() > 0:
		city.remove_pop(city.pop[city.pop.size() - 1].uid)
	if int(evt.get("rep", 0)) != 0:
		ReputationSystem.apply(city, int(evt.rep))
	return {
		"occurred": true,
		"event_id": evt.id,
		"text": evt.text,
	}

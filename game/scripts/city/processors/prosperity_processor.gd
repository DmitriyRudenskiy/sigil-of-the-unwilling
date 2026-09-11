class_name ProsperityProcessor
extends CitySubProcessor
## Prosperity recalculation, gold bonus, reputation modifier.


func get_id() -> StringName:
	return &"prosperity"


func process(city: City, _turn: int, report: Dictionary) -> void:
	var prosperity: float = ProsperitySystem.recalculate(city)
	var gold_bonus: float = ProsperitySystem.gold_bonus(city)
	if gold_bonus > 0.0:
		city.storage[&"industry"] = float(city.storage.get(&"industry", 0.0)) + gold_bonus
	var rep_mod: int = ProsperitySystem.reputation_mod(city)
	if rep_mod != 0:
		ReputationSystem.apply(city, float(rep_mod))
	report["prosperity"] = prosperity
	report["gold_bonus"] = gold_bonus

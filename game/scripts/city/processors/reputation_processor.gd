class_name ReputationProcessor
extends CitySubProcessor
## Reputation turn processing.

signal reputation_changed(city_uid: int, value: int, band: int)


func get_id() -> StringName:
	return &"reputation"


func process(city: City, _turn: int, report: Dictionary) -> void:
	var rep_before: int = city.reputation
	ReputationSystem.process_turn(city)
	if city.reputation != rep_before:
		report["rep_delta"] = city.reputation - rep_before
		reputation_changed.emit(city.uid, city.reputation, city.reputation_band())

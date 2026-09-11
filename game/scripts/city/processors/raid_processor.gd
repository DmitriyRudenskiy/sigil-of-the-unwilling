class_name RaidProcessor
extends CitySubProcessor
## Raid resolution.

signal raid_occurred(city_uid: int, repelled: bool)


func get_id() -> StringName:
	return &"raid"


func process(city: City, turn: int, report: Dictionary) -> void:
	var raid: Dictionary = RaidSystem.resolve(city, turn)
	if bool(raid.occurred):
		report["raid_occurred"] = 1
		report["raid_repelled"] = bool(raid.repelled)
		report["raid_strength"] = int(raid.strength)
		raid_occurred.emit(city.uid, bool(raid.repelled))

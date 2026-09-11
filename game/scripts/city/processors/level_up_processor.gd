class_name LevelUpProcessor
extends CitySubProcessor
## City level-up attempts (driven by prosperity).

signal city_level_up(city_uid: int, new_level: int)


func get_id() -> StringName:
	return &"level_up"


func process(city: City, _turn: int, report: Dictionary) -> void:
	if ProsperitySystem.try_level_up(city):
		report["level_up"] = city.level
		city_level_up.emit(city.uid, city.level)

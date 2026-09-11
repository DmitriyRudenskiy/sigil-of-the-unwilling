class_name ScienceProcessor
extends CitySubProcessor
## Science income from specialization.


func get_id() -> StringName:
	return &"science"


func process(city: City, _turn: int, _report: Dictionary) -> void:
	var sci: float = SpecializationSystem.science_per_turn(city)
	if sci > 0.0:
		city.ensure_resource_ctx().add(&"science", sci)

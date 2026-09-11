class_name CitySubProcessor
extends RefCounted
## Base class for city turn sub-processors (see CityTurnProcessor).
## Each sub-processor handles one subsystem of the city turn and writes
## its results into the shared `report` dictionary. Signals for its
## effects are declared here and forwarded by CityTurnProcessor.


func get_id() -> StringName:
	return &""


func process(_city: City, _turn: int, _report: Dictionary) -> void:
	pass

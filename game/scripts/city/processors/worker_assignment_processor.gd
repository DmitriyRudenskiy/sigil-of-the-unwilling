class_name WorkerAssignmentProcessor
extends CitySubProcessor
## Worker rebalancing across buildings.

signal worker_assignment_changed(city_uid: int, assigned: int)


func get_id() -> StringName:
	return &"worker_assignment"


func process(city: City, _turn: int, report: Dictionary) -> void:
	var assigned: int = WorkerAssignment.rebalance(city)
	if assigned > 0:
		report["workers_assigned"] = assigned
		worker_assignment_changed.emit(city.uid, assigned)

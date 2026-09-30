
class_name NeedStrategy
extends RefCounted

var decay_rate: float

func _init(p_decay: float) -> void:
	decay_rate = p_decay

func get_recovery_hero(_in_city: bool, _city: City) -> float:
	return 0.0

func get_recovery_pop(_city: City, _pop: PopUnit) -> float:
	return 0.0

func get_death_cause() -> StringName:
	return &""

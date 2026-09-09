
class_name NeedStrategy
extends RefCounted

var decay_rate: float

func _init(p_decay: float) -> void:
	decay_rate = p_decay

func get_recovery_hero(in_city: bool, city: City) -> float:
	return 0.0

func get_recovery_pop(city: City, pop: PopUnit) -> float:
	return 0.0

func get_death_cause() -> StringName:
	return &""

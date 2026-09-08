class_name RestStrategy
extends NeedStrategy

func _init() -> void:
	super._init(GameNumbers.NEED_REST_DECAY)

func get_recovery_hero(in_city: bool, city: City) -> float:
	return GameNumbers.NEED_REST_RECOVERY_CITY if in_city else 0.0

func get_recovery_pop(city: City, pop: PopUnit) -> float:
	if pop != null and pop.state == PopUnit.State.MILITIA:
		return 0.0
	return GameNumbers.NEED_REST_RECOVERY_POP

func get_death_cause() -> StringName:
	return &"exhaustion"

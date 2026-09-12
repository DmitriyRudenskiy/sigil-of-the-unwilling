class_name InspirationStrategy
extends NeedStrategy

func _init() -> void:
	super._init(GameNumbers.NEED_INSP_DECAY)

func get_recovery_hero(in_city: bool, _city: City) -> float:
	return GameNumbers.NEED_INSP_RECOVERY_CITY if in_city else 0.0

func get_recovery_pop(_city: City, _pop: PopUnit) -> float:
	return GameNumbers.NEED_INSP_RECOVERY_POP

func get_death_cause() -> StringName:
	return &"burnout"

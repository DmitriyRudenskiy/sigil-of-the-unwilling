class_name SocialStrategy
extends NeedStrategy

func _init() -> void:
	super._init(GameNumbers.NEED_SOCIAL_DECAY)

func get_recovery_hero(in_city: bool, city: City) -> float:
	if in_city and city != null and city.pop.size() >= 3:
		return GameNumbers.NEED_SOCIAL_RECOVERY_CITY
	return GameNumbers.NEED_SOCIAL_RECOVERY_LOW

func get_recovery_pop(city: City, pop: PopUnit) -> float:
	if city != null and city.pop.size() >= 3:
		return GameNumbers.NEED_SOCIAL_RECOVERY_POP
	return GameNumbers.NEED_SOCIAL_RECOVERY_LOW

func get_death_cause() -> StringName:
	return &"isolation"

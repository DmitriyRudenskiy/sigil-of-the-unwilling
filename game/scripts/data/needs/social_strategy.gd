class_name SocialStrategy
extends NeedStrategy

func _init() -> void:
	super._init(GameNumbers.NEED_SOCIAL_DECAY)

func get_recovery_hero(in_city: bool, city: City) -> float:
	# В городе с населением (pop >= 3) — CITY; вне города и в пустом — LOW
	# (LOW ≈ decay: спад −0.01/ход, герой без города доживает ~100 ходов —
	# balance-core: смерть от изоляции на 9-м ходу была несправедливой).
	if in_city and city != null and city.pop.size() >= 3:
		return GameNumbers.NEED_SOCIAL_RECOVERY_CITY
	return GameNumbers.NEED_SOCIAL_RECOVERY_LOW

func get_recovery_pop(city: City, pop: PopUnit) -> float:
	if city != null and city.pop.size() >= 3:
		return GameNumbers.NEED_SOCIAL_RECOVERY_POP
	return GameNumbers.NEED_SOCIAL_RECOVERY_LOW

func get_death_cause() -> StringName:
	return &"isolation"

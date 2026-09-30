class_name InspirationStrategy
extends NeedStrategy

func _init() -> void:
	super._init(GameNumbers.NEED_INSP_DECAY)

func get_recovery_hero(in_city: bool, _city: City) -> float:
	# Вне города — LOW ≈ decay (см. RestStrategy): спад −0.01/ход, герой без
	# города доживает ~100 ходов, а не ~20 (balance-core: ранние DEFEAT).
	return GameNumbers.NEED_INSP_RECOVERY_CITY if in_city \
		else GameNumbers.NEED_INSP_RECOVERY_LOW

func get_recovery_pop(_city: City, _pop: PopUnit) -> float:
	return GameNumbers.NEED_INSP_RECOVERY_POP

func get_death_cause() -> StringName:
	return &"burnout"

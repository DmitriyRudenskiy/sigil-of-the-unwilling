class_name RestStrategy
extends NeedStrategy

func _init() -> void:
	super._init(GameNumbers.NEED_REST_DECAY)

func get_recovery_hero(in_city: bool, _city: City) -> float:
	# Вне города герой «отдыхает в походе» (LOW ≈ decay): чистый спад −0.01/
	# ход — герой без города умирает от истощения ~на 100-м ходу, а не на
	# 12-м (balance-core: несправедливое раннее DEFEAT). В городе — полный
	# реквери (CITY) по исходному дизайну.
	return GameNumbers.NEED_REST_RECOVERY_CITY if in_city \
		else GameNumbers.NEED_REST_RECOVERY_LOW

func get_recovery_pop(_city: City, pop: PopUnit) -> float:
	if pop != null and pop.state == PopUnit.State.MILITIA:
		return 0.0
	return GameNumbers.NEED_REST_RECOVERY_POP

func get_death_cause() -> StringName:
	return &"exhaustion"

class_name ScaleShiftManager
extends RefCounted

const TIER_NAMES := ["Селение", "Деревня", "Город", "Метрополия"]


static func tier_for(pop_capped: int) -> int:
	var t := 3
	for i in GameNumbers.SCALE_TIERS.size():
		if pop_capped <= GameNumbers.SCALE_TIERS[i]:
			t = i
			break
	return t


static func tier_name(tier: int) -> String:
	return TIER_NAMES[clampi(tier, 0, TIER_NAMES.size() - 1)]


static func storage_multiplier(tier: int) -> float:
	return GameNumbers.SCALE_STORAGE_MULT[clampi(tier, 0, GameNumbers.SCALE_STORAGE_MULT.size() - 1)]


static func auto_resource_multiplier(tier: int) -> float:
	return GameNumbers.SCALE_AUTO_MULT[clampi(tier, 0, GameNumbers.SCALE_AUTO_MULT.size() - 1)]


static func upkeep_multiplier(tier: int) -> float:
	return GameNumbers.SCALE_UPKEEP_MULT[clampi(tier, 0, GameNumbers.SCALE_UPKEEP_MULT.size() - 1)]

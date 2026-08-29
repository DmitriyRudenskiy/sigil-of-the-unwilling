class_name ScaleShiftManager
extends RefCounted
## M3: Масштабный сдвиг города. Город растёт масштабами (селение → деревня
## → город → метрополия) по числу жителей (pop_capped). Каждый масштаб
## даёт бонусы: ёмкость хранилищ, авто-ресурсы, скидка поддержки.
##
## Пороги согласованы с POP_CAP_BY_STRONGHOLD (максимум 35): верхний
## масштаб достижим только у сильных крепостей.

## Границы по pop_capped: [0..3] = 4-й масштаб начинается с 30.
const TIER_UPPER_BOUNDS := [4, 14, 29]  # tier 0: <=4, tier 1: <=14, tier 2: <=29, tier 3: >=30
const TIER_NAMES := ["Селение", "Деревня", "Город", "Метрополия"]
const STORAGE_MULT := [1.0, 1.25, 1.5, 2.0]      # ёмкость хранилищ resource_ctx
const AUTO_RESOURCE_MULT := [1.0, 1.1, 1.2, 1.4] # дрова/камень в день
const UPKEEP_MULT := [1.0, 0.95, 0.9, 0.85]      # стоимость поддержки


## Масштаб по числу жителей (pop_capped).
static func tier_for(pop_capped: int) -> int:
	var t := 3
	for i in TIER_UPPER_BOUNDS.size():
		if pop_capped <= TIER_UPPER_BOUNDS[i]:
			t = i
			break
	return t


static func tier_name(tier: int) -> String:
	return TIER_NAMES[clampi(tier, 0, TIER_NAMES.size() - 1)]


static func storage_multiplier(tier: int) -> float:
	return STORAGE_MULT[clampi(tier, 0, STORAGE_MULT.size() - 1)]


static func auto_resource_multiplier(tier: int) -> float:
	return AUTO_RESOURCE_MULT[clampi(tier, 0, AUTO_RESOURCE_MULT.size() - 1)]


static func upkeep_multiplier(tier: int) -> float:
	return UPKEEP_MULT[clampi(tier, 0, UPKEEP_MULT.size() - 1)]

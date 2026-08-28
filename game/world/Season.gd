class_name Season
extends RefCounted
## Сезоны по номеру месяца (1..12) и модификаторы циклического притока.

enum ID { SPRING, SUMMER, AUTUMN, WINTER }

static func from_month(month: int) -> ID:
	if month <= 0 or month > 12:
		push_warning("Season: некорректный месяц %d, считаем весной" % month)
		return ID.SPRING
	if month <= 2 or month == 12:
		return ID.WINTER
	if month <= 5:
		return ID.SPRING
	if month <= 8:
		return ID.SUMMER
	return ID.AUTUMN

static func growth_modifier(s: ID) -> float:
	match s:
		ID.WINTER:
			return CityBalance.INFLOW_WINTER_MOD
		ID.SUMMER:
			return CityBalance.INFLOW_SUMMER_MOD
		_:
			return CityBalance.INFLOW_SPRING_AUTUMN_MOD

class_name Season
extends RefCounted

enum ID { SPRING, SUMMER, AUTUMN, WINTER }

static func from_month(month: int) -> ID:
	if month <= 0 or month > 12:
		push_warning("Season: invalid month %d, treating as spring" % month)
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
			return GameNumbers.INFLOW_WINTER_MOD
		ID.SUMMER:
			return GameNumbers.INFLOW_SUMMER_MOD
		_:
			return GameNumbers.INFLOW_SPRING_AUTUMN_MOD

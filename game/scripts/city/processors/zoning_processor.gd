class_name ZoningProcessor
extends CitySubProcessor
## Zone multipliers for buildings + zone violation checks.

signal zone_violation(city_uid: int, cell: Vector2i)


func get_id() -> StringName:
	return &"zoning"


func process(city: City, _turn: int, report: Dictionary) -> void:
	for building in city.buildings:
		if building == null:
			continue
		if building.zone_type == ZoningSystem.ZoneType.NONE:
			building.zone_multiplier = 1.0
		else:
			building.zone_multiplier = ZoningSystem.zone_multiplier(
				city, building.cell, building.zone_type)

	for building in city.buildings:
		if building == null:
			continue
		var check: CityCheck = ZoningSystem.can_place(
			city, building.cell, building.zone_type)
		if not check.ok:
			report["violations"] += 1
			zone_violation.emit(city.uid, building.cell)

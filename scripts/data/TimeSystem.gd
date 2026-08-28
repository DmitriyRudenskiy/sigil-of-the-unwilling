extends RefCounted
class_name TimeSystem
## Day-time derived from movement points spent.
## hour = 6.0 + mp_spent * 1.8; clamp to 24.
## Noon = [11:00, 13:00); Night = [21:00, 24:00).

signal time_changed(hour: float)

var mp_spent_today: float = 0.0:
	set(v):
		mp_spent_today = clampf(v, 0.0, 10.0)
		_recalculate()

var current_hour: float = 6.0


func _recalculate() -> void:
	current_hour = clampf(6.0 + mp_spent_today * 1.8, 0.0, 24.0)
	time_changed.emit(current_hour)


func reset_for_new_day() -> void:
	mp_spent_today = 0.0
	current_hour = 6.0
	time_changed.emit(current_hour)


func spend_move_points(amount: float) -> void:
	mp_spent_today += amount


func get_period_name() -> String:
	if current_hour >= 11.0 and current_hour < 13.0:
		return "noon"
	# 24.0 (конец дня после clamp) тоже ночь.
	if current_hour >= 21.0 and current_hour <= 24.0:
		return "night"
	return "day"


func is_noon() -> bool:
	return current_hour >= 11.0 and current_hour < 13.0


func is_night() -> bool:
	# 24.0 (конец дня после clamp) тоже ночь.
	return current_hour >= 21.0 and current_hour <= 24.0


func get_hours_until(target_hour: float) -> float:
	if current_hour >= target_hour:
		return 0.0
	return target_hour - current_hour


func wait_hours(hours: float) -> float:
	"""Wait for given hours, returns MP cost."""
	if hours <= 0.0:
		return 0.0
	var mp_cost := hours / 1.8
	mp_spent_today += mp_cost
	return mp_cost


func wait_until_noon() -> float:
	"""Wait until noon (11:00), returns MP cost. 0 if already past noon."""
	if current_hour >= 13.0:
		return 0.0  # Already past noon
	var hours := get_hours_until(11.0)
	return wait_hours(hours)


func wait_until_night() -> float:
	"""Wait until night (21:00), returns MP cost. 0 if already past night."""
	if current_hour >= 24.0:
		return 0.0
	var hours := get_hours_until(21.0)
	return wait_hours(hours)


func format_time() -> String:
	var h := int(floor(current_hour))
	var m := int(round((current_hour - floor(current_hour)) * 60))
	return "🕐 %02d:%02d" % [h, m]

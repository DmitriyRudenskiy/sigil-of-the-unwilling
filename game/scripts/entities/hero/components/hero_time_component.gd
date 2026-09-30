class_name HeroTimeComponent
extends HeroComponent

var time: TimeSystem = TimeSystem.new()

signal time_changed(hour: float)

func setup_hero(hero: HeroController) -> void:
	super(hero)
	time.time_changed.connect(time_changed.emit)

func set_time(v: TimeSystem) -> void:
	time = v

func spend_move_points(amount: float) -> void:
	time.spend_move_points(amount)

func reset_for_new_day() -> void:
	time.reset_for_new_day()

func get_period_name() -> String:
	return time.get_period_name()

func is_noon() -> bool:
	return time.is_noon()

func is_night() -> bool:
	return time.is_night()

func format_time() -> String:
	return time.format_time()

func end_turn() -> void:
	reset_for_new_day()

func serialize() -> Dictionary:
	return {"time_mp_spent": time.mp_spent_today}

func deserialize(data: Dictionary) -> void:
	time.mp_spent_today = float(data.get("time_mp_spent", 0.0))

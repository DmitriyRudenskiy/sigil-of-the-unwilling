class_name CityManager
extends Node

signal city_updated(city: City)
signal cycle_completed(turn: int, arrivals: int)
signal glory_changed(window_total: float)
signal status_message(text: String)
signal reputation_changed(city_uid: int, value: int, band: int)
signal relocation_completed(city_uid: int, new_center: Vector2i)

var cities: Array[City] = []
var capital: City = null
var glory := GloryTracker.new()
var current_turn := 0
var _tile_yield_provider: Callable = Callable()

var _buildable_provider: Callable = Callable()

func register_city(city: City, make_capital := false) -> void:
	if city == null or cities.has(city):
		return
	city.uid = cities.size()
	cities.append(city)
	if _tile_yield_provider.is_valid():
		city.tile_yield_fn = _tile_yield_provider

	if _buildable_provider.is_valid():
		city.is_buildable_fn = _buildable_provider

	city.relocation_completed.connect(
		func(new_center: Vector2i): relocation_completed.emit(city.uid, new_center))
	if make_capital or capital == null:
		set_capital(city)

func set_capital(city: City) -> void:
	if not cities.has(city):
		return
	if capital != null:
		capital.is_capital = false
	capital = city
	city.is_capital = true

func add_glory(amount: float, reason: StringName = &"") -> void:
	glory.add_glory(amount, current_turn + 1, reason)
	glory_changed.emit(glory.glory_last_window(current_turn + 1))

func apply_reputation(city: City, delta: float) -> int:
	if city == null:
		return 0
	var v: int = ReputationSystem.apply(city, delta)
	reputation_changed.emit(city.uid, v, city.reputation_band())
	return v

func set_tile_yield_provider(fn: Callable) -> void:
	_tile_yield_provider = fn
	for c in cities:
		c.tile_yield_fn = fn

func set_buildable_provider(fn: Callable) -> void:
	_buildable_provider = fn
	for c in cities:
		c.is_buildable_fn = fn

func city_at(cell: Vector2i) -> City:
	for c in cities:
		if c != null and c.center == cell:
			return c
	return null

func get_city_by_uid(u: int) -> City:
	for c in cities:
		if c != null and c.uid == u:
			return c
	return null

func on_turn_ended(month: int) -> Dictionary:
	current_turn += 1
	var report := {
		"turn": current_turn, "cities": [], "arrivals": 0, "cycle": false,
	}
	for c in cities:
		var r := c.process_turn(current_turn)
		(report["cities"] as Array).append({
			"city": c.display_name, "births": r.births, "level_ups": r.level_ups,
		})
		city_updated.emit(c)
	glory.prune(current_turn)

	if current_turn % GameNumbers.CITY_CYCLE_TURNS == 0:
		var arrivals := capital_inflow(month)
		report["cycle"] = true
		report["arrivals"] = arrivals
		if arrivals > 0 and capital != null:
			var overflow: int = capital.add_followers(arrivals, current_turn)
			if overflow > 0:
				status_message.emit(
					"Столица переполнена: %d последователей требуют распределения" % overflow
				)
			cycle_completed.emit(current_turn, arrivals)
			city_updated.emit(capital)
	return report

func capital_inflow(month: int) -> int:
	if capital == null:
		return 0
	var base := GameNumbers.INFLOW_BASE \
		+ GameNumbers.INFLOW_PER_TEMPLE * capital.get_great_temple_level()
	var glory_mod := 1.0 \
		+ glory.glory_last_window(current_turn) / GameNumbers.INFLOW_GLORY_DIVISOR
	var season_mod := Season.growth_modifier(Season.from_month(month))
	return int(floor(base * glory_mod * season_mod))

func get_season(month: int) -> Season.ID:
	return Season.from_month(month)

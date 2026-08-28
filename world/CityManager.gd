class_name CityManager
extends Node
## Координатор городов: ходовой цикл, циклический приток в столицу (ТЗ 3.2),
## слава, события для UI. WorldController вызывает on_turn_ended() раз в ход.

signal city_updated(city: City)
signal cycle_completed(turn: int, arrivals: int)
signal glory_changed(window_total: float)
signal status_message(text: String)

var cities: Array[City] = []
var capital: City = null
var glory := GloryTracker.new()
## Абсолютный счётчик завершённых ходов (дней).
var current_turn := 0


func register_city(city: City, make_capital := false) -> void:
	if city == null or cities.has(city):
		return
	city.uid = cities.size()
	cities.append(city)
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
	## Слава за победы, деревни, квесты, подземелья (ТЗ 3.2).
	## +1: событие принадлежит текущему незавершённому ходу.
	glory.add_glory(amount, current_turn + 1, reason)
	glory_changed.emit(glory.glory_last_window(current_turn + 1))


func set_tile_yield_provider(fn: Callable) -> void:
	for c in cities:
		c.tile_yield_fn = fn


func on_turn_ended(month: int) -> Dictionary:
	## Конец хода: все города обрабатываются, затем (каждые 7 ходов) —
	## циклический приток последователей в столицу.
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

	if current_turn % CityBalance.CITY_CYCLE_TURNS == 0:
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
	## Итог = floor(База × Слава × Сезон), ТЗ 3.2.
	if capital == null:
		return 0
	var base := CityBalance.INFLOW_BASE \
		+ CityBalance.INFLOW_PER_TEMPLE_LEVEL * capital.get_great_temple_level()
	var glory_mod := 1.0 \
		+ glory.glory_last_window(current_turn) / CityBalance.INFLOW_GLORY_DIVISOR
	var season_mod := Season.growth_modifier(Season.from_month(month))
	return int(floor(base * glory_mod * season_mod))


func get_season(month: int) -> Season.ID:
	return Season.from_month(month)

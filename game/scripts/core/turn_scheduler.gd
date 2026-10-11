class_name TurnScheduler
extends RefCounted
## T-010: конвейер фаз хода. Драйвер: 1 ход = 1 итерация конвейера.
##
## Порядок исполнения фиксирован (TurnPhase.PHASE_IDS, владелец round 7 §2.2):
##   city_population → hero_movement → caravans_trade → diplomacy_council
##   → battle_raid_resolution → production
## Внутри фазы — get_priority(), затем порядок регистрации.
##
## Счётчик хода — WorldClock (единственный источник): execute_turn()
## продвигает час, ctx.turn_number/ctx.season берутся из него.

signal turn_started(turn: int)
signal phase_completed(phase_id: StringName, report: Dictionary)
signal turn_completed(turn: int, report: Dictionary)

var _processors: Array[TurnPhaseProcessor] = []
var _registration: Dictionary = {}


func register_processor(proc: TurnPhaseProcessor) -> void:
	if proc == null or _processors.has(proc):
		return
	_processors.append(proc)
	_registration[proc] = _registration.size()
	_sort()


func unregister_processor(proc: TurnPhaseProcessor) -> void:
	_processors.erase(proc)
	_registration.erase(proc)


func get_processors() -> Array[TurnPhaseProcessor]:
	return _processors


func execute_turn(ctx: TurnContext) -> Dictionary:
	if ctx == null:
		push_error("TurnScheduler.execute_turn: ctx == null")
		return {}

	var turn: int = WorldClock.advance_turn()
	ctx.turn_number = turn
	ctx.season = WorldClock.season()
	if ctx.weather < 0:
		ctx.weather = GameNumbers.WEATHER_CLEAR
	GameLogger.world("[Turn %d] %s: старт (%d фаз)" % [turn, ctx.get_date_label(), _processors.size()])
	turn_started.emit(turn)

	var report := {"turn": turn, "phases": {}}
	for proc in _processors:
		var phase_id: StringName = proc.get_phase_id()
		var result: Dictionary = proc.process(ctx)
		(report["phases"] as Dictionary)[phase_id] = result
		phase_completed.emit(phase_id, result)

	turn_completed.emit(turn, report)
	return report


func get_turn() -> int:
	return WorldClock.get_turn()


func _sort() -> void:
	var reg := _registration
	_processors.sort_custom(func(a: TurnPhaseProcessor, b: TurnPhaseProcessor) -> bool:
		var ia: int = TurnPhase.order_index(a.get_phase())
		var ib: int = TurnPhase.order_index(b.get_phase())
		if ia != ib:
			return ia < ib
		if a.get_priority() != b.get_priority():
			return a.get_priority() < b.get_priority()
		return int(reg.get(a, 0)) < int(reg.get(b, 0))
	)

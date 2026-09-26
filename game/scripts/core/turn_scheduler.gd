class_name TurnScheduler
extends RefCounted

signal turn_started(turn: int)
signal phase_completed(phase_id: StringName, report: Dictionary)
signal turn_completed(turn: int, report: Dictionary)

var _processors: Array[TurnPhaseProcessor] = []
var _turn := 0

func register_processor(proc: TurnPhaseProcessor) -> void:
	if proc == null or _processors.has(proc):
		return
	_processors.append(proc)
	_processors.sort_custom(func(a: TurnPhaseProcessor, b: TurnPhaseProcessor) -> bool:
		return a.get_priority() < b.get_priority())

func unregister_processor(proc: TurnPhaseProcessor) -> void:
	_processors.erase(proc)

func get_processors() -> Array[TurnPhaseProcessor]:
	return _processors

func execute_turn(ctx: TurnContext) -> Dictionary:
	if ctx == null:
		push_error("TurnScheduler.execute_turn: ctx == null")
		return {}

	_turn += 1
	ctx.turn_number = _turn
	ctx.season = Season.from_month(ctx.month)
	if ctx.weather < 0:
		ctx.weather = GameNumbers.WEATHER_CLEAR
	GameLogger.world("[Turn %d] %s: старт (%d фаз)" % [_turn, ctx.get_date_label(), _processors.size()])
	turn_started.emit(_turn)

	var report := {"turn": _turn, "phases": {}}
	for proc in _processors:
		var phase_id: StringName = proc.get_phase_id()
		var result: Dictionary = proc.process(ctx)
		(report["phases"] as Dictionary)[phase_id] = result
		phase_completed.emit(phase_id, result)

	turn_completed.emit(_turn, report)
	return report

func get_turn() -> int:
	return _turn

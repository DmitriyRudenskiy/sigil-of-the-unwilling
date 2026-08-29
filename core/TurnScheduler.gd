class_name TurnScheduler
extends RefCounted
## Оркестратор фаз хода (M0: Ядро).
##
## Каждый ход: execute_turn(ctx) пробегает зарегистрированные процессоры
## по возрастанию приоритета и собирает отчёт. Заменяет разрозненные
## ручные вызовы в конце хода — новые подсистемы (M1 экономика,
## M2 демография, M3 город) подключаются как независимые процессоры.
##
## Интеграция: WorldBootstrap создаёт планировщик и регистрирует
## процессоры; WorldEventRouter вызывает execute_turn() в _on_end_turn()
## ПОСЛЕ существующего монолита городов (City.process_turn через
## GameEventBus.turn_ended → CityManager.on_turn_ended), чтобы новые
## фазы видели уже актуальное состояние (рождения, склад и т.д.).

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


## Исполняет один ход: обновляет контекст (номер, сезон) и пробегает
## фазы по приоритету. Возвращает итоговый отчёт {"turn": n, "phases": {}}.
func execute_turn(ctx: TurnContext) -> Dictionary:
	if ctx == null:
		push_error("TurnScheduler.execute_turn: ctx == null")
		return {}

	_turn += 1
	ctx.turn_number = _turn
	ctx.season = Season.from_month(ctx.month)
	if ctx.weather < 0:
		ctx.weather = GameSettings.WEATHER_CLEAR
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


## Текущий (последний исполненный) номер хода.
func get_turn() -> int:
	return _turn

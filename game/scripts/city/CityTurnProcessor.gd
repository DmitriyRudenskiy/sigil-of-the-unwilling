class_name CityTurnProcessor
extends TurnPhaseProcessor
## Orchestrates the city turn: runs the sub-processors in scripts/city/processors/
## in fixed order and forwards their signals outward.

signal city_scale_changed(city_uid: int, new_scale: int)
signal zone_violation(city_uid: int, cell: Vector2i)
signal reputation_changed(city_uid: int, value: int, band: int)
signal migration_occurred(city_uid: int, immigrants: int, emigrants: int)
signal worker_assignment_changed(city_uid: int, assigned: int)
signal city_level_up(city_uid: int, new_level: int)
signal raid_occurred(city_uid: int, repelled: bool)
signal city_event_occurred(city_uid: int, event_id: StringName)

var _scale: ScaleProcessor
var _zoning: ZoningProcessor
var _reputation: ReputationProcessor
var _migration: MigrationProcessor
var _workers: WorkerAssignmentProcessor
var _prosperity: ProsperityProcessor
var _level_up: LevelUpProcessor
var _raid: RaidProcessor
var _science: ScienceProcessor
var _events: CityEventsProcessor
var _sub_processors: Array = []

func _init() -> void:
	_scale = ScaleProcessor.new()
	_zoning = ZoningProcessor.new()
	_reputation = ReputationProcessor.new()
	_migration = MigrationProcessor.new()
	_workers = WorkerAssignmentProcessor.new()
	_prosperity = ProsperityProcessor.new()
	_level_up = LevelUpProcessor.new()
	_raid = RaidProcessor.new()
	_science = ScienceProcessor.new()
	_events = CityEventsProcessor.new()
	_sub_processors = [
		_scale, _zoning, _reputation, _migration, _workers,
		_prosperity, _level_up, _raid, _science, _events,
	]
	# Forward sub-processor signals (bootstrap and tests subscribe to the processor).
	_scale.city_scale_changed.connect(func(uid: int, s: int): city_scale_changed.emit(uid, s))
	_zoning.zone_violation.connect(func(uid: int, c: Vector2i): zone_violation.emit(uid, c))
	_reputation.reputation_changed.connect(func(uid: int, v: int, b: int): reputation_changed.emit(uid, v, b))
	_migration.migration_occurred.connect(func(uid: int, i: int, e: int): migration_occurred.emit(uid, i, e))
	_workers.worker_assignment_changed.connect(func(uid: int, a: int): worker_assignment_changed.emit(uid, a))
	_level_up.city_level_up.connect(func(uid: int, l: int): city_level_up.emit(uid, l))
	_raid.raid_occurred.connect(func(uid: int, r: bool): raid_occurred.emit(uid, r))
	_events.city_event_occurred.connect(func(uid: int, e: StringName): city_event_occurred.emit(uid, e))


func get_phase_id() -> StringName:
	return &"city"

func get_priority() -> int:
	return 5

func process(ctx: TurnContext) -> Dictionary:
	var report := {"cities": [], "scale_changes": 0, "zone_violations": 0,
		"rep_deltas": 0, "immigrants": 0, "emigrants": 0, "raids": 0, "events": 0}
	if ctx == null:
		return report
	for city in ctx.cities:
		var city_report: Dictionary = _process_city(city, int(ctx.turn_number))
		(report["cities"] as Array).append(city_report)
		report["scale_changes"] += int(city_report.get("scale_changed", 0))
		report["zone_violations"] += int(city_report.get("violations", 0))
		report["rep_deltas"] += int(city_report.get("rep_delta", 0))
		report["immigrants"] += int(city_report.get("immigrants", 0))
		report["emigrants"] += int(city_report.get("emigrants", 0))
		report["raids"] += int(city_report.get("raid_occurred", 0))
		report["events"] += int(city_report.get("event_occurred", 0))
	return report

func _process_city(city: City, turn: int) -> Dictionary:
	var report := {"uid": city.uid, "scale_changed": 0, "violations": 0, "tier": 0,
		"rep_delta": 0, "immigrants": 0, "emigrants": 0, "raid_occurred": 0,
		"event_occurred": 0, "event": ""}
	for sub in _sub_processors:
		(sub as CitySubProcessor).process(city, turn, report)
	return report

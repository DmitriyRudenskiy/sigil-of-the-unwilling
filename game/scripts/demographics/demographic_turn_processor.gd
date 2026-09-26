class_name DemographicTurnProcessor
extends TurnPhaseProcessor

signal character_born(character_uid: int, city_uid: int, name: String)
signal character_died(character_uid: int, city_uid: int, cause: StringName)
signal character_need_critical(character_uid: int, need_id: int)
signal disease_outbreak(city_uid: int, character_uid: int)

var registry: CharacterRegistry = null
var _rng := RandomNumberGenerator.new()
var _outbreak_turn: Dictionary = {}

func setup(r: CharacterRegistry) -> void:
	registry = r

func get_phase_id() -> StringName:
	return &"demographics"

func get_priority() -> int:
	return 20

func process(ctx: TurnContext) -> Dictionary:
	var report := {"ensured": 0, "critical": 0, "deaths": 0, "outbreaks": 0, "cities": []}
	if ctx == null:
		return report
	if registry == null:
		push_warning("DemographicTurnProcessor: registry not set (setup())")
		return report

	for city in ctx.cities:
		var city_report: Dictionary = _process_city(city, ctx)
		report["ensured"] += int(city_report.get("ensured", 0))
		report["critical"] += int(city_report.get("critical", 0))
		report["deaths"] += int(city_report.get("deaths", 0))
		report["outbreaks"] += int(city_report.get("outbreaks", 0))
		(report["cities"] as Array).append(city_report)
	return report

func _process_city(city: City, ctx: TurnContext) -> Dictionary:
	var report := {"uid": city.uid, "ensured": 0, "critical": 0, "deaths": 0, "outbreaks": 0, "promoted": 0}
	var rng := _rng_for(ctx, city)

	for pop in city.pop.duplicate():
		if registry.get_by_pop(pop.uid) == null:
			var ch := registry.create(city.uid, pop, rng)
			report["ensured"] += 1
			character_born.emit(ch.uid, city.uid, ch.name)

	var critical_chars: Array = []
	for ch in registry.alive_in_city(city.uid).duplicate():
		var pop: PopUnit = _find_pop(city, ch.pop_uid)
		for need_id in Character.NEED_KEYS:
			var strat: NeedStrategy = NeedType.strategies()[need_id]
			var delta := -strat.decay_rate + strat.get_recovery_pop(city, pop)
			delta += ch.trait_modifier(NeedType.to_name(need_id))
			ch.modify_need(need_id, delta)

		for need_id in Character.NEED_KEYS:
			if float(ch.needs[need_id]) <= 0.0001:
				ch.need_zero_streak[need_id] = int(ch.need_zero_streak.get(need_id, 0)) + 1
			else:
				ch.need_zero_streak[need_id] = 0

		var char_critical := 0
		for need_id in Character.NEED_KEYS:
			var crit: bool = ch.is_need_critical(need_id, GameNumbers.DEMO_CRITICAL_THRESHOLD)
			if crit:
				char_critical += 1
				if not bool(ch.was_critical.get(need_id, false)):
					ch.was_critical[need_id] = true
					report["critical"] += 1
					character_need_critical.emit(ch.uid, need_id)
			else:
				ch.was_critical[need_id] = false
		if char_critical >= 2:
			critical_chars.append(ch)

	for ch in registry.alive_in_city(city.uid).duplicate():
		var cause := _death_cause(ch)
		if cause == &"":
			continue
		_kill(city, ch, cause, report)

	var outbreak_due := false
	if not critical_chars.is_empty():
		var threshold := 2 if registry.alive_in_city(city.uid).size() >= 4 else 1
		if critical_chars.size() >= threshold:
			var last: int = int(_outbreak_turn.get(city.uid, -999))
			if ctx.turn_number - last >= GameNumbers.DEMO_OUTBREAK_COOLDOWN:
				outbreak_due = true
	if outbreak_due:
		_outbreak_turn[city.uid] = ctx.turn_number
		for ch in registry.alive_in_city(city.uid):
			if critical_chars.has(ch):
				ch.modify_need(NeedType.ID.REST, -0.2)
				ch.modify_need(NeedType.ID.INSPIRATION, -0.1)
				report["outbreaks"] += 1
				disease_outbreak.emit(city.uid, ch.uid)

	var promoted := 0
	var rc: ResourceContext = city.resource_ctx
	if rc != null:
		var candidate: PopUnit = _promotable_follower(city)
		while rc.amount(&"scholar_points") >= 1.0 \
				and candidate != null \
				and city.free_housing(PopUnit.State.SCHOLAR) > 0:
			rc.remove(&"scholar_points", 1.0)
			candidate.state = PopUnit.State.SCHOLAR
			city.population_changed.emit()
			promoted += 1
			candidate = _promotable_follower(city)
	if promoted > 0:
		report["promoted"] = promoted
	return report

func _promotable_follower(city: City) -> PopUnit:
	var best: PopUnit = null
	for u in city.pop:
		if not u.is_free_follower():
			continue
		if best == null or u.born_turn < best.born_turn:
			best = u
	return best

func _death_cause(ch: Character) -> StringName:
	for need_id in Character.NEED_KEYS:
		if int(ch.need_zero_streak.get(need_id, 0)) >= GameNumbers.DEMO_DEATH_STREAK:
			var strat: NeedStrategy = NeedType.strategies()[need_id]
			return strat.get_death_cause()
	return &""

func _kill(city: City, ch: Character, cause: StringName, report: Dictionary) -> void:
	ch.alive = false
	report["deaths"] += 1
	var removed: PopUnit = city.remove_pop(ch.pop_uid)
	if removed != null:
		removed.character_uid = -1
	registry.on_pop_removed(ch.pop_uid)
	character_died.emit(ch.uid, city.uid, cause)

func _find_pop(city: City, pop_uid: int) -> PopUnit:
	return city.find_pop(pop_uid)

func _rng_for(ctx: TurnContext, city: City) -> RandomNumberGenerator:
	if ctx.rng != null:
		return ctx.rng
	_rng.seed = hash([ctx.turn_number, city.uid])
	return _rng

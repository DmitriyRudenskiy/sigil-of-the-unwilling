class_name DemographicTurnProcessor
extends TurnPhaseProcessor
## Фаза 2 (M2: Демография). Исполняется ПОСЛЕ экономики (priority 20).
##
## Персонажи — нарративная оболочка над PopUnit; сам населенческий
## контур (рождения/смерти от голода в монолите City.process_turn)
## НЕ дублируется здесь — процессор только гарантирует персонажа
## для каждой живой фигурки и тикает потребности.
##
## Тик:
##  1. Для каждой pop без персонажа — create() + character_born;
##  2. Дельты потребностей (базовый распад + восстановление от города
##     + модификаторы черт);
##  3. Критика (< 0.2) — сигнал раз в эпизод (не каждый ход);
##  4. Смерть: потребность = 0.0 три хода подряд -> character_died,
##     фигурка удаляется (city.remove_pop);
##  5. Эпидемия: 2+ персонажа с 2+ критическими потребностями
##     (или 1, если город маленький) -> disease_outbreak на каждого
##     поражённого (кулдаун 5 ходов на город).
##
## НЕ вызывает city.process_turn() — монолит уже отработал ранее.
## Внешние эффекты пробрасывает интеграционный слой (WorldBootstrap).

signal character_born(character_uid: int, city_uid: int, name: String)
signal character_died(character_uid: int, city_uid: int, cause: StringName)
signal character_need_critical(character_uid: int, need_id: StringName)
signal disease_outbreak(city_uid: int, character_uid: int)

const CRITICAL_THRESHOLD := 0.2
const DEATH_STREAK := 3
const OUTBREAK_COOLDOWN := 5

## Базовый ежедневный распад потребностей (без восстановлений).
const DECAY: Dictionary = {
	&"hunger": 0.15,
	&"rest": 0.10,
	&"social": 0.08,
	&"inspiration": 0.05,
}

var registry: CharacterRegistry = null
var _rng := RandomNumberGenerator.new()
## city_uid -> ход последней эпидемии
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
		push_warning("DemographicTurnProcessor: registry не задан (setup())")
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

	# 1. Персонаж для каждой живой фигурки.
	for pop in city.pop.duplicate():
		if registry.get_by_pop(pop.uid) == null:
			var ch := registry.create(city.uid, pop, rng)
			report["ensured"] += 1
			character_born.emit(ch.uid, city.uid, ch.name)

	# 2. Тик потребностей.
	var critical_chars: Array = []
	for ch in registry.alive_in_city(city.uid).duplicate():
		var pop: PopUnit = _find_pop(city, ch.pop_uid)
		for need_id in Character.NEED_KEYS:
			var delta := -float(DECAY[need_id])
			delta += _recovery(need_id, city, pop)
			delta += ch.trait_modifier(need_id)
			ch.modify_need(need_id, delta)

		# Счётчик нулевых ходов.
		for need_id in Character.NEED_KEYS:
			if float(ch.needs[need_id]) <= 0.0001:
				ch.need_zero_streak[need_id] = int(ch.need_zero_streak.get(need_id, 0)) + 1
			else:
				ch.need_zero_streak[need_id] = 0

		# 3. Критика (сигнал раз в эпизод).
		var char_critical := 0
		for need_id in Character.NEED_KEYS:
			var crit: bool = ch.is_need_critical(need_id, CRITICAL_THRESHOLD)
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

	# 4. Смерти.
	for ch in registry.alive_in_city(city.uid).duplicate():
		var cause := _death_cause(ch)
		if cause == &"":
			continue
		_kill(city, ch, cause, report)

	# 5. Эпидемия.
	var outbreak_due := false
	if not critical_chars.is_empty():
		var threshold := 2 if registry.alive_in_city(city.uid).size() >= 4 else 1
		if critical_chars.size() >= threshold:
			var last: int = int(_outbreak_turn.get(city.uid, -999))
			if ctx.turn_number - last >= OUTBREAK_COOLDOWN:
				outbreak_due = true
	if outbreak_due:
		_outbreak_turn[city.uid] = ctx.turn_number
		for ch in registry.alive_in_city(city.uid):
			if critical_chars.has(ch):
				ch.modify_need(&"rest", -0.2)
				ch.modify_need(&"inspiration", -0.1)
				report["outbreaks"] += 1
				disease_outbreak.emit(city.uid, ch.uid)

	# 6. Повышение учёных (Спринт 7): балл училища (scholar_points)
	#    -> самый старый свободный последователь становится учёным
	#    (персонаж не мешает — состояние живёт на PopUnit).
	#    Особняк (slot SCHOLAR) обязателен.
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
	## Самый старый свободный последователь (исключая переключающихся
	## и закреплённых — is_free_follower()).
	var best: PopUnit = null
	for u in city.pop:
		if not u.is_free_follower():
			continue
		if best == null or u.born_turn < best.born_turn:
			best = u
	return best


## Восстановление потребности от состояния города.
func _recovery(need_id: StringName, city: City, pop: PopUnit) -> float:
	match need_id:
		&"hunger":
			# Есть еда — сытость восстанавливается; голодающий город — распад усиливается.
			if city.starving:
				return -0.10
			return 0.20
		&"rest":
			# Рабочий живёт по ритму (норма сна), ополченец — дежурства.
			if pop != null and pop.state == PopUnit.State.MILITIA:
				return 0.0
			return 0.12
		&"social":
			# Компания есть, если население прилично.
			if city.pop.size() >= 3:
				return 0.10
			return -0.05
		&"inspiration":
			return 0.05
	return 0.0


func _death_cause(ch: Character) -> StringName:
	for need_id in Character.NEED_KEYS:
		if int(ch.need_zero_streak.get(need_id, 0)) >= DEATH_STREAK:
			match need_id:
				&"hunger":
					return &"starvation"
				&"rest":
					return &"exhaustion"
				&"social":
					return &"isolation"
				&"inspiration":
					return &"burnout"
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
	## Детерминированный rng: если контекст принёс свой — берём его,
	## иначе сидируем от (ход, город) — воспроизводимо без внешнего RNG.
	if ctx.rng != null:
		return ctx.rng
	_rng.seed = hash([ctx.turn_number, city.uid])
	return _rng

class_name CityTurnProcessor
extends TurnPhaseProcessor
## M3: Фаза города. Исполняется ПЕРВОЙ среди каскадных фаз (приоритет 5 —
## раньше экономики 10 и демографии 20), чтобы мультипликаторы были готовы:
##
##  1. Масштаб — пересчёт tier по населению (ScaleShiftManager); при смене
##     — сигнал city_scale_changed (→ GameEventBus.scale_shift);
##  2. Ёмкости хранилищ — базовые лимиты resource_ctx × storage_multiplier;
##     базовые лимиты кэшируются, чтобы смена масштаба не множила уже
##     умноженные значения;
##  3. Мультипликаторы города — auto_resource_mult / upkeep_mult для
##     EconomicTurnProcessor;
##  4. Зонирование — zone_multiplier у каждого здания (для экономики);
##  5. Контроль зон — здания, нарушающие правила (например, завод у
##     центра), дают сигнал zone_violation (защита от обходов UI);
##  6. Репутация (Спринт 6) — факторы хода (еда/голод/перенаселение/
##     adjacency), сжатие -100..+100, сигнал reputation_changed;
##  7. Миграция (Спринт 6) — иммиграция при репутации >= +30, эмиграция
##     при <= -30 (порядок: учёный -> ополченец -> рабочий), сигнал
##     migration_occurred;
##  8. Рабочие (Спринт 7) — WorkerAssignment.rebalance(): сломанные
##     ссылки освобождаем, здания добирают рабочих до required_workers,
##     сигнал worker_assignment_changed.
##
## Не вызывает city.process_turn() — монолит идёт своим контуром (turn_ended).

signal city_scale_changed(city_uid: int, new_scale: int)
signal zone_violation(city_uid: int, cell: Vector2i)
signal reputation_changed(city_uid: int, value: int, band: int)
signal migration_occurred(city_uid: int, immigrants: int, emigrants: int)
signal worker_assignment_changed(city_uid: int, assigned: int)
## Спринт 9: город повысил уровень (1..5).
signal city_level_up(city_uid: int, new_level: int)
## Спринт 10: рейд (repelled = отбит).
signal raid_occurred(city_uid: int, repelled: bool)


## Базовые (до масштабного бонуса) ёмкости: city.uid -> {id: float}.
var _base_caps: Dictionary = {}


func get_phase_id() -> StringName:
	return &"city"


func get_priority() -> int:
	return 5


func process(ctx: TurnContext) -> Dictionary:
	var report := {"cities": [], "scale_changes": 0, "zone_violations": 0,
		"rep_deltas": 0, "immigrants": 0, "emigrants": 0, "raids": 0}
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
	return report


func _process_city(city: City, turn: int) -> Dictionary:
	var report := {"uid": city.uid, "scale_changed": 0, "violations": 0, "tier": 0,
		"rep_delta": 0, "immigrants": 0, "emigrants": 0, "raid_occurred": 0}

	# 1. Масштаб.
	var new_tier: int = ScaleShiftManager.tier_for(city.pop_capped())
	if new_tier != city.scale_tier:
		city.scale_tier = new_tier
		report["scale_changed"] = 1
		city_scale_changed.emit(city.uid, new_tier)
	report["tier"] = new_tier

	# 2. Ёмкости хранилищ (базовые × масштаб).
	var res := city.ensure_resource_ctx()
	var storage_mult: float = ScaleShiftManager.storage_multiplier(new_tier)
	if storage_mult != 1.0:
		var base: Dictionary = _base_caps.get(city.uid, {})
		for rid in _known_resource_ids(res):
			var cur_cap: float = res.get_capacity(rid)
			if cur_cap >= GameSettings.INF / 2.0:
				continue  # безлимитные — не трогаем
			if not base.has(rid):
				base[rid] = cur_cap  # первый раз: текущий лимит — базовый
			res.set_capacity(rid, float(base[rid]) * storage_mult)
		_base_caps[city.uid] = base
	elif _base_caps.has(city.uid):
		# Масштаб вернулся на 1.0 — восстанавливаем базовые лимиты.
		var base: Dictionary = _base_caps[city.uid]
		for rid in base:
			res.set_capacity(rid, float(base[rid]))

	# 3. Мультипликаторы для экономики.
	city.auto_resource_mult = ScaleShiftManager.auto_resource_multiplier(new_tier)
	city.upkeep_mult = ScaleShiftManager.upkeep_multiplier(new_tier)

	# 4. Зонирование зданий.
	for building in city.buildings:
		if building == null:
			continue
		if building.zone_type == ZoningSystem.ZoneType.NONE:
			building.zone_multiplier = 1.0
		else:
			building.zone_multiplier = ZoningSystem.zone_multiplier(
				city, building.cell, building.zone_type)

	# 5. Контроль нарушений.
	for building in city.buildings:
		if building == null:
			continue
		var check: Dictionary = ZoningSystem.can_place(
			city, building.cell, building.zone_type)
		if not check.ok:
			report["violations"] += 1
			zone_violation.emit(city.uid, building.cell)

	# 6. Репутация (Спринт 6): факторы хода + сжатие.
	var rep_before: int = city.reputation
	ReputationSystem.process_turn(city)
	if city.reputation != rep_before:
		report["rep_delta"] = city.reputation - rep_before
		reputation_changed.emit(city.uid, city.reputation, city.reputation_band())

	# 7. Миграция (Спринт 6).
	var mig: Dictionary = ReputationSystem.process_migration(city)
	report["immigrants"] = int(mig.immigrants)
	report["emigrants"] = int(mig.emigrants)
	if int(mig.immigrants) > 0 or int(mig.emigrants) > 0:
		migration_occurred.emit(city.uid, int(mig.immigrants), int(mig.emigrants))

	# 8. Назначение рабочих (Спринт 7) — после миграции: новые рабочие
	#    сразу занимают свободные места в цепочках зданий.
	var assigned: int = WorkerAssignment.rebalance(city)
	if assigned > 0:
		report["workers_assigned"] = assigned
		worker_assignment_changed.emit(city.uid, assigned)

	# 9. Процветание (Спринт 9): пересчёт + бонус к золоту + реп. модификатор.
	var prosperity: float = ProsperitySystem.recalculate(city)
	var gold_bonus: float = ProsperitySystem.gold_bonus(city)
	if gold_bonus > 0.0:
		city.storage[&"industry"] = float(city.storage.get(&"industry", 0.0)) + gold_bonus
	var rep_mod: int = ProsperitySystem.reputation_mod(city)
	if rep_mod != 0:
		ReputationSystem.apply(city, float(rep_mod))
	report["prosperity"] = prosperity
	report["gold_bonus"] = gold_bonus

	# 10. Уровень города (Спринт 9): кольцо застройки расширяется.
	if ProsperitySystem.try_level_up(city):
		report["level_up"] = city.level
		city_level_up.emit(city.uid, city.level)

	# 11. Рейды (Спринт 10): детерминированный бросок от (uid, turn).
	var raid: Dictionary = RaidSystem.resolve(city, turn)
	if bool(raid.occurred):
		report["raid_occurred"] = 1
		report["raid_repelled"] = bool(raid.repelled)
		report["raid_strength"] = int(raid.strength)
		raid_occurred.emit(city.uid, bool(raid.repelled))
	return report


## Ресурсы, известные контексту (есть в _resources — только они имеют
## запас, который может упреться в лимит; не тронутые остаются базовыми).
func _known_resource_ids(res: ResourceContext) -> Array:
	var ids: Array = []
	for id in res.get_all():
		ids.append(id)
	return ids

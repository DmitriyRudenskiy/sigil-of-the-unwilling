class_name DataLibrary
extends RefCounted

# [AI]: сгенерировано по задаче 5.4 tasks.md, проверено человеком.
#
# Загрузчик и валидатор данных. Формат проверки отделён от формата файлов:
# validate() принимает уже загруженные словари/наборы, поэтому тесты могут
# испортить копию данных и убедиться, что конкретное правило срабатывает, а не
# только что «на настоящих данных всё хорошо».


## Каталог юнитов и наборы. Файлы создаёт tools/author_data.gd.
const UNITS_DIR := "res://data/units"
const ROSTER_IDS := ["a", "b"]
const ENEMY_ID := &"stormmage"
## Восемь юнитов в пуле плюс один враг.
const UNIT_COUNT := 9
const POOL_SIZE := 8
const ROSTER_SIZE := 7


static func roster_path(id: String) -> String:
	return "res://data/rosters/%s.tres" % id


## id -> UnitStats по всем .tres каталога.
static func load_units() -> Dictionary:
	var loaded := {}
	for file in DirAccess.get_files_at(UNITS_DIR):
		if not file.ends_with(".tres"):
			continue
		var stats := load("%s/%s" % [UNITS_DIR, file]) as UnitStats
		if stats == null:
			continue
		loaded[stats.id] = stats
	return loaded


static func load_roster(id: String) -> RosterData:
	return load(roster_path(id)) as RosterData


static func load_rosters() -> Array:
	var loaded: Array = []
	for id in ROSTER_IDS:
		loaded.append(load_roster(id))
	return loaded


## Нарушения как человекочитаемые строки; пустой массив = данные годны.
static func validate(units: Dictionary, rosters: Array) -> Array[String]:
	var problems: Array[String] = []
	_check_units(units, problems)
	_check_rosters(units, rosters, problems)
	return problems


static func _check_units(units: Dictionary, problems: Array[String]) -> void:
	if units.size() != UNIT_COUNT:
		problems.append("юнитов %d, ожидалось %d" % [units.size(), UNIT_COUNT])
	if not units.has(ENEMY_ID):
		problems.append("нет врага %s" % ENEMY_ID)
	if units.size() - 1 != POOL_SIZE:
		problems.append("в пуле %d юнитов, ожидалось %d" % [units.size() - 1, POOL_SIZE])
	for id in units:
		var stats: UnitStats = units[id]
		var who := "юнит %s" % id
		if stats.max_hp <= 0 or stats.attack <= 0 or stats.initiative <= 0:
			problems.append("%s: hp/attack/initiative должны быть больше нуля" % who)
		if stats.abilities.size() != 1:
			problems.append("%s: нужна ровно одна способность" % who)
		for ability in stats.abilities:
			_check_ability(who, ability, problems)


static func _check_ability(who: String, ability: Ability, problems: Array[String]) -> void:
	if ability.id == &"":
		problems.append("%s: способность без id" % who)
	if ability.cost < 0 or ability.cost > BattleUnit.FOCUS_MAX:
		problems.append("%s: стоимость %d вне 0..%d" % [who, ability.cost, BattleUnit.FOCUS_MAX])
	if ability.cooldown < 0 or ability.hits < 1:
		problems.append("%s: %s — отрицательный откат или ноль ударов" % [who, ability.id])
	if ability.multiplier < 0.0:
		problems.append("%s: %s — отрицательный множитель" % [who, ability.id])
	if not ability.target_kind in [
		Ability.TargetKind.ENEMY_SINGLE,
		Ability.TargetKind.ENEMY_ALL,
		Ability.TargetKind.ALLY_SINGLE,
		Ability.TargetKind.ALLY_OTHERS,
	]:
		problems.append("%s: %s — неизвестная цель" % [who, ability.id])
	for status_id in ability.applies + ability.self_applies:
		if not BattleUnit.STATUSES.has(status_id):
			problems.append("%s: %s — неизвестный статус %s" % [who, ability.id, status_id])


static func _check_rosters(units: Dictionary, rosters: Array, problems: Array[String]) -> void:
	if rosters.size() != ROSTER_IDS.size():
		problems.append("наборов %d, ожидалось %d" % [rosters.size(), ROSTER_IDS.size()])
	var seen_titles := {}
	var membership := {}
	for roster in rosters:
		if roster == null or not roster is RosterData:
			problems.append("набор не загрузился или это не RosterData")
			continue
		var who := "набор %s" % roster.id
		if roster.title == "" or roster.difference == "":
			problems.append("%s: пустое имя или описание отличия" % who)
		if seen_titles.has(roster.title):
			problems.append("%s: имя набора повторяется" % who)
		seen_titles[roster.title] = true
		if roster.units.size() != ROSTER_SIZE:
			problems.append("%s юнитов %d, ожидалось %d" % [who, roster.units.size(), ROSTER_SIZE])
		var ids := {}
		for stats in roster.units:
			if ids.has(stats.id):
				problems.append("%s: %s встречается дважды" % [who, stats.id])
			ids[stats.id] = true
			if not units.has(stats.id):
				problems.append("%s: юнит %s нет в каталоге" % [who, stats.id])
			elif stats.id == ENEMY_ID:
				problems.append("%s: враг %s в наборе игрока" % [who, ENEMY_ID])
		membership[roster.id] = ids
	if membership.size() == ROSTER_IDS.size():
		_check_roster_difference(membership, problems)


## Наборы различаются ровно одним юнитом с каждой стороны — иначе «два набора»
## это два разных состава, а не вариация.
static func _check_roster_difference(membership: Dictionary, problems: Array[String]) -> void:
	var first: Dictionary = membership[ROSTER_IDS[0]]
	var second: Dictionary = membership[ROSTER_IDS[1]]
	var only_first := 0
	var only_second := 0
	for id in first:
		if not second.has(id):
			only_first += 1
	for id in second:
		if not first.has(id):
			only_second += 1
	if only_first != 1 or only_second != 1:
		problems.append(
			(
				"наборы различаются на %d и %d юнитов, ожидалось по одному"
				% [only_first, only_second]
			)
		)

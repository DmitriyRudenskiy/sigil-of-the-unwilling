class_name ReputationSystem
extends RefCounted
## Спринт 6: Репутация города и миграция.
##
## Репутация: шкала -100..+100 (City.reputation). Диапазоны (диапазонные
## пороги, по концепту):
##   >= +80  Золотой век | >= +30  Процветание | >= 0  Норма
##   >= -30  Недовольство | >= -70  Кризис | иначе  Бунт
##
## Факторы хода (turn_factor):
##   +1  при нетто-еде > 0 (еда есть);
##   -5  голод в этом ходу;
##   -2  за каждую фигурку сверх лимита населения;
##   +/- adjacency-бонусы зданий (AdjacencySystem.reputation_bonus,
##       Спринт 8: храм/таверна у жилья +2, особняк у рудника -2);
##   +/- черта города «Вера» (Спринт 11: +1/ход).
## Дискретные события (победа +10, ЧП -10) — apply().
##
## Миграция — функция репутации:
##   >= +30: иммиграция +1/ход (состояние — City.immigrant_state(),
##           т.е. по жилью; пока нет жилья — рабочий);
##   <= -30: эмиграция -1/ход (<= -70: -2/ход), порядок ухода
##           УЧЁНЫЙ -> ОПОЛЧЕНЕЦ -> РАБОЧИЙ; уходят только фигурки
##           без персонажей (иначе персонаж вешается в воздух).
##
## Статика, без нод Godot — тестируется headless.

enum Band {
	REBELLION = 0,    # <= -70
	CRISIS = 1,       # -70..-30
	DISCONTENT = 2,   # -30..-1
	NORMAL = 3,       # 0..29
	PROSPERITY = 4,   # 30..79
	GOLDEN_AGE = 5,   # >= 80
}


## Диапазон по значению (границы включены в верхний диапазон).
static func band(value: int) -> int:
	if value >= CityBalance.REP_BAND_GOLDEN_AGE:
		return Band.GOLDEN_AGE
	if value >= CityBalance.REP_BAND_PROSPERITY:
		return Band.PROSPERITY
	if value >= 0:
		return Band.NORMAL
	if value >= CityBalance.REP_BAND_DISCONTENT:
		return Band.DISCONTENT
	if value >= CityBalance.REP_BAND_CRISIS:
		return Band.CRISIS
	return Band.REBELLION


static func band_name(value: int) -> String:
	match band(value):
		Band.GOLDEN_AGE:
			return "Золотой век"
		Band.PROSPERITY:
			return "Процветание"
		Band.NORMAL:
			return "Норма"
		Band.DISCONTENT:
			return "Недовольство"
		Band.CRISIS:
			return "Кризис"
		_:
			return "Бунт"


static func clamp_value(v: int) -> int:
	return clampi(v, CityBalance.REP_MIN, CityBalance.REP_MAX)


## Суммарный фактор хода (до дискретных событий).
static func turn_factor(city: City) -> int:
	var f := 0
	if city.net_food() > 0.0:
		f += CityBalance.REP_FOOD_SURPLUS
	if city.starving:
		f += CityBalance.REP_STARVING
	f += CityBalance.REP_OVERPOP_PER * city.over_limit()
	f += AdjacencySystem.reputation_bonus(city)
	return f


## Применить дельту, вернуть новое значение (зажато -100..+100).
static func apply(city: City, delta: float) -> int:
	city.reputation = clamp_value(int(city.reputation) + int(roundf(delta)))
	return city.reputation


## Ход репутации: факторы + сжатие.
static func process_turn(city: City) -> int:
	return apply(city, turn_factor(city))


## Миграция за ход. Возвращает {"immigrants": int, "emigrants": int}.
## Мутация населения только через публичные API города.
static func process_migration(city: City) -> Dictionary:
	var immigrants := 0
	var emigrants := 0
	if city.reputation >= CityBalance.MIGRATE_IN_AT:
		if city.pop_capped() < city.pop_cap():
			var st: int = city.immigrant_state()
			if st >= 0:
				city.add_migrant(st)
				immigrants = CityBalance.MIGRATE_IN_PER_TURN
	elif city.reputation <= CityBalance.MIGRATE_OUT_AT:
		var per: int = CityBalance.MIGRATE_CRISIS_PER_TURN \
			if city.reputation <= CityBalance.MIGRATE_CRISIS_AT \
			else 1
		for i in per:
			if _emigrate_one(city):
				emigrants += 1
	if immigrants > 0 or emigrants > 0:
		city.population_changed.emit()
	return {"immigrants": immigrants, "emigrants": emigrants}


## Эмиграция одной фигурки: УЧЁНЫЙ -> ОПОЛЧЕНЕЦ -> РАБОЧИЙ.
## Берёт первую свободную (без персонажа); ополчение/учёных без
## персонажей обычно нет — тогда уходит рабочий.
static func _emigrate_one(city: City) -> bool:
	var order: Array = [
		PopUnit.State.SCHOLAR,
		PopUnit.State.MILITIA,
		PopUnit.State.WORKER,
		PopUnit.State.FOLLOWER,
	]
	for st in order:
		for u in city.pop:
			if u.state == st and u.character_uid == -1:
				city.remove_pop(u.uid)
				return true
	return false

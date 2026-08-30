class_name ProsperitySystem
extends RefCounted
## Спринт 9: Процветание и уровень города.
##
## Процветание (0..100) — интегральный показатель здоровья экономики:
## еда, золото, застройка, плотность населения, репутация. Пересчитывается
## каждый ход (CityTurnProcessor, шаг 9) и даёт:
##   - бонус к золоту: GOLD_PER_POINT × prosperity (100 → +5/ход);
##   - модификатор репутации: +1 (>= REP_HIGH) / -1 (<= REP_LOW).
##
## Уровень города (1..CITY_LEVEL_MAX) растёт, когда СОВМЕСТНО выполнены:
##   - prosperity >= LEVEL_PROSPERITY_REQ;
##   - население >= LEVEL_POP_BASE + LEVEL_POP_STEP × (level - 1);
##   - зданий >= LEVEL_BUILDINGS_PER × level.
## Каждый уровень расширяет «кольцо» застройки на 1 клетку
## (City.building_max_distance): ур.1 = 3, ур.2 = 4, ур.3+ = 5.
##
## Статический класс — headless-тестируемый, без autoload.
## Сигналы эмитит CityTurnProcessor (city_level_up), WorldBootstrap
## пробрасывает их в GameEventBus.

const PROSPERITY_MIN := 0.0
const PROSPERITY_MAX := 100.0

## Базовое процветание нейтрального города.
const BASE := 50.0
## +N за положительный нетто-баланс еды, -N при голоде.
const FOOD_BONUS := 10.0
## +N при золоте (industry) >= GOLD_REQ.
const GOLD_BONUS := 10.0
const GOLD_REQ := 10.0
## +N за каждое здание, максимум BUILDINGS_BONUS_CAP.
const BUILDINGS_BONUS_PER := 2.0
const BUILDINGS_BONUS_CAP := 20.0
## +N при населении >= POP_RATIO от капа (город «живёт на пределе»).
const POP_BONUS := 10.0
const POP_RATIO := 0.75
## Репутация вносит репутацию/10 пунктов (-10..+10).

## Золото за пункт процветания (100 → +5.0/ход).
const GOLD_PER_POINT := 0.05
## Пороги репутационного модификатора.
const REP_HIGH := 60.0
const REP_LOW := 20.0

## Уровни города.
const CITY_LEVEL_MIN := 1
const CITY_LEVEL_MAX := 5
const LEVEL_PROSPERITY_REQ := 60.0
const LEVEL_POP_BASE := 12
const LEVEL_POP_STEP := 8
const LEVEL_BUILDINGS_PER := 2
## Кольцо застройки: базовый радиус (CityBalance.BUILDING_MAX_BUILD_DISTANCE)
## + (level - 1), потолок MAX_BUILD_RADIUS.
const MAX_BUILD_RADIUS := 5


## Пересчитывает и записывает prosperity. Возвращает новое значение.
static func recalculate(city: City) -> float:
	var v := BASE
	# Еда: нетто-баланс города.
	if city.net_food() >= 0.0:
		v += FOOD_BONUS
	else:
		v -= FOOD_BONUS
	# Золото на складе.
	if float(city.storage.get(&"industry", 0.0)) >= GOLD_REQ:
		v += GOLD_BONUS
	# Застройка.
	var bld: float = 0.0
	for building in city.buildings:
		if building != null:
			bld += BUILDINGS_BONUS_PER
	v += minf(bld, BUILDINGS_BONUS_CAP)
	# Плотность населения.
	var cap := city.pop_cap()
	if cap > 0 and float(city.pop_capped()) / float(cap) >= POP_RATIO:
		v += POP_BONUS
	# Репутация: -10..+10.
	v += float(city.reputation) / 10.0
	v = clampf(v, PROSPERITY_MIN, PROSPERITY_MAX)
	city.prosperity = v
	return v


## Бонус к золоту за ход (0..GOLD_PER_POINT × 100).
static func gold_bonus(city: City) -> float:
	return city.prosperity * GOLD_PER_POINT


## Модификатор репутации за ход: +1 / 0 / -1.
static func reputation_mod(city: City) -> int:
	if city.prosperity >= REP_HIGH:
		return 1
	if city.prosperity <= REP_LOW:
		return -1
	return 0


## Население, требуемое для перехода с `level` на level+1.
static func level_pop_req(level: int) -> int:
	return LEVEL_POP_BASE + LEVEL_POP_STEP * (level - 1)


## Число зданий, требуемое для перехода с `level` на level+1.
static func level_buildings_req(level: int) -> int:
	return LEVEL_BUILDINGS_PER * level


## Радиус застройки для уровня (кольцо): 3, 4, 5, 5, 5.
static func build_radius_for_level(level: int) -> int:
	var l := clampi(level, CITY_LEVEL_MIN, CITY_LEVEL_MAX)
	return mini(CityBalance.BUILDING_MAX_BUILD_DISTANCE + (l - 1), MAX_BUILD_RADIUS)


## Проверка условий повышения. {ok: bool, reasons: Array[String]}.
static func can_level_up(city: City) -> Dictionary:
	var reasons: Array[String] = []
	if city.level >= CITY_LEVEL_MAX:
		return {"ok": false, "reasons": ["Максимальный уровень"]}
	if city.prosperity < LEVEL_PROSPERITY_REQ:
		reasons.append("Процветание: %.0f/%.0f" % [city.prosperity, LEVEL_PROSPERITY_REQ])
	if city.pop_capped() < level_pop_req(city.level):
		reasons.append("Население: %d/%d" % [city.pop_capped(), level_pop_req(city.level)])
	var bld := 0
	for building in city.buildings:
		if building != null:
			bld += 1
	if bld < level_buildings_req(city.level):
		reasons.append("Здания: %d/%d" % [bld, level_buildings_req(city.level)])
	return {"ok": reasons.is_empty(), "reasons": reasons}


## Повышает уровень, если условия выполнены. true = произошло повышение
## (сигнал эмитит вызывающий процессор).
static func try_level_up(city: City) -> bool:
	var check := can_level_up(city)
	if not bool(check.ok):
		return false
	city.level += 1
	return true

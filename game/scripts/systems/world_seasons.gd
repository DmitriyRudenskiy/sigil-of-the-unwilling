class_name WorldSeasons
extends RefCounted
## Мировые сезоны (раннее основание, 2026-09-30; Q-M26 — владелец 2026-10-05).
## 1 ход = 1 сезон (канон «turn = season», T-032, GDD §6): сезон меняется каждый ход
## (цикл: Ясный → Морось → Буря). Ход 1 = Ясный сезон.
## DAYS_PER_SEASON — баланс-конфиг (07-balance §2): 1 ход = DAYS_PER_SEASON дней;
## единственная конверсия день↔ход — все день-величины (k_pop, intra_region_steps)
## выражаются через DAYS_PER_SEASON, независимые день-константы запрещены.
## Баланс-год «4 сезона × ~90 дней» (владелец 2026-10-05 §2.3) — сводится на стороне
## баланса, не в каноне (Q-M27).

const SEASONS: Array = [
	{"name": "Ясный сезон", "prod_mult": 1.0, "enemy_mult": 1.0},
	{"name": "Морось", "prod_mult": 1.2, "enemy_mult": 1.0},
	{"name": "Буря", "prod_mult": 0.4, "enemy_mult": 1.25},
]
## Баланс-конфиг (07-balance §2): дней в ходе (= дней в сезоне).
## Единственный источник конверсии день↔ход (Q-M26, владелец 2026-10-05).
const DAYS_PER_SEASON: int = 20

const HOSTILITY_BASE: float = 1.0
const HOSTILITY_GROWTH: float = 0.02
const HOSTILITY_CAP: float = 2.0

static var _turn_count: int = 0  # число ходов (1 ход = 1 сезон, Q-M26)

static func advance_turn() -> void:
	_turn_count += 1

static func get_turns() -> int:
	return _turn_count

static func set_turns(turns: int) -> void:
	_turn_count = maxi(turns, 0)

## Сезон текущего хода: ход 1 = Ясный (0), ход 2 = Морось (1), ход 3 = Буря (2), ход 4 = Ясный...
static func season_index() -> int:
	if _turn_count <= 0:
		return 0
	return (_turn_count - 1) % SEASONS.size()

static func season_name() -> String:
	return SEASONS[season_index()]["name"]

static func production_mult() -> float:
	return SEASONS[season_index()]["prod_mult"]

static func enemy_mult() -> float:
	return SEASONS[season_index()]["enemy_mult"]

## Враждебность мира растёт со временем (давление среды, K-R3).
static func hostility_mult() -> float:
	return minf(HOSTILITY_BASE + float(_turn_count) * HOSTILITY_GROWTH, HOSTILITY_CAP)

static func reset() -> void:
	_turn_count = 0

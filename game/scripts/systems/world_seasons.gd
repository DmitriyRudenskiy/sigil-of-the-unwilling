class_name WorldSeasons
extends RefCounted
## Мировые сезоны (раннее основание, 2026-09-30; Q-M26/Q-M27 — владелец 2026-10-05).
## 1 ход = 1 сезон (канон «turn = season», GDD §6 «четыре хода составляют год»):
## цикл 4 сезона (Q-M27, закрыто, 11-я итерация §1.1): Весна → Лето → Осень → Зима.
## Ход 1 = Весна; season_index = (turns − 1) % 4.
## DAYS_PER_SEASON — баланс-конфиг (07-balance §2): 1 ход = DAYS_PER_SEASON дней;
## единственная конверсия день↔ход — все день-величины (k_pop, intra_region_steps)
## выражаются через DAYS_PER_SEASON, независимые день-константы запрещены.
## Числа множителей — 07-balance §6 (сезонная таблица, канон чисел).
## Q-M29 (открыт): ход 21 = Весна по формуле vs «ход 21 = зима» в решении Q-M27 —
## арифметическое противоречие внутри директивы, вердикт владельцу.

const SEASONS: Array = [
	# 07-balance §6 (сезонная таблица, Q-M27): перенос 3-сезонной —
	# Ясный→весна, Морось→лето, Буря→зима; осень — нейтральная.
	# Якорь: зима < весна (GDD §6 «зима сокращает сбор еды»).
	{"name": "Весна", "prod_mult": 1.0, "enemy_mult": 1.0},
	{"name": "Лето", "prod_mult": 1.2, "enemy_mult": 1.0},
	{"name": "Осень", "prod_mult": 1.0, "enemy_mult": 1.0},
	{"name": "Зима", "prod_mult": 0.4, "enemy_mult": 1.25},
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

## Сезон текущего хода: ход 1 = Весна (0), ход 2 = Лето (1), ход 3 = Осень (2),
## ход 4 = Зима (3), ход 5 = Весна... Формула (Q-M27): (turns − 1) % 4.
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

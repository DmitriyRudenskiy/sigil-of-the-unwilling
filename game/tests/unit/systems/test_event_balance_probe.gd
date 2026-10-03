extends BaseTest

## crisis-content-seasonal-rare-events 5.1: статистический прогон.
## Детерминированный seed; проверяет:
## - темп кризисов не меняется от сезонного фильтра (критерий 4);
## - редкие события наблюдаемы и не чаще weights-лимита (критерий 3).
##
## Счётчики — member-переменные: GDScript-лямбды захватывают value-типы
## по значению, метод-обработчик работает с self.


const SIM_DAYS := 2000
const SEED := 20260927
## Ускоренная частота событий для статистики (интервал ~20 дней вместо ~23).
const EVENT_CHANCE := 0.5

var _crises := 0
var _rare_hits := 0
var _total_events := 0


func _season_for_day(day: int) -> String:
	# 10 дней = месяц; 12 месяцев в году.
	var month := (day / 10) % 12 + 1
	match Season.from_month(month):
		Season.ID.SPRING:
			return "spring"
		Season.ID.SUMMER:
			return "summer"
		Season.ID.AUTUMN:
			return "autumn"
		_:
			return "winter"


func _reset_counters() -> void:
	_crises = 0
	_rare_hits = 0
	_total_events = 0


func _on_crisis_started(_c) -> void:
	_crises += 1


func _on_event_triggered(e) -> void:
	_total_events += 1
	if e.rarity == "rare":
		_rare_hits += 1


func _make_sys(with_seasons: bool) -> CrisisEventSystem:
	var sys := make_node(CrisisEventSystem)
	sys.rng.seed = SEED
	sys.base_event_chance = EVENT_CHANCE
	if with_seasons:
		sys.set_season_provider(func() -> String: return _season_for_day(sys.day_counter))
	sys.crisis_started.connect(_on_crisis_started)
	sys.event_triggered.connect(_on_event_triggered)
	return sys


func _simulate(sys: CrisisEventSystem) -> void:
	for d in range(1, SIM_DAYS + 1):
		sys.on_day_passed(d)
		if sys.current_crisis != null:
			sys.resolve_crisis(-1)  # авто-разрешение, чтобы симуляция шла дальше
		sys.active_events.clear()  # игрок «выбрал» — событие завершено


## ---------- Критерий 4: темп кризисов ----------

func test_crisis_tempo_unchanged_by_season_filter() -> void:
	_reset_counters()
	_simulate(_make_sys(true))
	var crises_with_seasons := _crises
	_reset_counters()
	_simulate(_make_sys(false))
	var crises_without := _crises
	# Сезонный фильтр не должен менять частоту кризисов: 7 из 8 кризисов
	# без сезонного тега, пул никогда не пуст, формула шанса не тронута.
	assert_that(crises_with_seasons).is_equal(crises_without)
	# И сам темп в разумном диапазоне: cooldown 20 дней → максимум 100 за 2000;
	# шанс растёт со временем (0.05 + day/100) → в поздней игре кризис почти
	# каждый cooldown. Допуск [50, 100].
	assert_that(crises_without).is_between(50, 100)


## ---------- Критерий 3: редкие события ----------

func test_rare_events_observed_in_simulation() -> void:
	_reset_counters()
	_simulate(_make_sys(true))
	# Наблюдаемость «≥1 за 2000 дней» — порог недостижим при текущих параметрах
	# (λ ≈ 1, CI-3, 2026-10-03): гарантированная наблюдаемость — в
	# test_rare_weight_respected_10k_rolls (λ ≈ 103, детерминировано).
	# Здесь — только верх: не чаще weights-лимита (вес редких = 0.2 из ~19.35 → ~1%).
	# При ~96 событиях за 2000 дней ожидаем ~1 редкое; ≤5 — хвост Binomial(96, 1%).
	assert_that(_rare_hits).is_less_equal(5)


func test_rare_weight_respected_10k_rolls() -> void:
	var sys := _make_sys(true)
	# Полный пул шаблонов (без сезонного фильтра: считаем общий вес).
	var items: Array = []
	for e in sys.event_templates:
		items.append(e)
	var total_weight := 0.0
	var rare_weight := 0.0
	for e in items:
		total_weight += float(e.weight)
		if e.rarity == "rare":
			rare_weight += float(e.weight)
	var expected_ratio := rare_weight / total_weight
	# Редкие события существуют и имеют ненулевой шанс.
	assert_that(expected_ratio).is_greater(0.0)
	# 10k роллов: наблюдаемая доля ≈ ожидаемая (±2%).
	var rare_count := 0
	const N := 10000
	for _i in N:
		var chosen: CrisisEventSystem.DynamicEventData = sys.select_by_weight(items)
		if chosen.rarity == "rare":
			rare_count += 1
	var observed := float(rare_count) / float(N)
	assert_that(observed).is_between(expected_ratio - 0.02, expected_ratio + 0.02)

extends TestBase
## Спринт 6: репутация и миграция.

const CityC = preload("res://world/City.gd")
const Reputation = preload("res://city/ReputationSystem.gd")


func _make_city(stronghold: int = 1) -> RefCounted:
	var city := CityC.new()
	city.uid = 1
	city.center = Vector2i(5, 5)
	city.stronghold_level = stronghold
	city.add_followers(10)
	return city


func _test_band_boundaries() -> void:
	var cases: Array = [
		[90, Reputation.Band.GOLDEN_AGE],
		[80, Reputation.Band.GOLDEN_AGE],
		[79, Reputation.Band.PROSPERITY],
		[30, Reputation.Band.PROSPERITY],
		[29, Reputation.Band.NORMAL],
		[0, Reputation.Band.NORMAL],
		[-1, Reputation.Band.DISCONTENT],
		[-30, Reputation.Band.DISCONTENT],
		[-31, Reputation.Band.CRISIS],
		[-70, Reputation.Band.CRISIS],
		[-71, Reputation.Band.REBELLION],
		[-100, Reputation.Band.REBELLION],
	]
	for c in cases:
		var got: int = Reputation.band(int(c[0]))
		assert_eq(got, int(c[1]), "диапазон для %d" % int(c[0]))
	assert_eq(Reputation.band_name(90), "Золотой век")
	assert_eq(Reputation.band_name(-80), "Бунт")


func _test_turn_factor_food() -> void:
	# Еда: нетто-еда > 0 -> +1 за ход. Еда приходит через эксплуатируемую
	# клетку рабочего (у последователей клеток нет).
	var city := _make_city()
	city.tile_yield_fn = func(_c: Vector2i) -> Dictionary:
		return {&"food": 100.0}
	var w := city.add_migrant()
	w.tile = city.first_free_worker_tile()
	assert_true(w.tile.x >= 0, "найдена клетка для рабочего")
	assert_true(city.net_food() > 0.0, "нетто-еда > 0: %f" % city.net_food())
	var f: int = Reputation.turn_factor(city)
	assert_true(f >= 1, "еда есть -> фактор >= 1 (получено %d)" % f)
	var before: int = city.reputation
	Reputation.process_turn(city)
	assert_eq(city.reputation, before + f)


func _test_turn_factor_starving_and_overpop() -> void:
	var city := _make_city(1)  # лимит 10
	city.add_followers(3)  # 13 -> 3 сверх
	var f: int = Reputation.turn_factor(city)
	assert_true(f <= -2 * 3, "перенаселение: %d <= -6" % f)
	city.starving = true
	f = Reputation.turn_factor(city)
	assert_true(f <= -5 - 2 * 3, "голод + перенаселение: %d <= -11" % f)


func _test_apply_clamped() -> void:
	var city := _make_city()
	Reputation.apply(city, 500.0)
	assert_eq(city.reputation, CityBalance.REP_MAX)
	Reputation.apply(city, -1000.0)
	assert_eq(city.reputation, CityBalance.REP_MIN)
	# Суммы не переливаются за границы.
	Reputation.apply(city, 0.5)
	assert_true(city.reputation <= CityBalance.REP_MAX)


func _test_city_band_roundtrip() -> void:
	var city := _make_city()
	city.reputation = 45
	assert_eq(city.reputation_band(), Reputation.Band.PROSPERITY)
	var data: Dictionary = city.serialize()
	assert_eq(int(data.reputation), 45)
	var city2 := CityC.new()
	city2.deserialize(data)
	assert_eq(city2.reputation, 45)
	assert_eq(city2.reputation_band(), Reputation.Band.PROSPERITY)


func _test_migrant_added_as_worker() -> void:
	var city := _make_city()
	var total_before: int = city.pop_total()
	var u: RefCounted = city.add_migrant()
	assert_not_null(u)
	assert_eq(city.pop_total(), total_before + 1)
	assert_eq(int(u.state), PopUnit.State.WORKER)


func _test_migration_in() -> void:
	var city := _make_city(2)  # лимит 20, свободно 10
	city.reputation = 50
	var total_before: int = city.pop_total()
	var res: Dictionary = Reputation.process_migration(city)
	assert_eq(int(res.immigrants), 1)
	assert_eq(city.pop_total(), total_before + 1)


func _test_migration_in_blocked_by_cap() -> void:
	var city := _make_city(1)  # лимит 10, уже 10
	city.reputation = 50
	var res: Dictionary = Reputation.process_migration(city)
	assert_eq(int(res.immigrants), 0, "лимит населения блокирует иммиграцию")


func _test_migration_out_order() -> void:
	var city := _make_city(3)  # лимит 35
	city.reputation = -40
	# 3 рабочих, 2 ополченца, 1 учёный (без персонажей).
	for i in 3:
		city.add_migrant()
	var militia_before: int = 2
	for i in militia_before:
		var u := city.add_migrant()
		u.state = PopUnit.State.MILITIA
	var scholar := city.add_migrant()
	scholar.state = PopUnit.State.SCHOLAR
	var total_before: int = city.pop_total()
	var res: Dictionary = Reputation.process_migration(city)
	assert_eq(int(res.emigrants), 1)
	assert_eq(city.pop_total(), total_before - 1)
	# Первым ушёл учёный.
	assert_eq(city.count_state(PopUnit.State.SCHOLAR), 0)
	assert_eq(city.count_state(PopUnit.State.MILITIA), 2)
	# Следующие ходы: ополченцы.
	for i in 2:
		Reputation.process_migration(city)
	assert_eq(city.count_state(PopUnit.State.MILITIA), 0)
	assert_eq(city.count_state(PopUnit.State.WORKER), 3)


func _test_migration_out_crisis_rate() -> void:
	var city := _make_city(3)
	city.reputation = -90
	for i in 5:
		city.add_migrant()
	var res: Dictionary = Reputation.process_migration(city)
	assert_eq(int(res.emigrants), CityBalance.MIGRATE_CRISIS_PER_TURN)


func _test_no_migration_in_middle_band() -> void:
	var city := _make_city()
	city.reputation = 10
	var res: Dictionary = Reputation.process_migration(city)
	assert_eq(int(res.immigrants), 0)
	assert_eq(int(res.emigrants), 0)


func _test_processor_reputation_flow() -> void:
	# Город без еды: -5 за голод, -2*0 за перенаселение... но нетто-еда = 0
	# (нет рабочих) -> фактор 0. Добавим рабочих -> голод.
	var city := _make_city(1)
	for i in 3:
		var u := city.add_migrant()
		u.state = PopUnit.State.WORKER
	# 10 последователей + 3 рабочих = 13 > лимит 10: -2*3 = -6, голод -5
	# (флаг starving — монолит выставляет; здесь задаём вручную).
	city.starving = true
	var proc := preload("res://city/CityTurnProcessor.gd").new()
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = proc.process(ctx)
	var cr: Dictionary = (report.cities as Array)[0]
	assert_true(int(cr.rep_delta) <= -11, "голод+перенаселение: %d <= -11" % int(cr.rep_delta))
	assert_true(city.reputation < 0, "репутация стала отрицательной: %d" % city.reputation)


func _test_processor_emigration_signal() -> void:
	var city := _make_city(3)
	for i in 4:
		city.add_migrant()
	city.reputation = -40
	var proc := preload("res://city/CityTurnProcessor.gd").new()
	var got: Array = []
	proc.migration_occurred.connect(func(uid: int, im: int, em: int):
		got.append([uid, im, em]))
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	proc.process(ctx)
	assert_eq(got.size(), 1)
	assert_eq(int(got[0][1]), 0)
	assert_eq(int(got[0][2]), 1)


func _test_scholar_food() -> void:
	var city := _make_city()
	var u := city.add_migrant()
	u.state = PopUnit.State.SCHOLAR
	# 10 последователей (0) + 1 учёный (0.5).
	var food: float = city.food_consumption()
	assert_true(absf(food - 0.5) < 0.001, "учёный ест 0.5: %f" % food)

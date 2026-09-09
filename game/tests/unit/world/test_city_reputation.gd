extends GdUnitTestSuite

const CityC = preload("res://scripts/world/City.gd")
const Reputation = preload("res://scripts/city/ReputationSystem.gd")

func _make_city(stronghold: int = 1) -> RefCounted:
	var city := CityC.new()
	city.uid = 1
	city.center = Vector2i(5, 5)
	city.stronghold_level = stronghold
	city.add_followers(10)
	return city

func test_band_boundaries() -> void:
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
		assert_that(got).is_equal(int(c[1]))
	assert_that(Reputation.band_name(90)).is_equal("Золотой век")
	assert_that(Reputation.band_name(-80)).is_equal("Бунт")

func test_turn_factor_food() -> void:
	var city := _make_city(2)
	city.tile_yield_fn = func(_c: Vector2i) -> Dictionary:
		return {&"food": 100.0}
	var w: RefCounted = city.add_migrant()
	w.tile = city.first_free_worker_tile()
	assert_bool(w.tile.x >= 0).is_true()
	assert_bool(city.net_food() > 0.0).is_true()
	var f: int = Reputation.turn_factor(city)
	assert_bool(f >= 1).is_true()
	var before: int = city.reputation
	Reputation.process_turn(city)
	assert_that(city.reputation).is_equal(before + f)

func test_turn_factor_starving_and_overpop() -> void:
	var city := _make_city(1)
	city.add_followers(3)
	var f: int = Reputation.turn_factor(city)
	assert_bool(f <= -2 * 3).is_true()
	city.starving = true
	f = Reputation.turn_factor(city)
	assert_bool(f <= -5 - 2 * 3).is_true()

func test_apply_clamped() -> void:
	var city := _make_city()
	Reputation.apply(city, 500.0)
	assert_that(city.reputation).is_equal(GameNumbers.REP_MAX)
	Reputation.apply(city, -1000.0)
	assert_that(city.reputation).is_equal(GameNumbers.REP_MIN)
	Reputation.apply(city, 0.5)
	assert_bool(city.reputation <= GameNumbers.REP_MAX).is_true()

func test_city_band_roundtrip() -> void:
	var city := _make_city()
	city.reputation = 45
	assert_that(city.reputation_band()).is_equal(Reputation.Band.PROSPERITY)
	var data: Dictionary = city.serialize()
	assert_that(int(data.reputation)).is_equal(45)
	var city2 := CityC.new()
	city2.deserialize(data)
	assert_that(city2.reputation).is_equal(45)
	assert_that(city2.reputation_band()).is_equal(Reputation.Band.PROSPERITY)

func test_migrant_added_as_worker() -> void:
	var city := _make_city()
	var total_before: int = city.pop_total()
	var u: RefCounted = city.add_migrant()
	assert_that(u).is_not_null()
	assert_that(city.pop_total()).is_equal(total_before + 1)
	assert_that(int(u.state)).is_equal(PopUnit.State.WORKER)

func test_migration_in() -> void:
	var city := _make_city(2)
	city.reputation = 50
	var total_before: int = city.pop_total()
	var res: Dictionary = Reputation.process_migration(city)
	assert_that(int(res.immigrants)).is_equal(1)
	assert_that(city.pop_total()).is_equal(total_before + 1)

func test_migration_in_blocked_by_cap() -> void:
	var city := _make_city(1)
	city.reputation = 50
	var res: Dictionary = Reputation.process_migration(city)
	assert_that(int(res.immigrants)).is_equal(0)

func test_migration_out_order() -> void:
	var city := _make_city(3)
	city.reputation = -40
	for i in 3:
		city.add_migrant()
	var militia_before: int = 2
	for i in militia_before:
		var u: RefCounted = city.add_migrant()
		u.state = PopUnit.State.MILITIA
	var scholar: RefCounted = city.add_migrant()
	scholar.state = PopUnit.State.SCHOLAR
	var total_before: int = city.pop_total()
	var res: Dictionary = Reputation.process_migration(city)
	assert_that(int(res.emigrants)).is_equal(1)
	assert_that(city.pop_total()).is_equal(total_before - 1)
	assert_that(city.count_state(PopUnit.State.SCHOLAR)).is_equal(0)
	assert_that(city.count_state(PopUnit.State.MILITIA)).is_equal(2)
	for i in 2:
		Reputation.process_migration(city)
	assert_that(city.count_state(PopUnit.State.MILITIA)).is_equal(0)
	assert_that(city.count_state(PopUnit.State.WORKER)).is_equal(3)

func test_migration_out_crisis_rate() -> void:
	var city := _make_city(3)
	city.reputation = -90
	for i in 5:
		city.add_migrant()
	var res: Dictionary = Reputation.process_migration(city)
	assert_that(int(res.emigrants)).is_equal(GameNumbers.MIGRATE_CRISIS_PER_TURN)

func test_no_migration_in_middle_band() -> void:
	var city := _make_city()
	city.reputation = 10
	var res: Dictionary = Reputation.process_migration(city)
	assert_that(int(res.immigrants)).is_equal(0)
	assert_that(int(res.emigrants)).is_equal(0)

func test_processor_reputation_flow() -> void:
	var city := _make_city(1)
	for i in 3:
		var u: RefCounted = city.add_migrant()
		u.state = PopUnit.State.WORKER
	city.starving = true
	var proc := preload("res://scripts/city/CityTurnProcessor.gd").new()
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	var report: Dictionary = proc.process(ctx)
	var cr: Dictionary = (report.cities as Array)[0]
	assert_bool(int(cr.rep_delta) <= -11).is_true()
	assert_bool(city.reputation < 0).is_true()

func test_processor_emigration_signal() -> void:
	var city := _make_city(3)
	for i in 4:
		city.add_migrant()
	city.reputation = -40
	var proc := preload("res://scripts/city/CityTurnProcessor.gd").new()
	var got: Array = []
	proc.migration_occurred.connect(func(uid: int, im: int, em: int):
		got.append([uid, im, em]))
	var ctx := TurnContext.new()
	ctx.cities.append(city)
	proc.process(ctx)
	assert_that(got.size()).is_equal(1)
	assert_that(int(got[0][1])).is_equal(0)
	assert_that(int(got[0][2])).is_equal(1)

func test_scholar_food() -> void:
	var city := _make_city()
	var u: RefCounted = city.add_migrant()
	u.state = PopUnit.State.SCHOLAR
	var food: float = city.food_consumption()
	assert_bool(absf(food - 0.5) < 0.001).is_true()

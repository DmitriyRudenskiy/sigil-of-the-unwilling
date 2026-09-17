extends BaseTest

# social-systems-delta D4: негативные события низкой харизмы

const CharismaEvents = preload("res://scripts/systems/CharismaEvents.gd")

func _city_with_pop(n: int = 3) -> City:
	var c := City.new()
	for i in n:
		var u := PopUnit.new()
		u.state = PopUnit.State.WORKER
		c.pop.append(u)
	return c

func _city_with_militia() -> City:
	var c := _city_with_pop(2)
	var u := PopUnit.new()
	u.state = PopUnit.State.MILITIA
	c.pop.append(u)
	return c

func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

func test_no_leader_no_events() -> void:
	var out := CharismaEvents.process(_city_with_pop(), -1)
	assert_that(str(out.event)).is_equal("")
	assert_bool(not bool(out.needs_incentives))

func test_cha_7_needs_incentives() -> void:
	var out := CharismaEvents.process(_city_with_pop(), 7)
	assert_bool(bool(out.needs_incentives))
	assert_that(str(out.event)).is_equal("")

func test_cha_6_needs_incentives() -> void:
	var out := CharismaEvents.process(_city_with_pop(), 6)
	assert_bool(bool(out.needs_incentives))

func test_cha_5_morale_penalty() -> void:
	var out := CharismaEvents.process(_city_with_pop(), 5)
	assert_int(int(out.morale)).is_equal(-1)
	assert_that(str(out.event)).is_equal("")

func test_cha_4_morale_penalty() -> void:
	var out := CharismaEvents.process(_city_with_pop(), 4)
	assert_int(int(out.morale)).is_equal(-1)

func test_cha_3_mutiny_rolls_deterministic() -> void:
	# детерминизм: тот же seed — тот же исход
	CharismaEvents.set_rng(_rng(42))
	var c1 := _city_with_militia()
	var a: Dictionary = CharismaEvents.process(c1, 3)
	CharismaEvents.set_rng(_rng(42))
	var c2 := _city_with_militia()
	var b: Dictionary = CharismaEvents.process(c2, 3)
	assert_that(str(a.event)).is_equal(str(b.event))
	assert_int(c1.pop.size()).is_equal(c2.pop.size())

func test_cha_2_event_reduces_pop() -> void:
	# 20 сидов: при DC 18 (~11%) хотя бы один бунт/побег случится
	var reduced: bool = false
	for seed in 20:
		CharismaEvents.set_rng(_rng(seed))
		var c := _city_with_militia()
		var before: int = c.pop.size()
		var out: Dictionary = CharismaEvents.process(c, 2)
		if str(out.event) != "" and c.pop.size() < before:
			reduced = true
			break
	assert_bool(reduced).override_failure_message("ни один из 20 сидов не дал событие")

func test_desertion_removes_militia() -> void:
	# найти сид с desertion
	var found: bool = false
	for seed in 30:
		CharismaEvents.set_rng(_rng(seed))
		var c := _city_with_militia()
		var out: Dictionary = CharismaEvents.process(c, 1)
		if str(out.event) == "desertion":
			found = true
			assert_int(c.count_state(PopUnit.State.MILITIA)).is_equal(0)
			assert_int(c.count_state(PopUnit.State.WORKER)).is_equal(2)
			break
	assert_bool(found).override_failure_message("desertion не случился за 30 сидов")

func test_flight_removes_worker() -> void:
	var found: bool = false
	for seed in 30:
		CharismaEvents.set_rng(_rng(seed))
		var c := _city_with_pop(3)
		var out: Dictionary = CharismaEvents.process(c, 1)
		if str(out.event) == "flight":
			found = true
			assert_int(c.pop.size()).is_equal(2)
			break
	assert_bool(found).override_failure_message("flight не случился за 30 сидов")

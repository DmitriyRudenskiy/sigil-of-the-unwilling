extends BaseTest






var city: Variant
var reg: Variant
var proc: Variant
var born: Array = []
var died: Array = []
var crit: Array = []
var outbreak: Array = []

func before_test() -> void:
	city = City.new()
	city.center = Vector2i(5, 5)
	city.uid = 100
	reg = CharacterRegistry.new()
	proc = DemographicTurnProcessor.new()
	proc.setup(reg)
	born = []
	died = []
	crit = []
	outbreak = []
	proc.character_born.connect(
		func(uid: int, cuid: int, name: String): born.append({"uid": uid, "city": cuid, "name": name}))
	proc.character_died.connect(
		func(uid: int, cuid: int, cause: StringName): died.append({"uid": uid, "city": cuid, "cause": cause}))
	proc.character_need_critical.connect(
		func(uid: int, need: int): crit.append({"uid": uid, "need": need}))
	proc.disease_outbreak.connect(
		func(cuid: int, uid: int): outbreak.append({"city": cuid, "uid": uid}))

func _ctx(turn: int) -> TurnContext:
	var ctx := TurnContext.new()
	ctx.turn_number = turn
	ctx.cities = [city]
	return ctx

func _clear_traits() -> void:
	for ch in reg.alive_in_city(city.uid):
		(ch as Character).traits.clear()

func _chars() -> Array:
	return reg.alive_in_city(city.uid)

func test_phase_id_and_priority() -> void:
	assert_that(proc.get_phase_id()).is_equal(&"demographics")
	assert_that(proc.get_priority()).is_equal(20)

func test_without_registry_empty_report() -> void:
	var p2 := DemographicTurnProcessor.new()
	var report: Dictionary = p2.process(_ctx(1))
	assert_that(int(report.get("ensured", -1))).is_equal(0)
	assert_bool((report.get("cities", []) as Array).is_empty()).is_true()

func test_report_shape() -> void:
	city.add_followers(2)
	var report: Dictionary = proc.process(_ctx(1))
	assert_bool(report.has("ensured")).is_true()
	assert_bool(report.has("critical")).is_true()
	assert_bool(report.has("deaths")).is_true()
	assert_bool(report.has("outbreaks")).is_true()
	assert_that((report["cities"] as Array).size()).is_equal(1)
	assert_that(int((report["cities"][0] as Dictionary).get("uid", -1))).is_equal(city.uid)

func test_lazy_character_creation() -> void:
	city.add_followers(3)
	var report: Dictionary = proc.process(_ctx(1))
	assert_that(int(report["ensured"])).is_equal(3)
	assert_that(born.size()).is_equal(3)
	assert_that(reg.all().size()).is_equal(3)
	for pop in city.pop:
		assert_bool(pop.character_uid >= 0).is_true()
		var ch: Character = reg.get_by_uid(pop.character_uid)
		assert_that(ch).is_not_null()
		assert_that(ch.pop_uid).is_equal(pop.uid)

func test_no_double_creation() -> void:
	city.add_followers(2)
	proc.process(_ctx(1))
	var report: Dictionary = proc.process(_ctx(2))
	assert_that(int(report["ensured"])).is_equal(0)
	assert_that(born.size()).is_equal(2)
	assert_that(reg.all().size()).is_equal(2)

func test_new_pop_next_turn_gets_character() -> void:
	city.add_followers(1)
	proc.process(_ctx(1))
	city.add_followers(1)
	proc.process(_ctx(2))
	assert_that(reg.all().size()).is_equal(2)

func test_fed_city_needs_stable() -> void:
	city.add_followers(3)
	proc.process(_ctx(1))
	_clear_traits()
	var ch: Character = _chars()[0]
	var rest_before: float = ch.needs[NeedType.ID.REST]
	proc.process(_ctx(2))
	assert_bool(ch.needs[NeedType.ID.REST] >= rest_before).is_true()
	assert_bool(ch.needs[NeedType.ID.SOCIAL] >= 0.7).is_true()

func test_trait_slow_rest_recovery() -> void:
	city.add_followers(3)
	proc.process(_ctx(1))
	_clear_traits()
	var ch: Character = _chars()[0]
	var jaded := TraitDef.new()
	jaded.id = &"test_jaded"
	jaded.effect_type = &"rest"
	jaded.effect_value = -0.2
	ch.traits = [jaded]
	ch.needs[NeedType.ID.REST] = 0.8
	ch.need_zero_streak[NeedType.ID.REST] = 0
	proc.process(_ctx(2))
	assert_bool(absf(ch.needs[NeedType.ID.REST] - 0.62) < 0.001).is_true()

func test_critical_signal_once_per_episode() -> void:
	city.add_followers(3)
	proc.process(_ctx(1))
	var ch: Character = _chars()[0]
	ch.traits.clear()
	for character in _chars():
		if character != ch:
			character.traits.clear()
	ch.needs[NeedType.ID.REST] = 0.15
	ch.need_zero_streak[NeedType.ID.REST] = 0
	proc.process(_ctx(2))
	assert_that(crit.size()).is_equal(1)
	assert_that(crit[0]["need"]).is_equal(NeedType.ID.REST)
	assert_that(int(crit[0]["uid"])).is_equal(ch.uid)
	proc.process(_ctx(3))
	assert_that(crit.size()).is_equal(1)
	ch.needs[NeedType.ID.REST] = 0.9
	ch.need_zero_streak[NeedType.ID.REST] = 0
	proc.process(_ctx(4))
	assert_that(crit.size()).is_equal(1)
	ch.needs[NeedType.ID.REST] = 0.05
	ch.need_zero_streak[NeedType.ID.REST] = 0
	proc.process(_ctx(5))
	assert_that(crit.size()).is_equal(2)

func test_death_by_isolation() -> void:
	city.add_followers(1)
	proc.process(_ctx(1))
	var ch: Character = _chars()[0]
	ch.traits.clear()
	ch.needs[NeedType.ID.SOCIAL] = 0.0
	var pop_before: int = city.pop.size()
	proc.process(_ctx(2))
	proc.process(_ctx(3))
	assert_that(died.size()).is_equal(0)
	proc.process(_ctx(4))
	assert_that(died.size()).is_equal(1)
	assert_that(died[0]["cause"]).is_equal(&"isolation")
	assert_that(int(died[0]["uid"])).is_equal(ch.uid)
	assert_that(int(died[0]["city"])).is_equal(city.uid)
	assert_bool(ch.alive).is_false()
	assert_that(city.pop.size()).is_equal(pop_before - 1)
	assert_that(reg.get_by_pop(ch.pop_uid)).is_null()
	assert_that(reg.get_by_uid(ch.uid)).is_not_null()

func test_no_death_without_zero_streak() -> void:
	city.add_followers(1)
	proc.process(_ctx(1))
	var ch: Character = _chars()[0]
	ch.traits.clear()
	ch.needs[NeedType.ID.REST] = 0.1
	ch.need_zero_streak[NeedType.ID.REST] = 2
	proc.process(_ctx(2))
	assert_that(died.size()).is_equal(0)
	assert_that(ch.need_zero_streak[NeedType.ID.REST]).is_equal(0)

func test_outbreak_triggered_and_cooldown() -> void:
	city.add_followers(4)
	proc.process(_ctx(1))
	_clear_traits()
	var chars: Array = _chars()
	chars[0].needs[NeedType.ID.REST] = 0.05
	chars[0].needs[NeedType.ID.SOCIAL] = 0.05
	chars[1].needs[NeedType.ID.REST] = 0.05
	chars[1].needs[NeedType.ID.SOCIAL] = 0.05
	var report: Dictionary = proc.process(_ctx(2))
	assert_that(int(report["outbreaks"])).is_equal(2)
	assert_that(outbreak.size()).is_equal(2)
	assert_that(outbreak[0]["city"]).is_equal(city.uid)
	var c0: Character = chars[0]
	assert_bool(c0.needs[NeedType.ID.INSPIRATION] < 0.75).is_true()
	chars[1].needs[NeedType.ID.REST] = 0.05
	chars[1].needs[NeedType.ID.SOCIAL] = 0.05
	proc.process(_ctx(3))
	assert_that(outbreak.size()).is_equal(2)

func test_no_outbreak_with_single_weak_character() -> void:
	city.add_followers(4)
	proc.process(_ctx(1))
	_clear_traits()
	var chars: Array = _chars()
	chars[0].needs[NeedType.ID.REST] = 0.05
	chars[0].needs[NeedType.ID.SOCIAL] = 0.05
	proc.process(_ctx(2))
	assert_that(outbreak.size()).is_equal(0)

func test_outbreak_in_small_city_threshold_one() -> void:
	city.add_followers(3)
	proc.process(_ctx(1))
	_clear_traits()
	var chars: Array = _chars()
	chars[0].needs[NeedType.ID.REST] = 0.05
	chars[0].needs[NeedType.ID.SOCIAL] = 0.05
	var report: Dictionary = proc.process(_ctx(2))
	assert_that(int(report["outbreaks"])).is_equal(1)
	assert_that(outbreak.size()).is_equal(1)

func test_through_scheduler() -> void:
	var sched := TurnScheduler.new()
	sched.register_processor(proc)
	city.add_followers(2)
	var ctx := TurnContext.new()
	ctx.cities = [city]
	var report: Dictionary = sched.execute_turn(ctx)
	var phases: Dictionary = report["phases"]
	assert_bool(phases.has(&"demographics")).is_true()
	assert_that(int((phases[&"demographics"] as Dictionary)["ensured"])).is_equal(2)

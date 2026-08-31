extends "res://tests/test_base.gd"
## M2: DemographicTurnProcessor — персонажи для фигурок, тик потребностей,
## критика, смерти от истощения, эпидемии. Город создаётся вручную;
## city.process_turn() здесь НЕ вызывается (монолит — отдельный контур).

const _City = preload("res://scripts/world/City.gd")
const _Processor = preload("res://scripts/demographics/DemographicTurnProcessor.gd")
const _Registry = preload("res://scripts/demographics/CharacterRegistry.gd")
const _Character = preload("res://scripts/demographics/Character.gd")
const _TraitDef = preload("res://scripts/demographics/TraitDef.gd")

var city: Variant
var reg: Variant
var proc: Variant
var born: Array = []
var died: Array = []
var crit: Array = []
var outbreak: Array = []


func before_each() -> void:
	city = _City.new()
	city.center = Vector2i(5, 5)
	city.uid = 100
	reg = _Registry.new()
	proc = _Processor.new()
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
		func(uid: int, need: StringName): crit.append({"uid": uid, "need": need}))
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


# ==================== БАЗА ====================

func test_phase_id_and_priority() -> void:
	assert_eq(proc.get_phase_id(), &"demographics", "phase id")
	assert_eq(proc.get_priority(), 20, "after economy (10)")


func test_without_registry_empty_report() -> void:
	var p2 := _Processor.new()
	var report: Dictionary = p2.process(_ctx(1))
	assert_eq(int(report.get("ensured", -1)), 0, "ensured 0")
	assert_true((report.get("cities", []) as Array).is_empty(), "no cities")


func test_report_shape() -> void:
	city.add_followers(2)
	var report: Dictionary = proc.process(_ctx(1))
	assert_true(report.has("ensured"), "ensured key")
	assert_true(report.has("critical"), "critical key")
	assert_true(report.has("deaths"), "deaths key")
	assert_true(report.has("outbreaks"), "outbreaks key")
	assert_eq((report["cities"] as Array).size(), 1, "1 city entry")
	assert_eq(int((report["cities"][0] as Dictionary).get("uid", -1)), city.uid, "city uid in entry")


# ==================== СОЗДАНИЕ ПЕРСОНАЖЕЙ ====================

func test_lazy_character_creation() -> void:
	city.add_followers(3)
	var report: Dictionary = proc.process(_ctx(1))
	assert_eq(int(report["ensured"]), 3, "3 ensured")
	assert_eq(born.size(), 3, "3 character_born signals")
	assert_eq(reg.all().size(), 3, "3 characters")
	for pop in city.pop:
		assert_true(pop.character_uid >= 0, "pop linked")
		var ch: Character = reg.get_by_uid(pop.character_uid)  # get() = Object.get
		assert_not_null(ch, "character exists")
		assert_eq(ch.pop_uid, pop.uid, "pop uid matches")


func test_no_double_creation() -> void:
	city.add_followers(2)
	proc.process(_ctx(1))
	var report: Dictionary = proc.process(_ctx(2))
	assert_eq(int(report["ensured"]), 0, "no new characters on 2nd turn")
	assert_eq(born.size(), 2, "still 2 born signals")
	assert_eq(reg.all().size(), 2, "still 2 characters")


func test_new_pop_next_turn_gets_character() -> void:
	city.add_followers(1)
	proc.process(_ctx(1))
	city.add_followers(1)
	proc.process(_ctx(2))
	assert_eq(reg.all().size(), 2, "new pop got character")


# ==================== ТИК ПОТРЕБНОСТЕЙ ====================

func test_fed_city_needs_stable() -> void:
	city.add_followers(3)
	proc.process(_ctx(1))
	_clear_traits()
	var ch: Character = _chars()[0]
	var hunger_before: float = ch.needs[&"hunger"]
	var rest_before: float = ch.needs[&"rest"]
	proc.process(_ctx(2))
	assert_true(ch.needs[&"hunger"] >= hunger_before, "hunger not worse in fed city")
	assert_true(ch.needs[&"rest"] >= rest_before, "rest not worse (follower rhythm)")
	assert_true(ch.needs[&"social"] >= 0.7, "social ok with 3 pop")


func test_starving_city_hunger_decays() -> void:
	city.add_followers(3)
	proc.process(_ctx(1))
	city.starving = true
	_clear_traits()
	var ch: Character = _chars()[0]
	ch.needs[&"hunger"] = 0.8
	ch.need_zero_streak[&"hunger"] = 0
	proc.process(_ctx(2))
	## 0.8 - 0.15 (распад) - 0.10 (голод) = 0.55
	assert_true(absf(ch.needs[&"hunger"] - 0.55) < 0.001, "hunger 0.55 (got %f)" % ch.needs[&"hunger"])


func test_trait_speeds_starvation() -> void:
	city.add_followers(3)
	proc.process(_ctx(1))
	city.starving = true
	_clear_traits()
	var ch: Character = _chars()[0]
	var glutton := _TraitDef.new()
	glutton.id = &"test_glutton"
	glutton.effect_type = &"hunger"
	glutton.effect_value = -0.2
	ch.traits = [glutton]
	ch.needs[&"hunger"] = 0.8
	ch.need_zero_streak[&"hunger"] = 0
	proc.process(_ctx(2))
	## 0.8 - 0.15 - 0.10 - 0.20 (черта) = 0.35
	assert_true(absf(ch.needs[&"hunger"] - 0.35) < 0.001, "hunger 0.35 with trait (got %f)" % ch.needs[&"hunger"])


# ==================== КРИТИКА ====================

func test_critical_signal_once_per_episode() -> void:
	# 3 жителя: social стабилизируется (компания есть), иначе в одиночестве
	# social упал бы в критику и добавил бы лишние сигналы.
	city.add_followers(3)
	proc.process(_ctx(1))
	city.starving = true
	var ch: Character = _chars()[0]
	ch.traits.clear()
	for c in _chars():
		if c != ch:
			c.traits.clear()
	ch.needs[&"hunger"] = 0.15
	ch.need_zero_streak[&"hunger"] = 0
	proc.process(_ctx(2))
	assert_eq(crit.size(), 1, "one critical signal")
	assert_eq(crit[0]["need"], &"hunger", "hunger critical")
	assert_eq(int(crit[0]["uid"]), ch.uid, "character uid")
	proc.process(_ctx(3))
	assert_eq(crit.size(), 1, "no repeat while still critical")
	# Восстановление -> новый эпизод -> новый сигнал.
	ch.needs[&"hunger"] = 0.9
	ch.need_zero_streak[&"hunger"] = 0
	city.starving = false
	proc.process(_ctx(4))
	assert_eq(crit.size(), 1, "recovered, no signal")
	ch.needs[&"hunger"] = 0.1
	ch.need_zero_streak[&"hunger"] = 0
	proc.process(_ctx(5))
	assert_eq(crit.size(), 2, "new episode -> new signal")


# ==================== СМЕРТИ ====================

func test_death_by_starvation() -> void:
	city.add_followers(1)
	proc.process(_ctx(1))
	city.starving = true
	var ch: Character = _chars()[0]
	ch.traits.clear()
	ch.needs[&"hunger"] = 0.0
	var pop_before: int = city.pop.size()
	proc.process(_ctx(2))
	proc.process(_ctx(3))
	assert_eq(died.size(), 0, "not dead after 2 zero turns")
	proc.process(_ctx(4))
	assert_eq(died.size(), 1, "dead after 3 zero turns")
	assert_eq(died[0]["cause"], &"starvation", "cause starvation")
	assert_eq(int(died[0]["uid"]), ch.uid, "right character")
	assert_eq(int(died[0]["city"]), city.uid, "right city")
	assert_false(ch.alive, "character marked dead")
	assert_eq(city.pop.size(), pop_before - 1, "pop removed from city")
	assert_null(reg.get_by_pop(ch.pop_uid), "pop link removed")
	assert_not_null(reg.get_by_uid(ch.uid), "tombstone kept")


func test_no_death_without_zero_streak() -> void:
	city.add_followers(1)
	proc.process(_ctx(1))
	var ch: Character = _chars()[0]
	ch.traits.clear()
	ch.needs[&"hunger"] = 0.1
	ch.need_zero_streak[&"hunger"] = 2  # было 2, но ход не нулевой
	proc.process(_ctx(2))
	## 0.1 - 0.15 + 0.20 = 0.15 > 0 → streak сбросился
	assert_eq(died.size(), 0, "alive (streak reset)")
	assert_eq(ch.need_zero_streak[&"hunger"], 0, "streak reset to 0")


# ==================== ЭПИДЕМИИ ====================

func test_outbreak_triggered_and_cooldown() -> void:
	city.add_followers(4)
	proc.process(_ctx(1))
	_clear_traits()
	var chars: Array = _chars()
	chars[0].needs[&"hunger"] = 0.05
	chars[0].needs[&"rest"] = 0.05
	chars[1].needs[&"hunger"] = 0.05
	chars[1].needs[&"rest"] = 0.05
	# Город сыт: hunger 0.05 -> 0.10, rest 0.05 -> 0.07 (оба < 0.2)
	var report: Dictionary = proc.process(_ctx(2))
	assert_eq(int(report["outbreaks"]), 2, "2 affected in outbreak")
	assert_eq(outbreak.size(), 2, "2 disease_outbreak signals")
	assert_eq(outbreak[0]["city"], city.uid, "city uid in signal")
	# Поражённые получили штраф.
	var c0: Character = chars[0]
	assert_true(c0.needs[&"inspiration"] < 0.75, "inspiration penalty applied")
	# Каллдаун: повторное состояние, но меньше 5 ходов с эпидемии.
	chars[1].needs[&"hunger"] = 0.05
	chars[1].needs[&"rest"] = 0.05
	proc.process(_ctx(3))
	assert_eq(outbreak.size(), 2, "cooldown blocks 2nd outbreak")


func test_no_outbreak_with_single_weak_character() -> void:
	city.add_followers(4)
	proc.process(_ctx(1))
	_clear_traits()
	var chars: Array = _chars()
	# Только один персонаж с критикой (нужны 2+ при населении 4+).
	chars[0].needs[&"hunger"] = 0.05
	chars[0].needs[&"rest"] = 0.05
	proc.process(_ctx(2))
	assert_eq(outbreak.size(), 0, "no outbreak: only 1 critical char")


func test_outbreak_in_small_city_threshold_one() -> void:
	city.add_followers(3)
	proc.process(_ctx(1))
	_clear_traits()
	var chars: Array = _chars()
	# Город < 4: порог 1 персонаж с 2+ критическими потребностями.
	chars[0].needs[&"hunger"] = 0.05
	chars[0].needs[&"rest"] = 0.05
	var report: Dictionary = proc.process(_ctx(2))
	assert_eq(int(report["outbreaks"]), 1, "small city: 1 affected")
	assert_eq(outbreak.size(), 1, "signal emitted")


# ==================== ЧЕРЕЗ ПЛАНИРОВЩИК ====================

func test_through_scheduler() -> void:
	var sched := TurnScheduler.new()
	sched.register_processor(proc)
	city.add_followers(2)
	var ctx := TurnContext.new()
	ctx.cities = [city]
	var report: Dictionary = sched.execute_turn(ctx)
	var phases: Dictionary = report["phases"]
	assert_true(phases.has(&"demographics"), "phase in report")
	assert_eq(int((phases[&"demographics"] as Dictionary)["ensured"]), 2, "ensured via scheduler")

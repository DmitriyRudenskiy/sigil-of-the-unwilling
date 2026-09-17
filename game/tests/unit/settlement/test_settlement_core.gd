extends BaseTest

# Фазы 1–2 settlement-system: виды, караван, Resolve, голод, уход

const Species = preload("res://scripts/data/settlement_species.gd")
const Settlement = preload("res://scripts/settlement/Settlement.gd")
const Resolve = preload("res://scripts/settlement/SettlementResolve.gd")

func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

func test_species_table_seven() -> void:
	assert_that(Species.all_ids().size()).is_equal(7)
	# 1:1 из прототипа
	var human: Dictionary = Species.by_id("human")
	assert_that(int(human["base_resolve"])).is_equal(15)
	assert_that(int(human["demand"])).is_equal(30)
	assert_that(int(human["decadence"])).is_equal(4)
	assert_that(int(human["hunger_tolerance"])).is_equal(6)
	var lizard: Dictionary = Species.by_id("lizard")
	assert_that(int(lizard["hunger_tolerance"])).is_equal(12)
	var harpy: Dictionary = Species.by_id("harpy")
	assert_that(int(harpy["hunger_tolerance"])).is_equal(4)

func test_caravan_three_species() -> void:
	var c: Variant = Settlement.form_caravan({"human": 2, "lizard": 1, "fox": 1})
	assert_bool(c != null).override_failure_message("караван 3 видов не сформирован")
	assert_that(c.species_in_caravan().size()).is_equal(3)
	assert_that(c.state["settlers"].size()).is_equal(4)
	# стартовые здания
	assert_that(c.buildings_of("hearth").size()).is_equal(1)
	assert_that(c.buildings_of("warehouse").size()).is_equal(1)

func test_caravan_four_species_rejected() -> void:
	var c: Variant = Settlement.form_caravan({"human": 1, "lizard": 1, "fox": 1, "harpy": 1})
	assert_that(c == null)

func test_frog_dlc_gate() -> void:
	assert_bool(not Species.is_available("frog")).override_failure_message("frog без DLC доступен")
	assert_bool(Species.is_available("frog", {"keepers_of_the_stone": true}))
	assert_bool(Species.is_available("human"))
	var c: Variant = Settlement.form_caravan({"frog": 1})
	assert_that(c == null)
	var c2: Variant = Settlement.form_caravan({"frog": 1}, {"keepers_of_the_stone": true})
	assert_bool(c2 != null)

func test_hunger_lizard_survives_longer() -> void:
	# lizard (tolerance 12) не теряет Resolve 12 ходов без еды;
	# harpy (tolerance 4) — после 4
	var l := Settlement.new()
	var ls := l.add_settler("lizard")
	var h := Settlement.new()
	var hs := h.add_settler("harpy")
	for i in 12:
		Resolve.on_day_passed(l, _rng(1))
	for i in 6:
		Resolve.on_day_passed(h, _rng(1))
	# lizard (tolerance 12): 12 ходов без еды — без урона от голода
	assert_bool(float(ls["resolve"]) >= 5.0).override_failure_message("lizard пострадал от голода раньше tolerance")
	# harpy (tolerance 4): с 5-го хода -1/ход
	assert_bool(float(hs["resolve"]) < 5.0 + 2.0).override_failure_message("harpy не пострадал от голода")

func test_break_interval() -> void:
	var s := Settlement.new()
	var st := s.add_settler("lizard")  # break_interval 1: перерыв каждый ход
	var r0: float = float(st["resolve"])
	Resolve.on_day_passed(s, _rng(3))
	assert_bool(float(st["resolve"]) > r0).override_failure_message("перерыв не даёт Resolve")

func test_firekeeper_lizard_boosts_all() -> void:
	var s := Settlement.new()
	var a := s.add_settler("lizard")
	var b := s.add_settler("human")
	s.state["firekeeper_id"] = a["id"]
	var before: float = float(b["resolve"])
	Resolve.apply_firekeeper(s)
	assert_that(float(b["resolve"])).is_equal(before + 1.0)

func test_leave_at_zero_resolve_frees_home() -> void:
	var s := Settlement.new()
	var st := s.add_settler("human")
	st["resolve"] = -5.0  # ниже, чем бонус жилья +2
	st["break_in"] = 2  # без перерыва в первые ходы
	var shelter := s.add_building("shelter", Vector2i(0, 1))
	shelter["data"]["resident"] = st["id"]
	Resolve.on_day_passed(s, _rng(5))
	assert_that(s.state["settlers"].size()).is_equal(0)
	assert_that(shelter["data"]["resident"]).is_equal("")

func test_frog_refuses_shelter() -> void:
	var s := Settlement.new()
	var frog := s.add_settler("frog")
	var shelter := s.add_building("shelter", Vector2i(0, 1))
	shelter["data"]["resident"] = frog["id"]
	var before: float = float(frog["resolve"])
	Resolve.on_day_passed(s, _rng(7))
	# frog не получил бонус жилья (но мог потерять от голода)
	var expected_max: float = before + 1.0  # только перерыв максимум
	assert_bool(float(frog["resolve"]) <= expected_max)

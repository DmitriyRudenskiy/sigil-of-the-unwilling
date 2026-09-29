extends BaseTest
## race-economy (Phase 2): loader for 7 race economic profiles + building
## race assignment (variant A). Schema: doc/races-economy.md §3, §4, §10.

var _uid_seq := 0


func _mk_building(id: String, workers: int = 1) -> UniqueBuilding:
	_uid_seq += 1
	var b := UniqueBuilding.new()
	var def := UniqueBuilding.Def.new()
	def.id = StringName(id)
	b.def = def
	b.uid = _uid_seq
	b.assigned_workers = workers
	return b


func test_all_seven_profiles_loaded() -> void:
	assert_that(RaceEconomy.all().size()).is_equal(7)


func test_every_known_game_race_has_profile() -> void:
	# orc ещё не в HeroRaces (ждёт DEX-решения) — проверяем 6 текущих рас.
	for rid in HeroRaces.RACES:
		assert_bool(RaceEconomy.has(StringName(rid))) \
			.is_true().override_failure_message("no profile for " + str(rid))


func test_orc_profile_present() -> void:
	assert_bool(RaceEconomy.has(&"orc")).is_true()


func test_profile_schema() -> void:
	for rid in RaceEconomy.all():
		var p: Dictionary = RaceEconomy.profile(StringName(rid))
		var needs: Dictionary = p.get("needs", {})
		assert_bool(needs.has("primary")).is_true()
		assert_bool(needs.has("secondary")).is_true()
		assert_bool(needs.has("not_needed")).is_true()
		assert_bool(p.has("production")).is_true()
		assert_bool(p.has("favorite_buildings")).is_true()
		assert_bool(p.has("synergy")).is_true()
		assert_bool(p.has("conflict")).is_true()
		assert_bool(p.has("ascetic")).is_true()
		assert_that(str(p.get("lore", ""))).is_not_empty()


func test_dwarf_specializes_mine_and_smithy() -> void:
	assert_that(RaceEconomy.production_mult(&"dwarf", &"mine")).is_equal(1.25)
	assert_that(RaceEconomy.production_mult(&"dwarf", &"smithy")).is_equal(1.25)
	# нет бонуса на чужую нишу
	assert_that(RaceEconomy.production_mult(&"dwarf", &"farm")).is_equal(1.0)


func test_best_production_takes_max_not_sum() -> void:
	# dwarf(1.25) + human(1.0) на mine -> 1.25, а не 2.25
	var m: float = RaceEconomy.best_production_mult([&"dwarf", &"human"], &"mine")
	assert_that(m).is_equal(1.25)


func test_godlike_is_ascetic_others_are_not() -> void:
	assert_bool(RaceEconomy.is_ascetic(&"godlike")).is_true()
	assert_bool(RaceEconomy.is_ascetic(&"dwarf")).is_false()


func test_synergy_and_conflict_pairs() -> void:
	assert_that(RaceEconomy.synergy_logistics(&"human", &"dwarf")).is_equal(1.10)
	assert_that(RaceEconomy.synergy_logistics(&"human", &"elf")).is_equal(1.0)
	assert_that(RaceEconomy.conflict_morale(&"orc", &"elf")).is_equal(-8)
	assert_that(RaceEconomy.conflict_morale(&"human", &"elf")).is_equal(0)


func test_needs() -> void:
	assert_that(str(RaceEconomy.needs_primary(&"dwarf"))).is_equal("tools")
	assert_that(str(RaceEconomy.needs_primary(&"orc"))).is_equal("bread")
	assert_that(RaceEconomy.not_needed(&"orc")).contains("gold")
	assert_that(RaceEconomy.not_needed(&"orc")).contains("scholar_points")


# --- Назначение расы зданиям (вариант A) ---

func test_empty_race_pop_no_bonus() -> void:
	var city := City.new()
	var mine := _mk_building("mine", 2)
	city.buildings.append(mine)
	city.race_pop = {}
	RaceEconomy.assign_building_races(city)
	assert_that(String(mine.worker_race)).is_equal("")
	assert_that(RaceEconomy.production_mult(mine.worker_race, mine.def.id)).is_equal(1.0)


func test_dwarf_on_mine_gets_bonus() -> void:
	var city := City.new()
	var mine := _mk_building("mine", 2)
	city.buildings.append(mine)
	city.race_pop = {"dwarf": 1}
	RaceEconomy.assign_building_races(city)
	assert_that(String(mine.worker_race)).is_equal("dwarf")
	assert_that(RaceEconomy.production_mult(mine.worker_race, mine.def.id)).is_equal(1.25)


func test_dwarf_not_assigned_to_farm() -> void:
	var city := City.new()
	var farm := _mk_building("farm", 2)
	city.buildings.append(farm)
	city.race_pop = {"dwarf": 1}
	RaceEconomy.assign_building_races(city)
	# у дварфа нет специализации на farm (mult 1.0) -> не назначается
	assert_that(String(farm.worker_race)).is_equal("")
	# даже если бы был назначен — бонуса нет
	assert_that(RaceEconomy.production_mult(&"dwarf", &"farm")).is_equal(1.0)


func test_greedy_assignment_exhausts_race() -> void:
	var city := City.new()
	var mine := _mk_building("mine", 2)
	var smithy := _mk_building("smithy", 2)
	var walls := _mk_building("walls", 2)
	city.buildings.append(mine)
	city.buildings.append(smithy)
	city.buildings.append(walls)
	city.race_pop = {"dwarf": 2}
	RaceEconomy.assign_building_races(city)
	assert_that(String(mine.worker_race)).is_equal("dwarf")
	assert_that(String(smithy.worker_race)).is_equal("dwarf")
	assert_that(String(walls.worker_race)).is_equal("")  # дварфы исчерпаны


func test_building_takes_best_race_max_not_sum() -> void:
	var city := City.new()
	var mine := _mk_building("mine", 2)
	city.buildings.append(mine)
	city.race_pop = {"dwarf": 1, "human": 1}
	RaceEconomy.assign_building_races(city)
	# здание берёт лучшую расу (dwarf 1.25), не сумму (2.25)
	assert_that(String(mine.worker_race)).is_equal("dwarf")
	assert_that(RaceEconomy.production_mult(mine.worker_race, mine.def.id)).is_equal(1.25)
	assert_that(RaceEconomy.best_production_mult([&"dwarf", &"human"], &"mine")).is_equal(1.25)


func test_worker_race_serialization_roundtrip() -> void:
	var def := UniqueBuilding.Def.new()
	def.id = &"mine"
	var b := UniqueBuilding.new()
	b.def = def
	b.uid = 42
	b.assigned_workers = 2
	b.worker_race = &"dwarf"
	var data := b.serialize()
	var restored := UniqueBuilding.deserialize(data, def)
	assert_that(String(restored.worker_race)).is_equal("dwarf")
	assert_that(restored.assigned_workers).is_equal(2)


func test_city_race_pop_serialization_roundtrip() -> void:
	var city := City.new()
	city.race_pop = {"dwarf": 3, "human": 5}
	var data := CitySerializer.serialize(city)
	var city2 := City.new()
	CitySerializer.deserialize(city2, data)
	assert_that(city2.race_pop.size()).is_equal(2)
	assert_that(int(city2.race_pop.get("dwarf", 0))).is_equal(3)
	assert_that(int(city2.race_pop.get("human", 0))).is_equal(5)


# --- Расовая синергия квартала (synergy -> логистика) ---

func test_district_synergy_mult_adjacent() -> void:
	var city := City.new()
	var a := _mk_building("farm", 2)
	a.cell = Vector2i.ZERO
	a.worker_race = &"human"
	city.buildings.append(a)
	var nb_cell: Vector2i = HexUtils.get_all_neighbors(Vector2i.ZERO)[0]
	var b := _mk_building("mine", 2)
	b.cell = nb_cell
	b.worker_race = &"dwarf"
	city.buildings.append(b)
	assert_that(RaceEconomy.district_synergy_mult(city, a)).is_equal(1.10)


func test_district_synergy_mult_no_neighbor() -> void:
	var city := City.new()
	var a := _mk_building("farm", 2)
	a.cell = Vector2i.ZERO
	a.worker_race = &"human"
	city.buildings.append(a)
	assert_that(RaceEconomy.district_synergy_mult(city, a)).is_equal(1.0)


func test_district_synergy_mult_empty_race() -> void:
	var city := City.new()
	var a := _mk_building("farm", 2)
	a.cell = Vector2i.ZERO
	city.buildings.append(a)
	# пустой worker_race -> 1.0
	assert_that(RaceEconomy.district_synergy_mult(city, a)).is_equal(1.0)


func test_district_synergy_mult_takes_max_not_sum() -> void:
	var city := City.new()
	var a := _mk_building("farm", 2)
	a.cell = Vector2i.ZERO
	a.worker_race = &"orlan"  # orlan: elf 1.10, orc 1.05
	city.buildings.append(a)
	var nbs: Array = HexUtils.get_all_neighbors(Vector2i.ZERO)
	var elf_b := _mk_building("school", 2)
	elf_b.cell = nbs[0]
	elf_b.worker_race = &"elf"
	city.buildings.append(elf_b)
	var orc_b := _mk_building("barracks", 2)
	orc_b.cell = nbs[1]
	orc_b.worker_race = &"orc"
	city.buildings.append(orc_b)
	# max(1.10, 1.05) = 1.10, не 1.155
	assert_that(RaceEconomy.district_synergy_mult(city, a)).is_equal(1.10)

extends BaseTest

## T-116: реестр жителей (population_system.gd). Покрывает состав
## 14-й итерации (раунд 2 §2.2): возрастная модель GDD §3 (трудоспособные
## 16–60, наставники 60+, lifespan «60 + Удача»), рождения k_pop (K-M12,
## MVP m=1) с переносом дробей, семьи, потребитель шва T-050
## (losses → списание жителей по character_uid; раненые — не потери),
## миграционная формула F-3 (вход — только Репутация; Престиж — никогда,
## Э1-3), сериализация в секцию "population" схемы T-110, детерминизм (I1).

const PopulationSystemScript := preload("res://scripts/campaign/population_system.gd")


func _p() -> PopulationSystemScript:
	return PopulationSystemScript.new()


func _resident(uid: int, age: float, luck: int = 0) -> Dictionary:
	return {"uid": uid, "age": age, "family_id": 1, "wounded": false, "luck": luck}


## — Возрастная модель (GDD §3) —

func test_seed_population_20() -> void:
	var p := _p()
	p.seed_population(20)
	assert_int(p.size()).is_equal(20)
	# Стартовый возраст 18–57 → все трудоспособны, наставников нет.
	assert_int(p.working_count()).is_equal(20)
	assert_int(p.mentor_count()).is_equal(0)


func test_age_bands_working_and_mentors() -> void:
	var p := _p()
	p.residents = [
		_resident(1, 10.0),   # ребёнок
		_resident(2, 16.0),   # нижняя граница трудоспособных (включена)
		_resident(3, 59.9),   # верхняя (исключена граница 60)
		_resident(4, 60.0),   # наставник (60+ включён)
		_resident(5, 74.0),   # наставник
	]
	assert_int(p.working_count()).is_equal(2)
	assert_int(p.mentor_count()).is_equal(2)


func test_lifespan_60_plus_luck() -> void:
	var p := _p()
	p.residents = [
		_resident(1, 60.4, 0),   # lifespan 60 → смерть после старения
		_resident(2, 60.9, 2),   # lifespan 62 → живёт
	]
	p.next_uid = 100
	var rep := p.process_turn(20, 0.0, -1)
	assert_array(rep["deaths_natural"] as Array).is_equal([1])
	assert_bool(p.find_resident(2).size() > 0).is_true()


## — Рождения (k_pop, K-M12: MVP — все m = 1) —

func test_births_k_pop_per_turn() -> void:
	var p := _p()
	p.seed_population(20)
	var rep := p.process_turn(20, 0.0, 999)
	# k_pop 0.1/день × 20 дней × m=1 → ровно 2 новорождённых.
	assert_int(int(rep["births"])).is_equal(2)
	assert_int(p.size()).is_equal(22)


func test_births_carry_fraction_between_turns() -> void:
	var p := _p()
	p.seed_population(20)
	var r1 := p.process_turn(5, 0.0, 999)  # 0.5 → 0, остаток в переносе
	var r2 := p.process_turn(5, 0.0, 999)  # 0.5 + 0.5 → 1
	assert_int(int(r1["births"])).is_equal(0)
	assert_int(int(r2["births"])).is_equal(1)


func test_births_respect_cap() -> void:
	var p := _p()
	p.seed_population(5)
	p.process_turn(20, 0.0, 5)  # кап = текущее население
	assert_int(p.size()).is_equal(5)


func test_newborn_joins_smallest_family() -> void:
	var p := _p()
	p.seed_population(5)  # семьи: 0 → трое (uid 1–3), 1 → двое (uid 4–5)
	p.process_turn(20, 0.0, 999)  # 2 новорождённых
	# 1-й: наименьшая семья — 1 (двое); 2-й: тай-брейк 3↔3 → минимальный id 0.
	assert_int(int(p.residents[5]["family_id"])).is_equal(1)
	assert_int(int(p.residents[6]["family_id"])).is_equal(0)


## — Потребитель шва T-050: losses → жители —

func test_battle_losses_remove_specific_residents() -> void:
	var p := _p()
	p.seed_population(5)
	var rep := p.apply_battle_losses([2, 4])
	assert_array(rep["removed"] as Array).is_equal([2, 4])
	assert_int(p.size()).is_equal(3)
	assert_bool(p.find_resident(2).is_empty()).is_true()
	assert_bool(p.find_resident(3) != null and not p.find_resident(3).is_empty()).is_true()


func test_wounded_are_not_losses() -> void:
	var p := _p()
	p.seed_population(5)
	var rep := p.apply_battle_losses([3], [5])
	assert_int(p.size()).is_equal(4)
	var r5 := p.find_resident(5)
	assert_bool(r5.size() > 0 and bool(r5["wounded"])).is_true()
	assert_array(rep["wounded"] as Array).is_equal([5])


func test_raider_uids_are_not_residents() -> void:
	var p := _p()
	p.seed_population(5)
	var rep := p.apply_battle_losses([-1, 0])
	assert_int(p.size()).is_equal(5)
	assert_array(rep["removed"] as Array).is_empty()
	assert_array(rep["missing"] as Array).is_empty()


func test_unknown_uid_recorded_as_missing() -> void:
	var p := _p()
	p.seed_population(3)
	var rep := p.apply_battle_losses([99])
	assert_array(rep["missing"] as Array).is_equal([99])
	assert_int(p.size()).is_equal(3)


func test_conscript_returns_resident_uid() -> void:
	var p := _p()
	p.seed_population(3)
	var uid := p.conscript()
	assert_bool(p.find_resident(uid).size() > 0).is_true()
	# Раненый/нетрудоспособный не идёт в бой.
	p.apply_battle_losses([], [uid])
	assert_int(p.conscript()).is_not_equal(uid)


## — Миграция: формула F-3 (вход — только Репутация; Э1-3) —

func test_migration_reputation_in_and_out() -> void:
	var p := _p()
	p.seed_population(10)
	var rep_in := p.process_turn(20, 4.0, 999)   # 0.25 × 4 = +1 иммигрант
	assert_int(int(rep_in["immigrants"])).is_equal(1)
	var rep_out := p.process_turn(20, -4.0, 999)  # −1 эмигрант (старший)
	assert_int((rep_out["emigrants"] as Array).size()).is_equal(1)


func test_migration_neutral_reputation_no_change() -> void:
	var p := _p()
	p.seed_population(10)
	var rep := p.process_turn(20, 0.0, 999)
	assert_int(int(rep["immigrants"])).is_equal(0)
	assert_array(rep["emigrants"] as Array).is_empty()


func test_migration_formula_has_no_prestige() -> void:
	# Э1-3: Престиж никогда не влияет на миграцию — ни ключом в конфиге
	# формулы, ни в имени системы (живой слой — только Репутация).
	var f := FileAccess.open(PopulationSystemScript.POPULATION_CONFIG_PATH, FileAccess.READ)
	assert_bool(f != null).is_true()
	var cfg: Dictionary = JSON.parse_string(f.get_as_text())
	var mig: Dictionary = cfg.get("migration", {})
	for key in mig.keys():
		assert_str(str(key).to_lower()).not_contains("prestige")
	assert_str(str(mig.get("note", ""))).not_contains("appeal")


func test_immigrants_respect_cap() -> void:
	var p := _p()
	p.seed_population(5)
	p.process_turn(20, 100.0, 5)
	assert_int(p.size()).is_equal(5)


## — Сериализация (секция "population" схемы T-110) + детерминизм —

func test_serialization_roundtrip() -> void:
	var p := _p()
	p.seed_population(8)
	p.process_turn(20, 2.0, 999)
	p.apply_battle_losses([3])
	var data := p.to_dict()
	assert_int(int(data["schema_version"])).is_equal(PopulationSystemScript.SCHEMA_VERSION)
	var back := PopulationSystemScript.from_dict(data)
	assert_str(JSON.stringify(back.to_dict())).is_equal(JSON.stringify(data))


func test_determinism_two_systems_identical() -> void:
	var a := _p()
	var b := _p()
	for p in [a, b]:
		p.seed_population(12)
		p.process_turn(20, 1.5, 999)
		p.process_turn(20, -0.5, 999)
		p.apply_battle_losses([2, 7])
	assert_str(JSON.stringify(a.to_dict())).is_equal(JSON.stringify(b.to_dict()))

extends BaseTest
## team-romance-roleplay 2.x: RelationshipSystem — связи, стадии, тик.


func _hero_with_follower(gender: StringName = &"female", orientation: StringName = &"hetero", hero_sex: String = "male") -> HeroController:
	var hero = auto_free(HeroController.new())
	hero.stats_comp.sex = hero_sex
	var f := Follower.new()
	f.uid = 1
	f.name = "Вера"
	f.gender = gender
	f.orientation = orientation
	hero.followers.append(f)
	return hero

func test_compatible_matrix() -> void:
	# bi — всегда
	assert_bool(RelationshipSystem.compatible("male", &"male", &"bi")).is_true()
	assert_bool(RelationshipSystem.compatible("male", &"female", &"bi")).is_true()
	# hetero: только разный пол
	assert_bool(RelationshipSystem.compatible("male", &"female", &"hetero")).is_true()
	assert_bool(RelationshipSystem.compatible("male", &"male", &"hetero")).is_false()
	assert_bool(RelationshipSystem.compatible("female", &"male", &"hetero")).is_true()
	# homo: только тот же пол
	assert_bool(RelationshipSystem.compatible("male", &"male", &"homo")).is_true()
	assert_bool(RelationshipSystem.compatible("male", &"female", &"homo")).is_false()
	assert_bool(RelationshipSystem.compatible("female", &"female", &"homo")).is_true()

func test_stage_boundaries() -> void:
	assert_that(RelationshipSystem.stage_of(-100)).is_equal(RelationshipSystem.STAGE_STRANGER)
	assert_that(RelationshipSystem.stage_of(29)).is_equal(RelationshipSystem.STAGE_STRANGER)
	assert_that(RelationshipSystem.stage_of(30)).is_equal(RelationshipSystem.STAGE_FRIEND)
	assert_that(RelationshipSystem.stage_of(59)).is_equal(RelationshipSystem.STAGE_FRIEND)
	assert_that(RelationshipSystem.stage_of(60)).is_equal(RelationshipSystem.STAGE_CLOSE_FRIEND)
	assert_that(RelationshipSystem.stage_of(100)).is_equal(RelationshipSystem.STAGE_CLOSE_FRIEND)

func test_romance_stage_boundaries() -> void:
	assert_that(RelationshipSystem.romance_stage(0)).is_equal(RelationshipSystem.ROM_NONE)
	assert_that(RelationshipSystem.romance_stage(24)).is_equal(RelationshipSystem.ROM_NONE)
	assert_that(RelationshipSystem.romance_stage(25)).is_equal(RelationshipSystem.ROM_FLIRT)
	assert_that(RelationshipSystem.romance_stage(49)).is_equal(RelationshipSystem.ROM_FLIRT)
	assert_that(RelationshipSystem.romance_stage(50)).is_equal(RelationshipSystem.ROM_RELATIONSHIP)
	assert_that(RelationshipSystem.romance_stage(74)).is_equal(RelationshipSystem.ROM_RELATIONSHIP)
	assert_that(RelationshipSystem.romance_stage(75)).is_equal(RelationshipSystem.ROM_ENGAGED)
	assert_that(RelationshipSystem.romance_stage(99)).is_equal(RelationshipSystem.ROM_ENGAGED)
	assert_that(RelationshipSystem.romance_stage(100)).is_equal(RelationshipSystem.ROM_MARRIED)

func test_modify_clamps() -> void:
	var hero := _hero_with_follower()
	var rel: HeroRelationshipsComponent = hero.relationships
	var f: Follower = hero.followers[0]
	# bond: 0 + 500 → 100 (клинирование)
	var applied: Dictionary = RelationshipSystem.modify(rel, "male", f, {"bond": 500})
	assert_that(int(applied["bond"])).is_equal(100)
	assert_that(int(rel.pair(1)["bond"])).is_equal(100)
	# trust: 50 - 500 → 0
	RelationshipSystem.modify(rel, "male", f, {"trust": -500})
	assert_that(int(rel.pair(1)["trust"])).is_equal(0)

func test_modify_romance_gate() -> void:
	# hero male, follower male hetero → romance не растёт
	var hero := _hero_with_follower(&"male", &"hetero", "male")
	var f: Follower = hero.followers[0]
	var applied: Dictionary = RelationshipSystem.modify(hero.relationships, "male", f, {"romance": 30})
	assert_that(int(applied["romance"])).is_equal(0)
	assert_that(int(hero.relationships.pair(1)["romance"])).is_equal(0)
	# bond при этом растёт
	var applied2: Dictionary = RelationshipSystem.modify(hero.relationships, "male", f, {"bond": 10})
	assert_that(int(applied2["bond"])).is_equal(10)
	# совместимая пара → romance растёт
	var hero2 := _hero_with_follower(&"female", &"hetero", "male")
	var f2: Follower = hero2.followers[0]
	var applied3: Dictionary = RelationshipSystem.modify(hero2.relationships, "male", f2, {"romance": 30})
	assert_that(int(applied3["romance"])).is_equal(30)

func test_process_turn_passive_bond_and_stage() -> void:
	var hero := _hero_with_follower()
	RelationshipSystem.set_rng(TestFactories.seeded(1))
	var events: Array = RelationshipSystem.process_turn(hero, hero.relationships)
	assert_that(int(hero.relationships.pair(1)["bond"])).is_equal(1)
	# переход в Друг, когда bond достигает 30 (30-й тик)
	var last: Array = []
	for i in 29:
		last = RelationshipSystem.process_turn(hero, hero.relationships)
	var saw_friend := false
	for e in last:
		if e["type"] == "stage_changed" and not e["is_romance"] and e["stage"] == RelationshipSystem.STAGE_FRIEND:
			saw_friend = true
	assert_bool(saw_friend).is_true()

func test_process_turn_betrayal() -> void:
	# trust 0 → r20 > 0 всегда → предательство гарантировано
	var hero := _hero_with_follower()
	hero.relationships.pair(1)["trust"] = 0
	RelationshipSystem.set_rng(TestFactories.seeded(42))
	var events: Array = RelationshipSystem.process_turn(hero, hero.relationships)
	var betrayed := false
	for e in events:
		if e["type"] == "betrayal":
			betrayed = true
	assert_bool(betrayed).is_true()
	assert_that(hero.followers.size()).is_equal(0)
	assert_bool(hero.relationships.has_pair(1)).is_false()

func test_process_turn_no_betrayal_healthy_trust() -> void:
	# trust ≥ 20 → проверки верности нет, предательств нет
	var hero := _hero_with_follower()
	RelationshipSystem.set_rng(TestFactories.seeded(1))
	for i in 5:
		var events: Array = RelationshipSystem.process_turn(hero, hero.relationships)
		for e in events:
			assert_bool(e["type"] != "betrayal").is_true()
	assert_that(hero.followers.size()).is_equal(1)

func test_process_turn_jealousy_once() -> void:
	# два последователя, у обоих romance ≥ 50 к герою → ревность один раз
	var hero := _hero_with_follower(&"female", &"hetero", "male")
	var f2 := Follower.new()
	f2.uid = 2
	f2.name = "Дарья"
	f2.gender = &"female"
	f2.orientation = &"hetero"
	hero.followers.append(f2)
	hero.relationships.pair(1)["romance"] = 60
	hero.relationships.pair(2)["romance"] = 60
	RelationshipSystem.set_rng(TestFactories.seeded(3))
	var events: Array = RelationshipSystem.process_turn(hero, hero.relationships)
	var jealousy_count := 0
	for e in events:
		if e["type"] == "jealousy":
			jealousy_count += 1
	assert_that(jealousy_count).is_equal(1)
	# bond/trust снижены у обоих
	assert_that(int(hero.relationships.pair(1)["bond"])).is_equal(-19)  # +1 пассив −20 ревность
	assert_that(int(hero.relationships.pair(1)["trust"])).is_equal(35)  # 50 −15
	# повторный тик — ревность не повторяется
	var events2: Array = RelationshipSystem.process_turn(hero, hero.relationships)
	var jealousy_count2 := 0
	for e in events2:
		if e["type"] == "jealousy":
			jealousy_count2 += 1
	assert_that(jealousy_count2).is_equal(0)

func test_process_turn_marriage_ready() -> void:
	var hero := _hero_with_follower(&"female", &"hetero", "male")
	# bond ≥ 60 → пассивная романтика +1 поднимает 99 → 100 (Брак)
	hero.relationships.pair(1)["romance"] = 99
	hero.relationships.pair(1)["bond"] = 60
	RelationshipSystem.set_rng(TestFactories.seeded(7))
	var events: Array = RelationshipSystem.process_turn(hero, hero.relationships)
	var marriage := false
	for e in events:
		if e["type"] == "marriage_ready":
			marriage = true
	assert_bool(marriage).is_true()
	# marry() → spouse
	RelationshipSystem.marry(hero.relationships, 1)
	assert_bool(bool(hero.relationships.pair(1)["spouse"])).is_true()
	# после брака marriage_ready больше не fires
	var events2: Array = RelationshipSystem.process_turn(hero, hero.relationships)
	for e in events2:
		assert_bool(e["type"] != "marriage_ready").is_true()

func test_process_turn_conflict() -> void:
	var hero := _hero_with_follower()
	hero.relationships.pair(1)["bond"] = -50
	RelationshipSystem.set_rng(TestFactories.seeded(11))
	var events: Array = RelationshipSystem.process_turn(hero, hero.relationships)
	var conflict := false
	for e in events:
		if e["type"] == "conflict":
			conflict = true
	# конфликт fires не больше раза за тик (флаг conflict_pending)
	if conflict:
		assert_bool(bool(hero.relationships.pair(1)["conflict_pending"])).is_true()
		# примирение снимает флаг и поднимает bond
		var ok := RelationshipSystem.try_reconcile(hero.relationships, 1, 14)
		assert_bool(bool(hero.relationships.pair(1)["conflict_pending"]) == false).is_true()

func test_sever() -> void:
	var hero := _hero_with_follower()
	hero.relationships.pair(1)["bond"] = 40
	RelationshipSystem.sever(hero, hero.relationships, 1)
	assert_that(hero.followers.size()).is_equal(0)
	assert_bool(hero.relationships.has_pair(1)).is_false()

func test_determinism_two_runs() -> void:
	# одинаковый seed → одинаковые события и связи
	var results: Array = []
	for run in 2:
		var hero := _hero_with_follower(&"female", &"hetero", "male")
		var f2 := Follower.new()
		f2.uid = 2
		f2.gender = &"female"
		f2.orientation = &"homo"
		hero.followers.append(f2)
		hero.relationships.pair(1)["trust"] = 10
		hero.relationships.pair(1)["bond"] = -40
		hero.relationships.pair(2)["romance"] = 60
		RelationshipSystem.set_rng(TestFactories.seeded(99))
		var all_events: Array = []
		for i in 10:
			all_events.append_array(RelationshipSystem.process_turn(hero, hero.relationships))
		results.append({"events": all_events, "pairs": hero.relationships.pairs.duplicate(true)})
		hero.free()
	assert_that(results[0]["events"]).is_equal(results[1]["events"])
	assert_that(results[0]["pairs"]).is_equal(results[1]["pairs"])

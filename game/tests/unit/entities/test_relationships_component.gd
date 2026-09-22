extends BaseTest
## team-romance-roleplay 1.4: HeroRelationshipsComponent — модель данных.


func test_pair_defaults() -> void:
	var comp := HeroRelationshipsComponent.new()
	assert_bool(comp.has_pair(1)).is_false()
	var p: Dictionary = comp.pair(1)
	assert_that(int(p["bond"])).is_equal(0)
	assert_that(int(p["trust"])).is_equal(50)
	assert_that(int(p["romance"])).is_equal(0)
	assert_bool(bool(p["spouse"])).is_false()
	assert_bool(comp.has_pair(1)).is_true()

func test_duo_key_order_independent() -> void:
	assert_that(HeroRelationshipsComponent.duo_key(3, 1)).is_equal(HeroRelationshipsComponent.duo_key(1, 3))
	assert_that(HeroRelationshipsComponent.duo_key(3, 1)).is_equal("1:3")

func test_duo_defaults_and_remove() -> void:
	var comp := HeroRelationshipsComponent.new()
	var d: Dictionary = comp.duo(2, 1)
	assert_that(int(d["trust"])).is_equal(50)
	assert_that(int(d["jealousy_to"])).is_equal(-1)
	assert_bool(bool(d["jealousy_fired"])).is_false()
	# remove_follower убирает и pair, и duos
	comp.pair(1)
	comp.remove_follower(1)
	assert_bool(comp.has_pair(1)).is_false()
	assert_bool(comp.duos.is_empty()).is_true()

func test_average_bond() -> void:
	var comp := HeroRelationshipsComponent.new()
	assert_that(comp.average_bond()).is_equal(0.0)
	comp.pair(1)["bond"] = 40
	comp.pair(2)["bond"] = 80
	assert_that(comp.average_bond()).is_equal(60.0)

func test_serialize_roundtrip() -> void:
	var comp := HeroRelationshipsComponent.new()
	var p: Dictionary = comp.pair(7)
	p["bond"] = 65
	p["trust"] = 80
	p["romance"] = 100
	p["spouse"] = true
	p["last_bond_stage"] = 2
	p["last_romance_stage"] = 4
	var d: Dictionary = comp.duo(2, 5)
	d["bond"] = -10
	d["jealousy_to"] = 7
	d["jealousy_fired"] = true

	var data: Dictionary = comp.serialize()
	var comp2 := HeroRelationshipsComponent.new()
	comp2.deserialize(data)

	var p2: Dictionary = comp2.pair(7)
	assert_that(int(p2["bond"])).is_equal(65)
	assert_that(int(p2["trust"])).is_equal(80)
	assert_that(int(p2["romance"])).is_equal(100)
	assert_bool(bool(p2["spouse"])).is_true()
	assert_that(int(p2["last_bond_stage"])).is_equal(2)
	assert_that(int(p2["last_romance_stage"])).is_equal(4)
	var d2: Dictionary = comp2.duo(5, 2)
	assert_that(int(d2["bond"])).is_equal(-10)
	assert_that(int(d2["jealousy_to"])).is_equal(7)
	assert_bool(bool(d2["jealousy_fired"])).is_true()

func test_deserialize_old_save_defaults() -> void:
	# старый сейв без блока relationships → пустые связи
	var comp := HeroRelationshipsComponent.new()
	comp.deserialize({})
	assert_bool(comp.pairs.is_empty()).is_true()
	assert_bool(comp.duos.is_empty()).is_true()
	# частичный pair (старый формат) → недостающие поля дефолтные
	var comp2 := HeroRelationshipsComponent.new()
	comp2.deserialize({"relationships": {"pairs": {"hero-1": {"bond": 30}}, "duos": {}}})
	var p: Dictionary = comp2.pair(1)
	assert_that(int(p["bond"])).is_equal(30)
	assert_that(int(p["trust"])).is_equal(50)
	assert_that(int(p["romance"])).is_equal(0)

func test_hero_controller_wiring() -> void:
	# компонент зарегистрирован в HeroController и сериализуется вместе с героем
	var hero = auto_free(HeroController.new())
	assert_that(hero.relationships).is_not_null()
	var p: Dictionary = hero.relationships.pair(1)
	p["bond"] = 25
	var data: Dictionary = hero.serialize()
	assert_bool(data.has("relationships")).is_true()
	var hero2 = auto_free(HeroController.new())
	hero2.deserialize(data)
	assert_that(int(hero2.relationships.pair(1)["bond"])).is_equal(25)
	hero.free()
	hero2.free()

func _make_hero_with_follower(uid: int = 1, gender: StringName = &"female") -> HeroController:
	var hero = auto_free(HeroController.new())
	hero.stats_comp.sex = "male"
	var f := Follower.new()
	f.uid = uid
	f.name = "Вера"
	f.gender = gender
	f.orientation = &"hetero"
	hero.followers.append(f)
	return hero

func test_end_turn_passive_tick() -> void:
	var hero := _make_hero_with_follower()
	hero.relationships.end_turn()
	assert_that(int(hero.relationships.pair(1)["bond"])).is_equal(1)
	assert_bool(hero.relationships.pending_scenes.is_empty()).is_true()

func test_end_turn_full_hero_wiring() -> void:
	# hero.end_turn() вызывает тик отношений
	var hero := _make_hero_with_follower()
	hero.end_turn()
	assert_that(int(hero.relationships.pair(1)["bond"])).is_equal(1)

func test_conflict_scene_pending_and_auto_resolve() -> void:
	var hero := _make_hero_with_follower()
	hero.relationships.pair(1)["bond"] = -50
	RelationshipSystem.set_rng(TestFactories.seeded(11))
	hero.relationships.end_turn()
	# если конфликт fires — сцена в очереди, на следующем тике авто-примирение
	var has_conflict := false
	for s in hero.relationships.pending_scenes:
		if s["type"] == "conflict":
			has_conflict = true
	if has_conflict:
		assert_that(hero.relationships.pending_scenes.size()).is_equal(1)
		hero.relationships.end_turn()
		assert_bool(hero.relationships.pending_scenes.is_empty()).is_true()
		assert_bool(bool(hero.relationships.pair(1).get("conflict_pending", false)) == false).is_true()

func test_marriage_scene_auto_confirm() -> void:
	var hero := _make_hero_with_follower()
	hero.relationships.pair(1)["romance"] = 99
	hero.relationships.pair(1)["bond"] = 60
	RelationshipSystem.set_rng(TestFactories.seeded(7))
	hero.relationships.end_turn()
	var has_marriage := false
	for s in hero.relationships.pending_scenes:
		if s["type"] == "marriage":
			has_marriage = true
	assert_bool(has_marriage).is_true()
	hero.relationships.end_turn()  # авто-подтверждение
	assert_bool(bool(hero.relationships.pair(1)["spouse"])).is_true()
	assert_bool(hero.relationships.pending_scenes.is_empty()).is_true()

func test_resolve_pending_sever() -> void:
	var hero := _make_hero_with_follower()
	hero.relationships.pending_scenes.append({"type": "conflict", "uid": 1})
	hero.relationships.resolve_pending(0, "sever")
	assert_that(hero.followers.size()).is_equal(0)
	assert_bool(hero.relationships.pending_scenes.is_empty()).is_true()

func test_resolve_pending_marriage_decline() -> void:
	var hero := _make_hero_with_follower()
	hero.relationships.pair(1)["romance"] = 90
	hero.relationships.pending_scenes.append({"type": "marriage", "uid": 1})
	hero.relationships.resolve_pending(0, "decline")
	assert_that(int(hero.relationships.pair(1)["romance"])).is_equal(75)
	assert_bool(bool(hero.relationships.pair(1)["spouse"]) == false).is_true()

func test_morale_bonus() -> void:
	# team-romance-roleplay 3.1: clampi(avg_bond/20, −2, 3)
	var hero := _make_hero_with_follower()
	assert_that(hero.morale_bonus()).is_equal(0)  # bond 0
	hero.relationships.pair(1)["bond"] = 60
	assert_that(hero.morale_bonus()).is_equal(3)
	hero.relationships.pair(1)["bond"] = 100
	assert_that(hero.morale_bonus()).is_equal(3)  # клин +3
	hero.relationships.pair(1)["bond"] = -40
	assert_that(hero.morale_bonus()).is_equal(-2)  # клин −2

func test_morale_in_battle_stack() -> void:
	var hero := _make_hero_with_follower()
	hero.stats_comp.stats["attack"] = 5
	hero.stats_comp.stats["defense"] = 4
	hero.combat_comp.combat_hp = 10
	var base: UnitStack = hero.get_hero_battle_stack()
	var base_atk := int(base.stats.attack)
	var base_def := int(base.stats.defense)
	hero.relationships.pair(1)["bond"] = 60  # +3
	var boosted: UnitStack = hero.get_hero_battle_stack()
	assert_that(int(boosted.stats.attack) - base_atk).is_equal(3)
	assert_that(int(boosted.stats.defense) - base_def).is_equal(3)

func test_betrayal_returns_to_city() -> void:
	# team-romance-roleplay 3.3: герой на центре города → предатель в население
	var hero := _make_hero_with_follower()
	hero.city_manager = CityManager.new()
	var city := City.new()
	city.uid = 1
	city.display_name = "Город"
	city.center = Vector2i(5, 5)
	hero.city_manager.register_city(city)
	hero.movement_comp.set_current_cell(Vector2i(5, 5))
	hero.relationships.pair(1)["trust"] = 0  # гарантированное предательство
	RelationshipSystem.set_rng(TestFactories.seeded(42))
	hero.relationships.end_turn()
	assert_that(hero.followers.size()).is_equal(0)
	assert_that(city.pop.size()).is_equal(1)
	assert_that(int(city.pop[0].state)).is_equal(int(PopUnit.State.FOLLOWER))

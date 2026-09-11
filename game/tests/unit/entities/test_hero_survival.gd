extends BaseTest









const _DeathSequenceScene = preload("res://scenes/ui/DeathSequence.tscn")














class _MockDeath extends Node:
	var visible := true
	signal successor_chosen
	signal return_to_menu
	signal chronicle_requested
	signal resurrection_chosen
	var shown := false
	var res_city: City = null
	var successor: Node = null
	func show_death(_n: String, _c: StringName, _s: Dictionary, succ: Node = null, rc: City = null) -> void:
		shown = true
		visible = true
		res_city = rc
		successor = succ

class _MockPersistence extends RefCounted:
	var session := GameSession.new()
	var chronicle = null
	func get_date() -> Dictionary:
		return {"month": 3, "week": 2, "day": 5}

var _uid := 100

func _next_uid() -> int:
	_uid += 1
	return _uid

func _survival_hero(path := &"warrior") -> HeroController:
	var h := TestFactories.make_hero(path)
	h._ready()
	h.max_combat_hp = 20
	h.set_combat_hp(20)
	h.is_alive = true
	h.movement = HeroMovementController.new()
	h.add_child(h.movement)
	return h

func _make_follower(uid: int, path: StringName) -> Follower:
	var f := Follower.new()
	f.uid = uid
	f.path = path
	return f

func _make_city() -> City:
	var c := City.new()
	c.uid = _next_uid()
	c.display_name = &"Testhold"
	c.owner = &"player"
	c.center = Vector2i(5, 5)
	return c

func _make_temple_city(resources_ok := true) -> City:
	var c := _make_city()
	if resources_ok:
		c.storage[&"industry"] = float(GameNumbers.SUCCESSION_RESURRECT_IND) + 100.0
		c.storage[&"gold"] = float(GameNumbers.SUCCESSION_RESURRECT_GOLD) + 50.0
	else:
		c.storage[&"industry"] = 1.0
		c.storage[&"gold"] = 1.0
	var bld := UniqueBuilding.new()
	bld.def = BuildingDefs.great_temple()
	bld.level = 1
	c.buildings.append(bld)
	return c

func _make_wc(cities: Array, persistence: _MockPersistence = null) -> WorldController:
	var wc = auto_free( WorldController.new())
	wc._rng = TestFactories.seeded(2128)
	var mgr = auto_free( CityManager.new())
	for city in cities:
		mgr.register_city(city)
	wc.add_child(mgr)
	wc._cities = mgr
	wc._succession = SuccessionController.new()
	wc._persistence = persistence if persistence != null else _MockPersistence.new()
	var sys := HeroLifecycleSystem.new()
	sys.setup(wc, wc._persistence, wc._rng, wc._cities, null, null, null, null, null, null, wc._succession, null)
	wc._hero_lifecycle = sys
	return wc

var _tree_parents: Array = []

func _hero_in_tree(hero: HeroController) -> Node:
	var parent := Node.new()
	add_child(parent)
	_tree_parents.append(parent)
	parent.add_child(hero)
	return parent

func _free_node(o: Variant) -> void:

	if is_instance_valid(o) and o is Node:
		o.free()

var _bus_conns: Array = []

func _bus(sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	_bus_conns.append([sig, cb])

func after_test() -> void:
	for p in _tree_parents:
		_free_node(p)
	_tree_parents.clear()
	for pair in _bus_conns:
		if pair[1].is_valid() and pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])
	_bus_conns.clear()

func test_needs_init_all_full() -> void:
	var n := HeroNeeds.new()
	for k in NeedType.all_ids():
		assert_float(n.get_need(k)).is_equal_approx(1.0, 0.0001)
		assert_that(n.zero_streak[k]).is_equal(0)

func test_needs_field_decay() -> void:
	var n := HeroNeeds.new()
	assert_that(n.tick(false)).is_equal(&"")
	assert_float(n.get_need(NeedType.ID.REST)).is_equal_approx(0.90, 0.0001)
	assert_float(n.get_need(NeedType.ID.SOCIAL)).is_equal_approx(0.87, 0.0001)
	assert_float(n.get_need(NeedType.ID.INSPIRATION)).is_equal_approx(0.95, 0.0001)

func test_needs_city_recovery() -> void:
	var n := HeroNeeds.new()
	for k in NeedType.all_ids():
		n.needs[k] = 0.5
	var c := _make_temple_city()
	c.pop = [PopUnit.new(), PopUnit.new(), PopUnit.new()]
	assert_that(n.tick(true, c)).is_equal(&"")
	assert_float(n.get_need(NeedType.ID.REST)).is_equal_approx(0.76, 0.0001)
	assert_float(n.get_need(NeedType.ID.SOCIAL)).is_equal_approx(0.72, 0.0001)
	assert_float(n.get_need(NeedType.ID.INSPIRATION)).is_equal_approx(0.60, 0.0001)

func test_needs_lonely_city_social_drains() -> void:
	var n := HeroNeeds.new()
	n.needs[NeedType.ID.SOCIAL] = 0.5
	var c := _make_temple_city()
	n.tick(true, c)
	assert_float(n.get_need(NeedType.ID.SOCIAL)).is_equal_approx(0.37, 0.0001)

func test_needs_zero_streak_all_causes() -> void:
	var cases := {
		NeedType.ID.REST: &"exhaustion",
		NeedType.ID.SOCIAL: &"isolation",
		NeedType.ID.INSPIRATION: &"burnout",
	}
	for need_id in cases:
		var m := HeroNeeds.new()
		m.needs[need_id] = 0.0
		assert_that(m.tick(false)).is_equal(&"")
		assert_that(m.tick(false)).is_equal(&"")
		assert_that(m.tick(false)).is_equal(cases[need_id])

func test_needs_serialize_roundtrip_and_old_save() -> void:
	var n := HeroNeeds.new()
	n.needs[NeedType.ID.REST] = 0.33
	n.zero_streak[NeedType.ID.REST] = 2
	var m := HeroNeeds.new()
	m.deserialize(n.serialize())
	assert_float(m.get_need(NeedType.ID.REST)).is_equal_approx(0.33, 0.0001)
	assert_that(m.zero_streak[NeedType.ID.REST]).is_equal(0)
	var old := HeroNeeds.new()
	old.deserialize({})
	for k in NeedType.all_ids():
		assert_float(old.get_need(k)).is_equal_approx(1.0, 0.0001)

func test_hero_dies_by_needs_emits_hero_died() -> void:
	var h := _survival_hero()
	h.needs.needs[NeedType.ID.REST] = 0.0
	var captured: Dictionary = {"cause": &""}
	var on_died := func(cause: StringName) -> void: captured["cause"] = cause
	_bus(GameEventBus.hero_died, on_died)
	h._tick_needs()
	h._tick_needs()
	assert_bool(h.is_alive).is_true()
	h._tick_needs()
	GameEventBus.hero_died.disconnect(on_died)
	assert_bool(h.is_alive).is_false()
	assert_that(captured["cause"]).is_equal(&"exhaustion")
	h.free()

func test_hero_city_tick_recovers() -> void:
	var h := _survival_hero()
	var c := _make_temple_city()
	c.pop = [PopUnit.new(), PopUnit.new(), PopUnit.new()]
	var mgr = auto_free( CityManager.new())
	mgr.register_city(c)
	h.city_manager = mgr
	h.movement.current_cell = c.center
	for k in NeedType.all_ids():
		h.needs.needs[k] = 0.5
	h._tick_needs()
	assert_float(h.needs.get_need(NeedType.ID.REST)).is_equal_approx(0.76, 0.0001)
	assert_float(h.needs.get_need(NeedType.ID.SOCIAL)).is_equal_approx(0.72, 0.0001)
	mgr.free()
	h.free()

func test_hero_revive_at() -> void:
	var h := _survival_hero()
	h.is_alive = false
	h.set_combat_hp(0)
	h.inventory.backpack.append(Artifact.new())
	h.inventory.equipped["weapon"] = Artifact.new()
	for k in NeedType.all_ids():
		h.needs.needs[k] = 0.2
	var c := _make_temple_city()
	c.center = Vector2i(9, 9)
	h.revive_at(c)
	assert_bool(h.is_alive).is_true()
	assert_that(h.combat_hp).is_equal(20)
	for k in NeedType.all_ids():
		assert_float(h.needs.get_need(k)).is_equal_approx(1.0, 0.0001)
	assert_bool(h.inventory.backpack.is_empty()).is_true()
	assert_bool(h.inventory.equipped.is_empty()).is_true()
	assert_that(h.movement.current_cell).is_equal(Vector2i(9, 9))
	h.free()

func _setup_serializable(h: HeroController) -> void:
	h.movement = HeroMovementController.new()
	h.army = HeroArmyController.new()
	h.resources = HeroResources.new()
	h.add_child(h.movement)
	h.add_child(h.army)
	h.add_child(h.resources)
	h.magic = HeroMagic.new()
	h.skills = HeroSkills.new()
	h.tools = HeroTools.new()
	h.time = TimeSystem.new()
	h.strategic_resources = HeroStrategicResources.new()

func test_hero_serialize_needs_roundtrip() -> void:
	var h := _survival_hero()
	h.hero_name = "Тест"
	_setup_serializable(h)
	h.needs.needs[NeedType.ID.REST] = 0.33
	h.resurrected_once = true
	var h2 = auto_free( HeroController.new())
	_setup_serializable(h2)
	h2.deserialize(h.serialize())
	assert_float(h2.needs.get_need(NeedType.ID.REST)).is_equal_approx(0.33, 0.0001)
	assert_bool(h2.resurrected_once).is_true()
	h.free(); h2.free()

func test_hero_deserialize_old_save_defaults() -> void:
	var h := _survival_hero()
	_setup_serializable(h)
	var d := h.serialize()
	d.erase("needs")
	d.erase("resurrected_once")
	var h2 = auto_free( HeroController.new())
	_setup_serializable(h2)
	h2.deserialize(d)
	for k in NeedType.all_ids():
		assert_float(h2.needs.get_need(k)).is_equal_approx(1.0, 0.0001)
	assert_bool(h2.resurrected_once).is_false()
	h.free(); h2.free()

func test_wc_find_resurrection_city() -> void:
	var city := _make_temple_city()
	var wc := _make_wc([city])
	var fresh := _survival_hero()
	assert_that(wc._find_resurrection_city(fresh)).is_equal(city)
	fresh.resurrected_once = true
	assert_that(wc._find_resurrection_city(fresh)).is_null()
	fresh.free()
	var poor := _make_temple_city(false)
	var wc2 := _make_wc([poor])
	var h2 := _survival_hero()
	assert_that(wc2._find_resurrection_city(h2)).is_null()
	h2.free()
	var plain := _make_city()
	var wc3 := _make_wc([plain])
	var h3 := _survival_hero()
	assert_that(wc3._find_resurrection_city(h3)).is_null()
	h3.free()
	wc.free(); wc2.free(); wc3.free()

func _setup_death_with_resurrection() -> Dictionary:
	var city := _make_temple_city()
	var wc := _make_wc([city])
	var hero := _survival_hero()
	hero.movement = HeroMovementController.new()
	hero.add_child(hero.movement)
	hero.followers.append(_make_follower(1, &"warrior"))
	var parent := _hero_in_tree(hero)
	wc._hero = hero
	var death := _MockDeath.new()
	wc._hero_lifecycle._death_seq = death
	wc._on_hero_died(&"exhaustion")
	return {"wc": wc, "hero": hero, "city": city, "parent": parent, "death": death}

func test_wc_death_holds_corpse_shows_resurrection() -> void:
	var s := _setup_death_with_resurrection()
	var wc: Node = s["wc"]
	var hero: HeroController = s["hero"]
	var city: City = s["city"]
	var death: Node = s["death"]
	assert_bool(is_instance_valid(hero)).is_true()
	assert_that(wc._hero_lifecycle._deceased_hero).is_equal(hero)
	assert_that(wc._hero_lifecycle._resurrection_city).is_equal(city)
	assert_that(wc._hero_lifecycle._pending_successor).is_not_null()
	assert_that(hero.get_parent()).is_null()
	assert_bool(death.shown).is_true()
	assert_that(death.res_city).is_equal(city)
	assert_that(death.successor).is_not_null()
	hero.free()
	s["parent"].free()
	death.free()
	_free_node(wc._hero_lifecycle._pending_successor)
	wc.free()

func test_wc_resurrection_chosen() -> void:
	var s := _setup_death_with_resurrection()
	var wc: Node = s["wc"]
	var hero: HeroController = s["hero"]
	var city: City = s["city"]
	var death: Node = s["death"]
	var successor: Node = wc._hero_lifecycle._pending_successor
	var succ_emitted: Dictionary = {"v": false}
	var on_succ := func(_h: Node) -> void: succ_emitted["v"] = true
	GameEventBus.hero_successor.connect(on_succ)
	wc._on_resurrection_chosen()
	GameEventBus.hero_successor.disconnect(on_succ)
	assert_bool(hero.is_alive).is_true()
	assert_bool(hero.resurrected_once).is_true()
	for k in NeedType.all_ids():
		assert_float(hero.needs.get_need(k)).is_equal_approx(1.0, 0.0001)
	assert_that(hero.combat_hp).is_equal(hero.max_combat_hp)
	assert_that(hero.movement.current_cell).is_equal(city.center)
	assert_float(city.storage[&"industry"]).is_equal_approx(100.0, 0.5)
	assert_float(city.storage[&"gold"]).is_equal_approx(50.0, 0.5)
	assert_that(wc._hero_lifecycle._deceased_hero).is_null()
	assert_that(wc._hero_lifecycle._resurrection_city).is_null()
	assert_that(wc._hero_lifecycle._pending_successor).is_null()
	assert_bool(is_instance_valid(successor)).is_false()
	assert_that(wc._hero).is_equal(hero)
	assert_bool(wc.is_death_sequence_open()).is_false()
	assert_bool(succ_emitted["v"]).is_false()
	s["parent"].free()
	death.free()
	wc.free()

func test_wc_second_death_in_cycle_no_resurrection() -> void:
	var s := _setup_death_with_resurrection()
	var wc: Node = s["wc"]
	var hero: HeroController = s["hero"]
	var death: Node = s["death"]
	wc._on_resurrection_chosen()
	hero.followers.append(_make_follower(9, &"warrior"))
	wc._on_hero_died(&"exhaustion")
	assert_that(wc._hero_lifecycle._deceased_hero).is_null()
	assert_that(wc._hero_lifecycle._resurrection_city).is_null()
	assert_bool(hero.is_queued_for_deletion()).is_true()
	assert_that(wc._hero_lifecycle._pending_successor).is_not_null()
	assert_bool(is_instance_valid(wc._hero_lifecycle._pending_successor)).is_true()
	assert_that(death.res_city).is_equal(null)
	if is_instance_valid(hero): hero.free()
	_free_node(wc._hero_lifecycle._pending_successor)
	s["parent"].free()
	death.free()
	wc.free()

func test_wc_succession_frees_held_corpse() -> void:
	var s := _setup_death_with_resurrection()
	var wc: Node = s["wc"]
	var hero: HeroController = s["hero"]
	wc._execute_succession()
	assert_that(wc._hero_lifecycle._deceased_hero).is_null()
	assert_bool(is_instance_valid(hero)).is_false()
	assert_that(wc._hero_lifecycle._pending_successor).is_null()
	assert_that(wc._hero).is_not_null()
	assert_bool(is_instance_valid(wc._hero)).is_true()
	s["parent"].free()
	s["death"].free()
	wc.free()

func test_wc_no_temple_corpse_freed() -> void:
	var plain := _make_city()
	var wc := _make_wc([plain])
	var hero := _survival_hero()
	hero.followers.append(_make_follower(2, &"warrior"))
	var parent := _hero_in_tree(hero)
	wc._hero = hero
	var death := _MockDeath.new()
	wc._hero_lifecycle._death_seq = death
	wc._on_hero_died(&"exhaustion")
	assert_that(wc._hero_lifecycle._deceased_hero).is_null()
	assert_bool(hero.is_queued_for_deletion()).is_true()
	assert_that(death.res_city).is_equal(null)
	if is_instance_valid(hero): hero.free()
	parent.free()
	death.free()
	_free_node(wc._hero_lifecycle._pending_successor)
	wc.free()

func test_wc_fresh_cycle_resurrection_again() -> void:
	var s := _setup_death_with_resurrection()
	var wc: Node = s["wc"]
	var city: City = s["city"]
	var death: Node = s["death"]
	wc._on_resurrection_chosen()
	var hero: HeroController = wc._hero
	hero.followers.append(_make_follower(9, &"warrior"))
	wc._on_hero_died(&"burnout")
	assert_that(wc._hero_lifecycle._resurrection_city).is_null()
	var succ: Node = wc._hero_lifecycle._pending_successor
	wc._execute_succession()
	var new_hero: HeroController = wc._hero
	new_hero.followers.append(_make_follower(10, &"warrior"))
	city.storage[&"industry"] = float(GameNumbers.SUCCESSION_RESURRECT_IND)
	city.storage[&"gold"] = float(GameNumbers.SUCCESSION_RESURRECT_GOLD)
	wc._on_hero_died(&"exhaustion")
	assert_that(wc._hero_lifecycle._resurrection_city).is_equal(city)
	assert_that(wc._hero_lifecycle._deceased_hero).is_equal(new_hero)
	assert_that(death.res_city).is_equal(city)
	if is_instance_valid(hero): hero.free()
	new_hero.free()
	s["parent"].free()
	death.free()
	_free_node(wc._hero_lifecycle._pending_successor)
	wc.free()

func test_deathseq_resurrection_button_flow() -> void:
	var ds := _DeathSequenceScene.instantiate() as DeathSequence
	var city := _make_temple_city()
	var succ := _survival_hero()
	var emitted: Dictionary = {"v": false}
	ds.resurrection_chosen.connect(func() -> void: emitted["v"] = true)
	ds.show_death("Тест", &"exhaustion", {}, succ, city)
	var btn: Button = ds.get_node("Root/Panel/VBox/Buttons/ResurrectionButton")
	assert_bool(btn.visible).is_true()
	assert_that(btn.text).is_equal("Воскресить (500⚙ + 100💰)")
	btn.pressed.emit()
	assert_bool(emitted["v"]).is_true()
	ds.free()
	succ.free()
	var ds2 := _DeathSequenceScene.instantiate() as DeathSequence
	var succ2 := _survival_hero()
	ds2.show_death("Тест", &"battle", {}, succ2, null)
	assert_bool(ds2.get_node("Root/Panel/VBox/Buttons/ResurrectionButton").visible).is_false()
	ds2.free()
	succ2.free()
	var ds3 := _DeathSequenceScene.instantiate() as DeathSequence
	ds3.show_death("Тест", &"battle", {}, null, city)
	assert_bool(ds3.get_node("Root/Panel/VBox/Buttons/ResurrectionButton").visible).is_false()
	ds3.free()

func test_statuspanel_needs_line() -> void:
	var panel := load("res://scenes/ui/HeroStatusPanel.tscn").instantiate() as HeroStatusPanel
	var h := _survival_hero()
	h.hero_name = "Тест"
	h.needs.needs[NeedType.ID.REST] = 0.1
	panel.set_hero(h)
	panel.refresh()
	var text := panel._cond_label.text
	assert_bool(text.contains("😴⚠️ 10%")).is_true()
	assert_bool(text.contains("🤝 100%")).is_true()
	assert_bool(text.contains("💡 100%")).is_true()
	panel.free()
	h.free()

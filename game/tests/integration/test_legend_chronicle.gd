extends BaseTest












const _DeathSequenceScene = preload("res://scenes/ui/death_sequence.tscn")

const _ChronicleScreenScene = preload("res://scenes/ui/chronicle_screen.tscn")

var _bus_conns: Array = []

func _bus(sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	_bus_conns.append([sig, cb])

func _bus_clear() -> void:
	for p in _bus_conns:
		if p[1].is_valid() and p[0].is_connected(p[1]):
			p[0].disconnect(p[1])
	_bus_conns.clear()

func after_test() -> void:
	_bus_clear()

func test_chronicle_append_numbers_generations_and_emits() -> void:
	var c: Chronicle = Chronicle.new()
	var got: Array = []
	var conn := func(id, text): got.append([id, text])
	_bus(GameEventBus.chronicle_entry_added, conn)
	c.append({"hero_name": "Darkstorn", "path": "archivist", "outcome": "succession", "glory": 10})
	c.append({"hero_name": "Nyx", "path": "warrior", "outcome": "DEFEAT", "glory": 50})
	GameEventBus.chronicle_entry_added.disconnect(conn)
	assert_that(c.entries.size()).is_equal(2)
	assert_that(c.entries[0]["generation"]).is_equal(1)
	assert_that(c.entries[1]["generation"]).is_equal(2)
	assert_that(got.size()).is_equal(2)
	assert_bool(str(got[1]).find("Nyx") != -1).is_true()

func test_chronicle_append_without_bus_does_not_crash() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var bus_node: Node = tree.root.get_node("/root/GameEventBus")
	bus_node.name = "GameEventBusHidden"
	var c: Chronicle = Chronicle.new()
	var e: Dictionary = c.append(
		{"hero_name": "Ghost", "path": "archivist", "outcome": "DEFEAT"})
	bus_node.name = "GameEventBus"
	assert_that(c.entries.size()).is_equal(1)
	assert_that(int(e.get("generation", 0))).is_equal(1)

func test_chronicle_roundtrip_and_garbage() -> void:
	var c: Chronicle = Chronicle.new()
	c.append({"hero_name": "A", "path": "x", "outcome": "succession"})
	var c2: Chronicle = Chronicle.new()
	c2.from_array(c.to_array())
	assert_that(c2.entries.size()).is_equal(1)
	assert_that(str(c2.entries[0]["hero_name"])).is_equal("A")
	c2.entries[0]["hero_name"] = "MUTATED"
	assert_that(str(c.entries[0]["hero_name"])).is_equal("A")
	c2.from_array([42, "junk", {"hero_name": "B"}])
	assert_that(c2.entries.size()).is_equal(1)
	assert_that(str(c2.entries[0]["hero_name"])).is_equal("B")

func test_savedata_v5_migrates_to_v6_with_empty_chronicle() -> void:
	var v5 := {
		"version": 5,
		"generator_version": 1,
		"run_seed": 7,
		"date": {"month": 2, "week": 3, "day": 4},
		"hero": {"cell": [1, 2]},
		"world": {},
		"cities": [],
		"characters": [],
		"successor": {},
		"legend": {},
		"session": {},
	}
	var sd: SaveData = SaveData.new()
	sd.from_dict(v5)
	assert_that(int(sd.version)).is_equal(SaveData.CURRENT_VERSION)
	assert_bool(sd.chronicle.is_empty()).is_true()
	var sd2: SaveData = SaveData.new()
	sd2.from_dict(sd.to_dict())
	assert_that(int(sd2.version)).is_equal(SaveData.CURRENT_VERSION)
	assert_bool(sd2.chronicle.is_empty()).is_true()

func test_savedata_v6_chronicle_roundtrip() -> void:
	var sd: SaveData = SaveData.new()
	sd.version = 6
	sd.chronicle.append({"hero_name": "A", "path": "x", "outcome": "succession", "generation": 1})
	var sd2: SaveData = SaveData.new()
	sd2.from_dict(sd.to_dict())
	assert_that(sd2.chronicle.size()).is_equal(1)
	assert_that(str(sd2.chronicle[0]["hero_name"])).is_equal("A")

func _make_follower(uid: int, name: String, path: StringName) -> Follower:
	var f: Follower = Follower.new()
	f.uid = uid
	f.name = name
	f.path = path
	return f

func test_hero_status_panel_with_hero() -> void:
	var h = auto_free( HeroController.new())
	h.hero_name = "Darkstorn"
	h.path_id = &"archivist"
	h.combat_hp = 5
	h.max_combat_hp = 10
	h.followers = [_make_follower(1, "Nyx", &"archivist")]
	var panel: HeroStatusPanel = load("res://scenes/ui/hero_status_panel.tscn").instantiate() as HeroStatusPanel
	add_child(panel)
	panel.set_hero(h)
	var title: String = str(panel.get_node("VBox/Title").text)
	assert_bool(title.find("Darkstorn") != -1).is_true()
	assert_bool(title.find("archivist") != -1).is_true()
	var followers: String = str(panel.get_node("VBox/FollowersLabel").text)
	assert_bool(followers.find("Nyx") != -1).is_true()
	h.free()
	panel.free()

func test_hero_status_panel_without_hero() -> void:
	var panel: HeroStatusPanel = load("res://scenes/ui/hero_status_panel.tscn").instantiate() as HeroStatusPanel
	add_child(panel)
	var title: String = str(panel.get_node("VBox/Title").text)
	assert_bool(title.find("Герой") != -1).is_true()
	var cond: String = str(panel.get_node("VBox/ConditionLabel").text)
	assert_that(cond).is_equal("")
	panel.free()

func test_death_sequence_with_successor() -> void:
	var ds: DeathSequence = _DeathSequenceScene.instantiate()
	add_child(ds)
	var succ = auto_free( HeroController.new())
	succ.hero_name = "Nyx"
	succ.path_id = &"warrior"
	ds.show_death("Darkstorn", &"battle", {"turns": 10, "date": {"month": 1, "week": 2, "day": 3}}, succ)
	var title: String = str(ds.get_node("Root/Panel/VBox/Title").text)
	assert_bool(title.find("цикл продолжится") != -1).is_true()
	assert_bool(ds.get_node("Root/Panel/VBox/Buttons/SuccessorButton").visible).is_true()
	assert_bool(ds.get_node("Root/Panel/VBox/Buttons/MenuButton").visible).is_false()
	var reason: String = str(ds.get_node("Root/Panel/VBox/Reason").text)
	assert_bool(reason.find("в бою") != -1).is_true()
	succ.free()
	ds.free()

func test_death_sequence_terminal() -> void:
	var ds: DeathSequence = _DeathSequenceScene.instantiate()
	add_child(ds)
	ds.show_death("Darkstorn", &"battle", {}, null)
	var title: String = str(ds.get_node("Root/Panel/VBox/Title").text)
	assert_bool(title.find("цикл оборвался") != -1).is_true()
	assert_bool(ds.get_node("Root/Panel/VBox/Buttons/MenuButton").visible).is_true()
	assert_bool(ds.get_node("Root/Panel/VBox/Buttons/SuccessorButton").visible).is_false()
	ds.free()

func test_death_sequence_successor_signal() -> void:
	var ds: DeathSequence = _DeathSequenceScene.instantiate()
	add_child(ds)
	var fired: Array = []
	ds.successor_chosen.connect(func(): fired.append(1))
	var succ = auto_free( HeroController.new())
	ds.show_death("A", &"battle", {}, succ)
	ds.get_node("Root/Panel/VBox/Buttons/SuccessorButton").pressed.emit()
	assert_that(fired.size()).is_equal(1)
	succ.free()
	ds.free()

func test_chronicle_screen_newest_first() -> void:
	var cs: ChronicleScreen = _ChronicleScreenScene.instantiate()
	add_child(cs)
	var entries: Array = [
		{"hero_name": "First", "path": "a", "outcome": "succession", "generation": 1, "end_turn": 5, "glory": 1, "battles_won": 0, "battles_lost": 0},
		{"hero_name": "Last", "path": "b", "outcome": "DEFEAT", "generation": 2, "end_turn": 9, "glory": 9, "battles_won": 1, "battles_lost": 1},
	]
	cs.show_entries(entries)
	var list: VBoxContainer = cs.get_node("Root/Panel/VBox/Scroll/List")
	var first: String = str(list.get_child(0).text)
	assert_bool(first.find("Last") != -1).is_true()
	assert_bool(first.find("2.") != -1).is_true()
	cs.free()

func test_chronicle_screen_empty() -> void:
	var cs: ChronicleScreen = _ChronicleScreenScene.instantiate()
	add_child(cs)
	cs.show_entries([])
	var list: VBoxContainer = cs.get_node("Root/Panel/VBox/Scroll/List")
	var txt: String = str(list.get_child(0).text)
	assert_bool(txt.find("Летопись пуста") != -1).is_true()
	cs.free()

func _make_wc() -> WorldController:
	var wc = auto_free( WorldController.new())
	wc._rng = TestFactories.seeded(7225)
	var mgr = auto_free( CityManager.new())
	var c: City = City.new()
	c.uid = 1
	c.display_name = &"Highhold"
	c.owner = &"player"
	mgr.register_city(c)
	wc._cities = mgr
	wc._succession = SuccessionController.new()
	var persistence: WorldPersistence = WorldPersistence.new(null)
	persistence.session = GameSession.new(42)
	wc._persistence = persistence
	var sys := HeroLifecycleSystem.new()
	sys.setup(wc, wc._persistence, wc._rng, wc._cities, null, null, null, null, null, null, wc._succession, null)
	wc._hero_lifecycle = sys
	return wc

func test_on_hero_died_defers_succession() -> void:
	var wc := _make_wc()
	var h = auto_free( HeroController.new())
	h.hero_name = "Darkstorn"
	h.path_id = &"archivist"
	h.followers = [_make_follower(1, "Nyx", &"archivist")]
	wc._hero = h
	wc._on_hero_died(&"battle")
	assert_that(wc.get_hero()).is_null()
	assert_bool(wc.is_death_sequence_open()).is_true()
	assert_that(wc._hero_lifecycle._pending_successor).is_not_null()
	assert_that(str(wc._hero_lifecycle._deceased_snapshot.get("hero_name", ""))).is_equal("Darkstorn")
	var fired: Array = []
	var conn := func(hero): fired.append(hero)
	_bus(GameEventBus.hero_successor, conn)
	var entries: Array = []
	var entry_conn := func(_id, _text): entries.append(1)
	_bus(GameEventBus.chronicle_entry_added, entry_conn)
	wc._execute_succession()
	GameEventBus.hero_successor.disconnect(conn)
	GameEventBus.chronicle_entry_added.disconnect(entry_conn)
	assert_that(fired.size()).is_equal(1)
	assert_bool(wc.get_hero() == fired[0]).is_true()
	assert_bool(wc.is_death_sequence_open()).is_false()
	assert_that(wc._persistence.chronicle.entries.size()).is_equal(1)
	var e: Dictionary = wc._persistence.chronicle.entries[0]
	assert_that(entries.size()).is_equal(1)
	assert_that(str(e.get("outcome", ""))).is_equal("succession")
	assert_that(str(e.get("hero_name", ""))).is_equal("Darkstorn")
	assert_that(int(e.get("generation", -1))).is_equal(1)
	h.free()
	wc._cities.free()
	wc.free()

func test_on_hero_died_terminal_no_succession() -> void:
	var wc := _make_wc()
	wc._persistence.session.state = 2
	var h = auto_free( HeroController.new())
	h.hero_name = "Last"
	h.path_id = &"archivist"
	h.followers = [_make_follower(1, "Nyx", &"archivist")]
	wc._hero = h
	wc._on_hero_died(&"battle")
	assert_that(wc.get_hero()).is_null()
	assert_bool(wc.is_death_sequence_open()).is_true()
	assert_that(wc._hero_lifecycle._pending_successor).is_null()
	assert_bool(wc._persistence.chronicle.entries.is_empty()).is_true()
	h.free()
	wc._cities.free()
	wc.free()

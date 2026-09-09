extends RefCounted

const DeathSequenceScene = preload("res://scenes/ui/DeathSequence.tscn")
const ChronicleScreenScene = preload("res://scenes/ui/ChronicleScreen.tscn")

var _world_ref: WeakRef = null

var _persistence = null
var _rng: RandomNumberGenerator = null
var _cities = null
var _map_gen = null
var _event_router = null
var _ui_manager = null
var battle_coordinator = null
var interaction_controller = null
var _bootstrap_result = null
var _succession = null
var _camera: Node = null

var _death_seq = null
var _chronicle_screen = null
var _pending_successor: HeroController = null
var _deceased_snapshot: Dictionary = {}
var _deceased_hero: HeroController = null
var _resurrection_city: City = null
var _connected_hero_signals: bool = false

func setup(
	p: Node2D,
	persistence,
	rng,
	cities,
	map_gen,
	event_router,
	ui_manager,
	battle_coord,
	interaction,
	bootstrap_result,
	succession,
	camera
) -> void:
	_world_ref = weakref(p)
	_persistence = persistence
	_rng = rng
	_cities = cities
	_map_gen = map_gen
	_event_router = event_router
	_ui_manager = ui_manager
	battle_coordinator = battle_coord
	interaction_controller = interaction
	_bootstrap_result = bootstrap_result
	_succession = succession
	_camera = camera
	if not GameEventBus.hero_died.is_connected(on_hero_died):
		GameEventBus.hero_died.connect(on_hero_died)

func _get_world() -> Node2D:
	if _world_ref == null:
		return null
	return _world_ref.get_ref()

func on_hero_died(cause: StringName) -> void:
	var world := _get_world()
	if world == null:
		return
	var deceased := _hero_ptr()
	if deceased == null:
		return
	_deceased_snapshot = {
		"hero_name": str(deceased.hero_name),
		"path": String(deceased.path_id),
	}
	var session = _persistence.session if _persistence != null else null
	if session != null and session.is_terminal():
		_disconnect_hero_signals(deceased)
		_remove_hero(deceased)
		_show_death_sequence(str(_deceased_snapshot.get("hero_name", "?")), cause, null)
		return
	var successor := _plan_succession(deceased)
	if successor == null:
		GameLogger.world("Succession: no eligible follower — run ends")
		_disconnect_hero_signals(deceased)
		_remove_hero(deceased)
		_show_death_sequence(str(_deceased_snapshot.get("hero_name", "?")), cause, null)
		return
	_pending_successor = successor
	var res_city: City = _find_resurrection_city(deceased)
	_resurrection_city = res_city
	if res_city != null:
		_deceased_hero = deceased
		_disconnect_hero_signals(deceased)
		_detach_hero(deceased)
	else:
		_disconnect_hero_signals(deceased)
		_remove_hero(deceased)
	_show_death_sequence(str(_deceased_snapshot.get("hero_name", "?")), cause, successor, res_city)

func is_death_sequence_open() -> bool:
	return _death_seq != null and is_instance_valid(_death_seq) and _death_seq.visible

func _show_death_sequence(
	deceased_name: String,
	cause: StringName,
	successor: Node,
	res_city: City = null
) -> void:
	var world := _get_world()
	if world == null:
		return
	if _death_seq == null or not is_instance_valid(_death_seq):
		if _ui_manager != null and is_instance_valid(_ui_manager.death_sequence):
			_death_seq = _ui_manager.death_sequence
		else:
			_death_seq = DeathSequenceScene.instantiate()
			_death_seq.name = "DeathSequence"
			world.add_child(_death_seq)
		if not _death_seq.successor_chosen.is_connected(_execute_succession):
			_death_seq.successor_chosen.connect(_execute_succession)
		if not _death_seq.return_to_menu.is_connected(_on_death_return_to_menu):
			_death_seq.return_to_menu.connect(_on_death_return_to_menu)
		if not _death_seq.chronicle_requested.is_connected(_on_death_chronicle_requested):
			_death_seq.chronicle_requested.connect(_on_death_chronicle_requested)
		if not _death_seq.resurrection_chosen.is_connected(_on_resurrection_chosen):
			_death_seq.resurrection_chosen.connect(_on_resurrection_chosen)
	_death_seq.show_death(deceased_name, cause, _run_summary(), successor, res_city)

func _execute_succession() -> void:
	var successor := _pending_successor
	_pending_successor = null
	if successor == null:
		return
	if is_death_sequence_open():
		_death_seq.visible = false
	_free_deceased()
	_reincarnate(successor)
	GameEventBus.hero_successor.emit(successor)
	_append_succession_entry()

func _find_resurrection_city(deceased: HeroController) -> City:
	if _succession == null or _cities == null:
		return null
	if deceased != null and deceased.resurrected_once:
		return null
	var cost: Dictionary = _succession.default_resurrection_cost()
	for c in _cities.cities:
		if c != null and c.owner == &"player" and c.can_resurrect(cost):
			return c
	return null

func _on_resurrection_chosen() -> void:
	var city := _resurrection_city
	var hero := _deceased_hero
	_resurrection_city = null
	_deceased_hero = null
	if hero == null or city == null or _succession == null:
		return
	if _pending_successor != null and is_instance_valid(_pending_successor):
		_pending_successor.free()
	_pending_successor = null
	_succession.resurrect_hero(city)
	hero.revive_at(city)
	hero.resurrected_once = true
	_install_hero(hero)
	_connect_hero_signals(hero)
	if is_death_sequence_open():
		_death_seq.visible = false
	GameLogger.world("Succession: %s resurrected in %s" % [hero.hero_name, city.display_name])

func _disconnect_hero_signals(hero: Node) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	if _event_router != null and _event_router.has_method("_disconnect_hero_signals"):
		_event_router.call("_disconnect_hero_signals", hero)
	_connected_hero_signals = false

func _connect_hero_signals(hero: Node) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	if _event_router != null and _event_router.has_method("_connect_hero_signals"):
		_event_router.call("_connect_hero_signals", hero)
	_connected_hero_signals = true

func _detach_hero(deceased: Node) -> void:
	if deceased != null and is_instance_valid(deceased) and deceased.get_parent() != null:
		deceased.get_parent().remove_child(deceased)
	if _hero_ptr() == deceased:
		_set_hero_ptr(null)

func _free_deceased() -> void:
	if _deceased_hero != null and is_instance_valid(_deceased_hero):
		_deceased_hero.free()
	_deceased_hero = null
	_resurrection_city = null

func _append_succession_entry() -> void:
	if _persistence == null or _persistence.chronicle == null:
		return
	var sum := _run_summary()
	_persistence.chronicle.append({
		"hero_name": _deceased_snapshot.get("hero_name", "?"),
		"path": _deceased_snapshot.get("path", ""),
		"end_turn": sum["turns"],
		"cities": sum["cities_owned"],
		"glory": sum["glory"],
		"battles_won": sum["battles_won"],
		"battles_lost": sum["battles_lost"],
		"outcome": "succession",
	})
	_deceased_snapshot = {}

func _on_death_chronicle_requested() -> void:
	var entries: Array = []
	if _persistence != null and _persistence.chronicle != null:
		entries = _persistence.chronicle.to_array()
	var world := _get_world()
	if world == null:
		return
	if _chronicle_screen == null or not is_instance_valid(_chronicle_screen):
		if _ui_manager != null and is_instance_valid(_ui_manager.chronicle_screen):
			_chronicle_screen = _ui_manager.chronicle_screen
		else:
			_chronicle_screen = ChronicleScreenScene.instantiate()
			_chronicle_screen.name = "ChronicleScreen"
			world.add_child(_chronicle_screen)
	_chronicle_screen.show_entries(entries)

func _on_death_return_to_menu() -> void:
	_free_deceased()
	var world := _get_world()
	if world != null:
		world.get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _run_summary() -> Dictionary:
	var turns := 0
	var glory := 0
	var cities_left := 0
	if _cities != null:
		turns = int(_cities.current_turn)
		if _cities.glory != null:
			glory = int(round(_cities.glory.total))
		for c in _cities.cities:
			if c != null and c.owner == &"player":
				cities_left += 1
	var s: GameSession = _persistence.session if _persistence != null else null
	var date: Dictionary = _persistence.get_date() if _persistence != null else {}
	return {
		"turns": turns,
		"date": {
			"month": int(date.get("month", 1)),
			"week": int(date.get("week", 1)),
			"day": int(date.get("day", 1)),
		},
		"cities_owned": cities_left,
		"glory": glory,
		"battles_won": int(s.battles_won) if s != null else 0,
		"battles_lost": int(s.battles_lost) if s != null else 0,
		"generations": (int(s.successions) if s != null else 0) + 1,
	}

func _plan_succession(deceased: HeroController) -> HeroController:
	if _succession == null or _cities == null or deceased == null:
		return null
	return _succession.on_hero_died(
		deceased, _rng, _cities.cities, _cities)

func _remove_hero(deceased: Node) -> void:
	var active := _hero_ptr()
	if deceased != null and is_instance_valid(deceased) and deceased.get_parent() != null:
		deceased.get_parent().remove_child(deceased)
	if active == deceased:
		_set_hero_ptr(null)
	if deceased != null and is_instance_valid(deceased):
		deceased.queue_free()

func _reincarnate(successor: HeroController) -> void:
	var old := _hero_ptr()
	if old != null:
		_disconnect_hero_signals(old)
	_remove_hero(old)
	_install_hero(successor)
	_connect_hero_signals(successor)
	GameLogger.world("Succession: successor took the legend")

func _install_hero(hero: HeroController) -> void:
	var world := _get_world()
	if world == null:
		return
	_set_hero_ptr(hero)
	world.add_child(hero)
	hero.city_manager = _cities
	if _map_gen != null:
		hero.setup(_map_gen)
	if _map_gen != null and _map_gen.has_valid_tilemap():
		hero.position = _map_gen.map_to_local(hero.current_cell)
	if is_instance_valid(battle_coordinator):
		battle_coordinator.hero = hero
	if is_instance_valid(interaction_controller):
		interaction_controller.hero = hero
	if _bootstrap_result != null:
		if _bootstrap_result.enemy_proc != null:
			_bootstrap_result.enemy_proc._hero = hero
		if _bootstrap_result.input_controller != null:
			_bootstrap_result.input_controller.hero = hero
		if _bootstrap_result.shortcuts != null:
			_bootstrap_result.shortcuts._hero = hero
	if _event_router != null:
		_event_router.hero = hero
	if _ui_manager != null:
		_ui_manager._hero = hero
		_ui_manager.ui.reattach_hero(hero, _camera)
		if is_instance_valid(_ui_manager.inventory_screen):
			_ui_manager.inventory_screen.set_hero(hero)
		if is_instance_valid(_ui_manager.city_screen):
			_ui_manager.city_screen.hero = hero

func _hero_ptr() -> HeroController:
	var world := _get_world()
	if world != null and world.has_method("get_hero"):
		return world.get_hero()
	return null

func _set_hero_ptr(hero: HeroController) -> void:
	var world := _get_world()
	if world != null and world.has_method("set_hero"):
		world.set_hero(hero)

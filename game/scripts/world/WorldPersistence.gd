class_name WorldPersistence
extends RefCounted
const _ShardManager = preload("res://scripts/core/ShardManager.gd")
const _HeroProfile = preload("res://scripts/data/HeroBuildProfile.gd")

var _save_manager: SaveManager
var session: GameSession = null
var chronicle: Chronicle = Chronicle.new()
var _date: Dictionary = {"month": 1, "week": 1, "day": 1}
var world_delta: WorldStateDelta = null
var visibility = null

var _last_save_dict: Dictionary = {}


var _shards_memory: Dictionary = {}

static var next_seed: int = 0
static var pending_save: SaveData = null
static var pending_new_game: _HeroProfile = null


func _init(save_manager: SaveManager) -> void:
	_save_manager = save_manager


func get_run_seed() -> int:
	if next_seed != 0:
		var s := next_seed
		next_seed = 0
		return s

	if OS.has_environment("GAME_RUN_SEED"):
		var env_seed := int(OS.get_environment("GAME_RUN_SEED"))
		return env_seed & 0x7FFFFFFF

	if OS.has_feature("editor"):
		return GameNumbers.EDITOR_SEED

	return int(Time.get_unix_time_from_system()) & 0x7FFFFFFF


func get_session_for_seed(seed: int) -> GameSession:
	return GameSession.new(seed)


func save_game(hero: HeroController, cities: Array = [], characters: Array = []) -> bool:
	if session == null or hero == null or world_delta == null:
		return false

	var save_data := SaveData.new()
	save_data.run_seed = session.run_seed
	save_data.date = _date.duplicate()
	save_data.hero = hero.serialize()
	if visibility != null:
		world_delta.set_fog_explored(visibility.serialize_explored())
	save_data.world = world_delta.serialize()
	var cities_arr: Array = []
	for c in cities:
		cities_arr.append(c.serialize())
	save_data.cities = cities_arr
	save_data.characters = characters
	save_data.session = session.serialize()
	save_data.chronicle = chronicle.to_array()
	var _mgr := _ShardManager.instance()
	var _active := _mgr.active_id
	save_data.active_shard_id = _active

	
	
	var shards_data: Dictionary = _shards_memory.duplicate(true)
	shards_data[_active] = {
		"world": world_delta.serialize(),
		"cities": cities_arr,
		"characters": characters,
		"hero": hero.serialize(),
		"date": _date.duplicate(),
		"run_seed": session.run_seed,
		"last_active_turn": _date_turn(),
	}
	_prune_old_shards(shards_data, _date_turn())
	save_data.shards = shards_data
	_shards_memory = shards_data

	_last_save_dict = save_data.to_dict()
	var err := _save_manager.save_game(save_data)
	if err == SaveManager.SaveError.OK:
		GameLogger.world("Game saved to %s" % SaveManager.SAVE_PATH)
	return err == SaveManager.SaveError.OK


func _date_turn() -> int:
	# date linearization instead of a turn counter (GameSession has no current_turn field)
	return int(_date.get("month", 1)) * 100000 + int(_date.get("week", 1)) * 100 + int(_date.get("day", 1))


func _prune_old_shards(shards: Dictionary, current_turn: int) -> void:
	const MAX_SHARDS := 10
	const MAX_INACTIVE_TURNS := 50
	if shards.size() <= MAX_SHARDS:
		return
	var to_remove: Array = []
	for shard_id in shards:
		var shard_data: Dictionary = shards[shard_id]
		var last_active: int = int(shard_data.get("last_active_turn", 0))
		if current_turn - last_active > MAX_INACTIVE_TURNS:
			to_remove.append(shard_id)
	for shard_id in to_remove:
		shards.erase(shard_id)
	if shards.size() > MAX_SHARDS:
		var sorted_shards: Array = shards.keys()
		sorted_shards.sort_custom(func(a, b):
			var a_turn: int = int(shards[a].get("last_active_turn", 0))
			var b_turn: int = int(shards[b].get("last_active_turn", 0))
			return a_turn < b_turn
		)
		while shards.size() > MAX_SHARDS:
			# FIX: no explicit String annotation — keys may be StringName, which would
			# crash the Variant->String cast on erase(). Use untyped Variant.
			var oldest = sorted_shards.pop_front()
			shards.erase(oldest)


func load_game() -> SaveData:
	var result: Dictionary = _save_manager.load_game()
	return result.get("data", null) as SaveData

func last_save_dict() -> Dictionary:
	return _last_save_dict

func load_game_with_error() -> Dictionary:
	return _save_manager.load_game()


func request_load_game() -> SaveData:
	var data := load_game()
	if data == null or not data.is_valid():
		GameLogger.world("No valid save found")
		return null
	pending_save = data
	return data


func restart_game(seed_value: int) -> void:
	next_seed = seed_value


func set_date(month: int, week: int, day: int) -> void:
	_date = {"month": month, "week": week, "day": day}


func get_date() -> Dictionary:
	return _date.duplicate()


func apply_loaded_save(data: SaveData, ctx) -> void:
	if ctx == null:
		push_warning("WorldPersistence: apply_loaded_save called with null ctx")
		return
	if data == null or not data.is_valid():
		return

	if ctx.world_delta == null:
		ctx.world_delta = WorldStateDelta.new()

	ctx.world_delta.deserialize(data.world)

	if session != null:
		session.deserialize(data.session)
	chronicle.from_array(data.chronicle)

	if visibility != null:
		visibility.load_explored(data.world.get("fog_explored", []))
		_recompute_visible(visibility, ctx)

	if data.date != null:
		set_date(
			int(data.date.get("month", 1)),
			int(data.date.get("week", 1)),
			int(data.date.get("day", 1))
		)
	if ctx.ui_manager:
		ctx.ui_manager.set_date(
			int(get_date().get("month", 1)),
			int(get_date().get("week", 1)),
			int(get_date().get("day", 1))
		)

	for cell in ctx.world_delta.defeated_enemies:
		if ctx.map_gen:
			ctx.map_gen.enemy_stacks.erase(cell)
		if ctx.spawner:
			ctx.spawner.remove_enemy_at(cell)

	for cell in ctx.world_delta.removed_resources:
		if ctx.map_gen:
			ctx.map_gen.resource_cells.erase(cell)
		if ctx.spawner:
			ctx.spawner.remove_resource_at(cell)


	for cell in ctx.world_delta.opened_chests:
		if ctx.spawner:
			ctx.spawner.remove_chest_at(cell)

	for cell in ctx.world_delta.removed_scrolls:
		if ctx.spawner:
			ctx.spawner.remove_scroll_at(cell)

	for cell in ctx.world_delta.captured_villages:
		if ctx.spawner:
			ctx.spawner.capture_village(cell)

	if ctx.resource_node_manager:
		for cell in ctx.world_delta.discovered_nodes:
			ctx.resource_node_manager.mark_discovered(cell)
		for cell in ctx.world_delta.exhausted_nodes:
			ctx.resource_node_manager.mark_exhausted(cell)

	if ctx.terrain_resource_manager != null:
		ctx.terrain_resource_manager.mark_exhausted(
			ctx.world_delta.terrain_exhausted_cells)

	_restore_cities(data, ctx)
	_restore_characters(data, ctx)

	
	if not data.shards.is_empty():
		_shards_memory = data.shards.duplicate(true)

	if ctx.camera and ctx.hero:
		ctx.camera.center_on(ctx.hero.position)

	if ctx.ui_manager:
		ctx.ui_manager.refresh_ui()

	GameLogger.world(
		"Loaded save: seed=%d, cell=%s" % [
			data.run_seed,
			str(ctx.hero.current_cell if ctx.hero else Vector2i(-1, -1))
		]
	)


func _recompute_visible(visibility, ctx) -> void:
	if ctx.map_gen == null:
		return
	var sources: Array = []
	if ctx.hero != null and ctx.hero.current_cell is Vector2i:
		sources.append(ctx.hero.current_cell)
	var cm = ctx.cities
	if cm != null:
		for c in cm.cities:
			if c != null and c.owner == &"player" and c.center is Vector2i:
				sources.append(c.center)
	visibility.set_map_size(ctx.map_gen.map_width, ctx.map_gen.map_height)
	if visibility.recompute(ctx.hero.current_cell, sources,
		GameNumbers.FOG_HERO_SIGHT, GameNumbers.FOG_CITY_SIGHT):
		if ctx.map_gen.visibility == null:
			ctx.map_gen.visibility = visibility
		ctx.map_gen.apply_fog(visibility)


func _restore_cities(data: SaveData, ctx) -> void:
	if not (ctx.cities is Node):
		return
	if not (data.cities is Array) or (data.cities as Array).is_empty():
		return
	var cities_mgr: CityManager = ctx.cities
	if ctx.world_delta != null:
		for cell in ctx.world_delta.captured_villages:
			var village := CityFactory.create_village(
				cell, CityFactory.village_name(data.run_seed, cell), data.run_seed)
			cities_mgr.register_city(village)
	var all: Array = cities_mgr.cities
	var saved_count: int = (data.cities as Array).size()
	var restored := 0
	for d in data.cities:
		var city := _find_city(all, int(d.get("uid", 0)), saved_count, d.get("center", {}))
		if city == null:
			GameLogger.warn("Load: город uid=%s не найден — пропущен" % d.get("uid", "?"))
			continue
		city.deserialize(d)
		restored += 1
	if restored > 0:
		GameLogger.world("Loaded cities: %d" % restored)


func _find_city(all: Array, city_uid: int, saved_count: int, saved_center: Variant) -> City:
	for c in all:
		if c.uid == city_uid:
			return c
	
	if saved_center is Dictionary:
		var cell := Vector2i(int(saved_center.get("x", 0)), int(saved_center.get("y", 0)))
		for c in all:
			if c.center == cell:
				return c
	if all.size() == 1 and saved_count == 1:
		return all[0]
	return null


func _restore_characters(data: SaveData, ctx) -> void:
	if ctx.character_registry == null:
		return
	if not (data.characters is Array) or (data.characters as Array).is_empty():
		return
	ctx.character_registry.deserialize(data.characters)
	GameLogger.world("Loaded characters: %d" % (data.characters as Array).size())

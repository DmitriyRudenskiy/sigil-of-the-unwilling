class_name WorldPersistence
extends RefCounted
## Save / load / restart / seed / session state.

var _save_manager: SaveManager
var session: GameSession = null
var _date: Dictionary = {"month": 1, "week": 1, "day": 1}
var world_delta: WorldStateDelta = null

static var next_seed: int = 0
static var pending_save: SaveData = null


func _init(save_manager: SaveManager) -> void:
	_save_manager = save_manager


func get_run_seed() -> int:
	if next_seed != 0:
		var s := next_seed
		next_seed = 0
		return s

	if OS.has_feature("editor"):
		return GameSettings.EDITOR_SEED

	return int(Time.get_unix_time_from_system()) & 0x7FFFFFFF


func get_session_for_seed(seed: int) -> GameSession:
	return GameSession.new(seed)


func save_game(hero: HeroController) -> bool:
	if session == null or hero == null or world_delta == null:
		return false

	var save_data := SaveData.new()
	save_data.run_seed = session.run_seed
	save_data.date = _date.duplicate()
	save_data.hero = hero.serialize()
	save_data.world = world_delta.serialize()

	var ok := _save_manager.save_game(save_data)
	if ok:
		GameLogger.world("Game saved to %s" % SaveManager.SAVE_PATH)
	return ok


func load_game() -> SaveData:
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
	if data == null or not data.is_valid():
		return

	if ctx.world_delta == null:
		ctx.world_delta = WorldStateDelta.new()

	ctx.world_delta.deserialize(data.world)

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

	# Remove defeated enemies
	for cell in ctx.world_delta.defeated_enemies:
		if ctx.map_gen:
			ctx.map_gen.enemy_stacks.erase(cell)
		if ctx.spawner:
			ctx.spawner.remove_enemy_at(cell)

	# Remove collected resources
	for cell in ctx.world_delta.removed_resources:
		if ctx.map_gen:
			ctx.map_gen.resource_cells.erase(cell)
		if ctx.spawner:
			ctx.spawner.remove_resource_at(cell)

	# Remove opened chests
	for cell in ctx.world_delta.opened_chests:
		if ctx.spawner:
			ctx.spawner.remove_chest_at(cell)

	# Remove picked scrolls
	for cell in ctx.world_delta.removed_scrolls:
		if ctx.spawner:
			ctx.spawner.remove_scroll_at(cell)

	# Capture villages
	for cell in ctx.world_delta.captured_villages:
		if ctx.spawner:
			ctx.spawner.capture_village(cell)

	# Restore resource node states
	if ctx.resource_node_manager:
		for cell in ctx.world_delta.discovered_nodes:
			ctx.resource_node_manager.mark_discovered(cell)
		for cell in ctx.world_delta.exhausted_nodes:
			ctx.resource_node_manager.mark_exhausted(cell)

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

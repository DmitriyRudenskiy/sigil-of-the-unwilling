class_name WorldPersistence
extends RefCounted
## Save / load / restart / seed / session state.

var _save_manager: SaveManager
var session: GameSession = null
## legend-chronicle: летопись поколений (персистентная, save v6).
var chronicle: Chronicle = Chronicle.new()
var _date: Dictionary = {"month": 1, "week": 1, "day": 1}
var world_delta: WorldStateDelta = null
## fog-of-war: карта видимости (наследует WorldController). null — без fog.
var visibility = null

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


## cities — Array[City] (сериализуются сами); characters — результат
## CharacterRegistry.serialize() (save v3: Каскад Сложности).
func save_game(hero: HeroController, cities: Array = [], characters: Array = []) -> bool:
	if session == null or hero == null or world_delta == null:
		return false

	var save_data := SaveData.new()
	save_data.run_seed = session.run_seed
	save_data.date = _date.duplicate()
	save_data.hero = hero.serialize()
	# fog-of-war: разведённая сетка сохраняется вместе с миром.
	if visibility != null:
		world_delta.set_fog_explored(visibility.serialize_explored())
	save_data.world = world_delta.serialize()
	var cities_arr: Array = []
	for c in cities:
		cities_arr.append(c.serialize())
	save_data.cities = cities_arr
	save_data.characters = characters
	# endgame: состояние забега (state/end_reason/счётчики) — липкое
	# терминальное состояние переживает save/load.
	save_data.session = session.serialize()
	# legend-chronicle: летопись поколений (save v6).
	save_data.chronicle = chronicle.to_array()

	var err := _save_manager.save_game(save_data)
	if err == SaveManager.SaveError.OK:
		GameLogger.world("Game saved to %s" % SaveManager.SAVE_PATH)
	return err == SaveManager.SaveError.OK


func load_game() -> SaveData:
	var result: Dictionary = _save_manager.load_game()
	return result.get("data", null) as SaveData

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
	if data == null or not data.is_valid():
		return

	if ctx.world_delta == null:
		ctx.world_delta = WorldStateDelta.new()

	ctx.world_delta.deserialize(data.world)

	# endgame: восстановить состояние забега ДО любого использования
	# (терминальный сейв → WorldController сразу покажет экран).
	if session != null:
		session.deserialize(data.session)
	# legend-chronicle: восстановить летопись (save v6; v5-сейвы — пусто).
	chronicle.from_array(data.chronicle)

	# fog-of-war: восстановить разведённую сетку и пересчитывать видимое.
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

	# --- Сохранение v3: города и персонажи (Каскад Сложности) ---
	_restore_cities(data, ctx)
	_restore_characters(data, ctx)

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


## Fog-of-war: пересчёт видимости из текущей позиции героя и городов
## (разведённая сетка уже восстановлена в load_explored).
func _recompute_visible(visibility, ctx) -> void:
	if ctx.map_gen == null:
		return
	var sources: Array = []
	if ctx.hero != null and ctx.hero.current_cell is Vector2i:
		sources.append(ctx.hero.current_cell)
	# ctx.cities — CityManager (Node), не Array.
	var cm = ctx.cities
	if cm != null:
		for c in cm.cities:
			if c != null and c.owner == &"player" and c.center is Vector2i:
				sources.append(c.center)
	visibility.set_map_size(ctx.map_gen.map_width, ctx.map_gen.map_height)
	if visibility.recompute(ctx.hero.current_cell, sources,
		GameSettings.FOG_HERO_SIGHT, GameSettings.FOG_CITY_SIGHT):
		if ctx.map_gen.visibility == null:
			ctx.map_gen.visibility = visibility
		ctx.map_gen.apply_fog(visibility)


func _restore_cities(data: SaveData, ctx) -> void:
	## Города пересозданы при бутстрапе — по uid возвращаем прогресс.
	## v2-сейв (cities пусто) — не трогает.
	## city-in-world: после бутстрапа существует только столица (uid 0), а
	## захваченные деревни — нет. Пересоздаём их из world_delta
	## (порядок регистрации: сначала столица, потом деревни в порядке захвата
	## из delta — уиды совпадают с оригинальным прогоном), ПОСЛЕМатчируем по uid.
	if not (ctx.cities is Node):
		return
	if not (data.cities is Array) or (data.cities as Array).is_empty():
		return
	var cities_mgr: CityManager = ctx.cities
	if ctx.world_delta != null:
		for cell in ctx.world_delta.captured_villages:
			# Пересоздаём безусловно: у города из сейва центр может отличаться
			# от capture-cell (перенос), а временное совпадение с бутстоп-столицей
			# безопасно — deserialize сразу вернёт оба города на их места.
			var village := CityFactory.create_village(
				cell, CityFactory.village_name(data.run_seed, cell), data.run_seed)
			cities_mgr.register_city(village)
	var all: Array = cities_mgr.cities
	var saved_count: int = (data.cities as Array).size()
	var restored := 0
	for d in data.cities:
		var city := _find_city(all, int(d.get("uid", 0)), saved_count)
		if city == null:
			GameLogger.warn("Load: город uid=%s не найден — пропущен" % d.get("uid", "?"))
			continue
		city.deserialize(d)
		restored += 1
	if restored > 0:
		GameLogger.world("Loaded cities: %d" % restored)


func _find_city(all: Array, city_uid: int, saved_count: int) -> City:
	for c in all:
		if c.uid == city_uid:
			return c
	# Fallback: единственный город (столица) — единственный и в сейве.
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

class_name WorldSpawner
extends Node2D
## Спавн и удаление объектов мира: деревни, ресурсы, враги, сундуки.

const ServiceContainer = preload("res://scripts/core/ServiceContainer.gd")
const ServiceLocator = preload("res://scripts/core/ServiceLocator.gd")

var map: MapGenerator = null
var rng: RandomNumberGenerator = null

var _resource_nodes: Dictionary = {}
var _enemy_nodes: Dictionary = {}
var _village_nodes: Dictionary = {}
var _chest_nodes: Dictionary = {}
var _chests: Dictionary = {}
var _scroll_nodes: Dictionary = {}
var _scrolls: Dictionary = {}
var _services: ServiceContainer = null

func setup_services(services: ServiceContainer) -> void:
	_services = services


func spawn_all() -> void:
	if map == null or not map.has_valid_tilemap():
		return
	_spawn_villages()
	_spawn_resources()
	_spawn_enemies()
	_spawn_chests()
	_spawn_scrolls()


func remove_resource_at(cell: Vector2i) -> bool:
	if not _resource_nodes.has(cell):
		return false

	var node: Node2D = _resource_nodes[cell]
	node.queue_free()
	_resource_nodes.erase(cell)
	# Синхронизируем модель, чтобы GET_STATE (map_resources) отражал сбор.
	if map != null and map.resource_cells.has(cell):
		map.resource_cells.erase(cell)

	return true


func remove_enemy_at(cell: Vector2i) -> bool:
	if not _enemy_nodes.has(cell):
		return false

	var node: Node2D = _enemy_nodes[cell]
	node.queue_free()
	_enemy_nodes.erase(cell)

	return true


func capture_village(cell: Vector2i) -> bool:
	if not _village_nodes.has(cell):
		return false

	var node: Node2D = _village_nodes[cell]
	var flag := node.get_node_or_null("Flag")
	if flag != null:
		flag.text = "🏳️"
		return true
	return false


func _spawn_villages() -> void:
	for cell in map.village_cells:
		var v := Node2D.new()
		v.set_meta("cell", cell)
		var sp := Sprite2D.new()
		# Triangle + rectangle village placeholder
		var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
		# Triangle roof (y 0-19): fill_rect per row
		for y in 20:
			var half_w := int((24 - y) * 0.8)
			if half_w > 0:
				img.fill_rect(Rect2i(24 - half_w, y, half_w * 2, 1), Color(0.7, 0.2, 0.1))
		# Rect body (y 20-41)
		img.fill_rect(Rect2i(10, 20, 29, 22), Color(0.6, 0.5, 0.3))
		sp.texture = ImageTexture.create_from_image(img)
		sp.z_index = 5
		v.add_child(sp)
		var flag := Label.new()
		flag.name = "Flag"
		flag.text = "🚩"
		flag.add_theme_font_size_override("font_size", 16)
		flag.position = Vector2(18, -20)
		v.add_child(flag)
		v.position = map.map_to_local(cell)
		add_child(v)
		_village_nodes[cell] = v


func _spawn_resources() -> void:
	var icons := ["🪵", "🧪", "🪨", "🟡", "🔷", "💎", "🪙"]
	for cell in map.resource_cells:
		var res_type: int = map.resource_cells[cell]
		var r := Node2D.new()
		r.set_meta("cell", cell)
		r.set_meta("res_type", res_type)
		var lbl := Label.new()
		lbl.text = icons[res_type] if res_type < icons.size() else "?"
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.position = Vector2(-12, -12)
		r.add_child(lbl)
		r.position = map.map_to_local(cell)
		r.z_index = 6
		add_child(r)
		_resource_nodes[cell] = r


func _spawn_enemies() -> void:
	var units_reg: Node = ServiceLocator.resolve(null, &"units")
	for cell in map.enemy_stacks:
		var army: Array = map.enemy_stacks[cell]
		var e := Node2D.new()
		e.set_meta("enemy_cell", cell)
		var sp := Sprite2D.new()

		var first_unit = army[0]
		var key: String = first_unit.get_key()
		var portrait_path := UnitSprites.find_portrait_small(key)
		if portrait_path != "":
			sp.texture = load(portrait_path)
		else:
			sp.texture = PlaceholderTexture.circle(
				20,
				Color(0.7, 0.15, 0.1),
				Color(0.2, 0.05, 0.05)
			)
		sp.z_index = 6
		e.add_child(sp)
		e.position = map.map_to_local(cell)
		add_child(e)
		_enemy_nodes[cell] = e


func remove_chest_at(cell: Vector2i) -> bool:
	if not _chest_nodes.has(cell):
		return false
	var node: Node2D = _chest_nodes[cell]
	node.queue_free()
	_chest_nodes.erase(cell)
	_chests.erase(cell)
	return true


func get_chest_at(cell: Vector2i) -> ArtifactChest:
	return _chests.get(cell, null)


func get_enemy_defender_bonus() -> Dictionary:
	var r = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.seed = GameSettings.EDITOR_SEED
	return {"defense": r.randi_range(GameSettings.MAP_ENEMY_DEFENSE_BONUS_MIN, GameSettings.MAP_ENEMY_DEFENSE_BONUS_MAX)}


func _spawn_chests() -> void:

	var chest_rng := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		chest_rng.seed = GameSettings.EDITOR_SEED
	var placed := 0
	var attempts := 0
	while placed < GameSettings.CHEST_COUNT and attempts < GameSettings.CHEST_PLACE_ATTEMPTS:
		attempts += 1
		var cell := Vector2i(chest_rng.randi_range(GameSettings.SPAWN_CHEST_MIN_BORDER, map.map_width - 4), chest_rng.randi_range(GameSettings.SPAWN_CHEST_MIN_BORDER, map.map_height - 4))
		if not map.is_walkable(cell):
			continue
		if map.enemy_stacks.has(cell) or map.resource_cells.has(cell) or cell in map.village_cells:
			continue
		if _chests.has(cell):
			continue
		var nearby_enemy := false
		for nb in HexUtils.get_all_neighbors(cell):
			if map.enemy_stacks.has(nb):
				nearby_enemy = true
				break
		if nearby_enemy:
			continue
		var art_reg: Node = ServiceLocator.resolve(null, &"artifacts")
		var artifact: Artifact = art_reg.random_of_rarity(Artifact.Rarity.MINOR, chest_rng)
		if artifact == null:
			continue
		var chest := ArtifactChest.new()
		chest.id = "chest_%s" % cell
		chest.artifact = artifact
		chest.cell = cell
		chest.gold_reward = chest_rng.randi_range(GameSettings.CHEST_GOLD_MIN, GameSettings.CHEST_GOLD_MAX)
		_chests[cell] = chest
		var n := Node2D.new()
		n.position = map.map_to_local(cell)
		n.z_index = 7
		var sp := Sprite2D.new()
		var img := Image.create(32, 24, false, Image.FORMAT_RGBA8)
		img.fill_rect(Rect2i(0, 0, 32, 4), Color(0.8, 0.6, 0.2))
		img.fill_rect(Rect2i(0, 4, 32, 15), Color(0.6, 0.4, 0.1))
		img.fill_rect(Rect2i(0, 19, 32, 5), Color(0.4, 0.25, 0.08))
		sp.texture = ImageTexture.create_from_image(img)
		n.add_child(sp)
		add_child(n)
		_chest_nodes[cell] = n
		placed += 1


# ==================== REMOVAL (for save/load) ====================
# These are handled by the primary removal functions above.
# (Removed duplicate definitions of remove_enemy_at, remove_resource_at, remove_chest_at, capture_village)


# ==================== SCROLLS ====================

func _spawn_scrolls() -> void:
	var scroll_count: int = max(2, map.map_width / 3)
	var placed: int = 0
	var attempts: int = 0
	var chest_rng := rng if rng != null else RandomNumberGenerator.new()
	while placed < scroll_count and attempts < GameSettings.SPAWN_SCROLL_MAX_ATTEMPTS:
		attempts += 1
		var cell := Vector2i(chest_rng.randi_range(GameSettings.SPAWN_CHEST_MIN_BORDER, map.map_width - 4), chest_rng.randi_range(GameSettings.SPAWN_CHEST_MIN_BORDER, map.map_height - 4))
		if not map.is_walkable(cell):
			continue
		if map.enemy_stacks.has(cell) or map.resource_cells.has(cell) or cell in map.village_cells:
			continue
		if _chests.has(cell):
			continue
		if _scrolls.has(cell):
			continue
		var spell_reg: Node = ServiceLocator.resolve(null, &"spells")
		var all_spells: Array = spell_reg.get_all_spells()
		if all_spells.is_empty():
			continue
		var spell = all_spells[chest_rng.randi() % all_spells.size()]
		_scrolls[cell] = spell.id
		var n := Node2D.new()
		n.position = map.map_to_local(cell)
		n.z_index = 6
		var sp := Sprite2D.new()
		var img := Image.create(24, 32, false, Image.FORMAT_RGBA8)
		img.fill_rect(Rect2i(0, 0, 24, 32), Color(0.3, 0.15, 0.5))
		img.fill_rect(Rect2i(0, 0, 4, 32), Color(0.5, 0.3, 0.7))
		img.fill_rect(Rect2i(20, 0, 4, 32), Color(0.5, 0.3, 0.7))
		sp.texture = ImageTexture.create_from_image(img)
		n.add_child(sp)
		add_child(n)
		_scroll_nodes[cell] = n
		placed += 1


func remove_scroll_at(cell: Vector2i) -> void:
	if _scroll_nodes.has(cell):
		_scroll_nodes[cell].queue_free()
		_scroll_nodes.erase(cell)
	_scrolls.erase(cell)


func get_scroll_at(cell: Vector2i) -> StringName:
	return _scrolls.get(cell, &"")


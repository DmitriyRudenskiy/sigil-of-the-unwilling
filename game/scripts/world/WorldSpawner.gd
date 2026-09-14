class_name WorldSpawner
extends Node2D

const VillageEntityScene = preload("res://scenes/entities/VillageEntity.tscn")
const ResourceEntityScene = preload("res://scenes/entities/ResourceEntity.tscn")
const EnemyEntityScene = preload("res://scenes/entities/EnemyEntity.tscn")
const ChestEntityScene = preload("res://scenes/entities/ChestEntity.tscn")
const ScrollEntityScene = preload("res://scenes/entities/ScrollEntity.tscn")

const MAP_RESOURCE_ICON_SCALE := 0.5

var map: MapGenerator = null
var rng: RandomNumberGenerator = null

var _resource_nodes: Dictionary = {}
var _enemy_nodes: Dictionary = {}
var _village_nodes: Dictionary = {}
var _chest_nodes: Dictionary = {}
var _chests: Dictionary = {}
var _scroll_nodes: Dictionary = {}
var _scrolls: Dictionary = {}
var fog_vis = null

func apply_fog_visibility(vis) -> void:
	fog_vis = vis
	if vis == null:
		return
	for cell in _enemy_nodes:
		_enemy_nodes[cell].visible = vis.is_visible(cell)
	for cell in _resource_nodes:
		_resource_nodes[cell].visible = vis.is_visible(cell)
	for cell in _chest_nodes:
		_chest_nodes[cell].visible = vis.is_visible(cell)
	for cell in _scroll_nodes:
		_scroll_nodes[cell].visible = vis.is_visible(cell)
	for cell in _village_nodes:
		_village_nodes[cell].visible = vis.is_visible(cell)

var _sprite_cache: Dictionary = {}

func _cached_texture(key: String, builder: Callable) -> ImageTexture:
	if not _sprite_cache.has(key):
		_sprite_cache[key] = builder.call()
	return _sprite_cache[key]

func spawn_all() -> void:
	if map == null or not map.has_valid_tilemap():
		return
	_spawn_villages()
	_spawn_resources()
	_spawn_enemies()
	_spawn_chests()
	_spawn_scrolls()

func get_res_type_at(cell: Vector2i) -> int:
	var node: Node2D = _resource_nodes.get(cell)
	if node == null:
		return -1
	return int(node.get_meta("res_type", -1))

func remove_resource_at(cell: Vector2i) -> bool:
	if not _resource_nodes.has(cell):
		return false

	var node: Node2D = _resource_nodes[cell]
	node.queue_free()
	_resource_nodes.erase(cell)
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

func move_enemy_visual(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if map == null or not _enemy_nodes.has(from_cell):
		return
	var node: Node2D = _enemy_nodes[from_cell]
	_enemy_nodes.erase(from_cell)
	_enemy_nodes[to_cell] = node
	node.set_meta("enemy_cell", to_cell)
	node.position = map.map_to_local(to_cell)
	if fog_vis != null:
		node.visible = fog_vis.is_visible(to_cell)

func spawn_enemy_visual(cell: Vector2i, army: Array) -> void:
	if map == null or _enemy_nodes.has(cell) or army.is_empty():
		return
	var e: Node2D = _make_enemy_node(cell, army)
	if e == null:
		return
	add_child(e)
	_enemy_nodes[cell] = e
	if fog_vis != null:
		e.visible = fog_vis.is_visible(cell)

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
		var v = VillageEntityScene.instantiate()
		v.set_meta("cell", cell)
		var sp = v.get_node("Sprite")
		sp.texture = _cached_texture("village", func() -> ImageTexture:
			var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
			for y in 20:
				var half_w := int((24 - y) * 0.8)
				if half_w > 0:
					img.fill_rect(Rect2i(24 - half_w, y, half_w * 2, 1), Color(0.7, 0.2, 0.1))
			img.fill_rect(Rect2i(10, 20, 29, 22), Color(0.6, 0.5, 0.3))
			return ImageTexture.create_from_image(img))
		v.position = map.map_to_local(cell)
		add_child(v)
		_village_nodes[cell] = v

func _spawn_resources() -> void:
	for cell in map.resource_cells:
		var res_type: int = map.resource_cells[cell]
		var r = ResourceEntityScene.instantiate()
		r.set_meta("cell", cell)
		r.set_meta("res_type", res_type)
		var sp = r.get_node("Icon")
		sp.texture = ResourceAtlas.texture_for_type(res_type)
		if sp.texture == null:
			sp.texture = PlaceholderTexture.circle(
				16,
				ResourceIcons.get_color(ResourceIcons.res_type_id(res_type)),
				Color(0.12, 0.10, 0.08)
			)
		sp.scale = Vector2(MAP_RESOURCE_ICON_SCALE, MAP_RESOURCE_ICON_SCALE)
		r.position = map.map_to_local(cell)
		add_child(r)
		_resource_nodes[cell] = r

## Пересоздать вражеские ноды из model.enemy_stacks (после ре-спавна моделей,
## например, когда place_enemies пересчитан с учётом городов).
func respawn_enemies() -> void:
	for n in _enemy_nodes.values():
		n.queue_free()
	_enemy_nodes.clear()
	_spawn_enemies()

func _spawn_enemies() -> void:
	for cell in map.enemy_stacks:
		var e := _make_enemy_node(cell, map.enemy_stacks[cell])
		if e == null:
			continue
		add_child(e)
		_enemy_nodes[cell] = e

func _make_enemy_node(cell: Vector2i, army: Array) -> Node2D:
	if army.is_empty():
		return null
	var e = EnemyEntityScene.instantiate()
	e.set_meta("enemy_cell", cell)
	var sp = e.get_node("Sprite")
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
	e.position = map.map_to_local(cell)
	return e

func chest_cells() -> Array:
	return _chests.keys()

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
		r.seed = GameNumbers.EDITOR_SEED
	return {"defense": r.randi_range(GameNumbers.MAP_ENEMY_DEF_BONUS_MIN, GameNumbers.MAP_ENEMY_DEF_BONUS_MAX)}

func _spawn_chests() -> void:
	var chest_rng := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		chest_rng.seed = GameNumbers.EDITOR_SEED
	var art_reg: Node = Services.resolve(&"artifacts")
	if art_reg == null:
		return

	var placed := 0
	var attempts := 0
	while placed < GameNumbers.CHEST_COUNT and attempts < GameNumbers.CHEST_PLACE_ATTEMPTS:
		attempts += 1
		var cell := Vector2i(chest_rng.randi_range(GameNumbers.SPAWN_CHEST_MIN_BORDER, map.map_width - 4), chest_rng.randi_range(GameNumbers.SPAWN_CHEST_MIN_BORDER, map.map_height - 4))
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
		var artifact: Artifact = art_reg.random_of_rarity(Artifact.Rarity.MINOR, chest_rng)
		if artifact == null:
			continue
		var chest := ArtifactChest.new()
		chest.id = "chest_%s" % cell
		chest.artifact = artifact
		chest.cell = cell
		chest.gold_reward = chest_rng.randi_range(GameNumbers.CHEST_GOLD_MIN, GameNumbers.CHEST_GOLD_MAX)
		_chests[cell] = chest
		var n = ChestEntityScene.instantiate()
		n.position = map.map_to_local(cell)
		var sp = n.get_node("Sprite")
		sp.texture = _cached_texture("chest", func() -> ImageTexture:
			var img := Image.create(32, 24, false, Image.FORMAT_RGBA8)
			img.fill_rect(Rect2i(0, 0, 32, 4), Color(0.8, 0.6, 0.2))
			img.fill_rect(Rect2i(0, 4, 32, 15), Color(0.6, 0.4, 0.1))
			img.fill_rect(Rect2i(0, 19, 32, 5), Color(0.4, 0.25, 0.08))
			return ImageTexture.create_from_image(img))
		add_child(n)
		_chest_nodes[cell] = n
		placed += 1

func _spawn_scrolls() -> void:
	var scroll_count: int = max(2, int(map.map_width / 3.0))
	var placed: int = 0
	var attempts: int = 0
	var chest_rng := rng if rng != null else RandomNumberGenerator.new()
	var spell_reg: Node = Services.resolve(&"spells")
	if spell_reg == null:
		return
	var all_spells: Array = spell_reg.get_all_spells()
	if all_spells.is_empty():
		return
	while placed < scroll_count and attempts < GameNumbers.SPAWN_SCROLL_MAX_ATTEMPTS:
		attempts += 1
		var cell := Vector2i(chest_rng.randi_range(GameNumbers.SPAWN_CHEST_MIN_BORDER, map.map_width - 4), chest_rng.randi_range(GameNumbers.SPAWN_CHEST_MIN_BORDER, map.map_height - 4))
		if not map.is_walkable(cell):
			continue
		if map.enemy_stacks.has(cell) or map.resource_cells.has(cell) or cell in map.village_cells:
			continue
		if _chests.has(cell):
			continue
		if _scrolls.has(cell):
			continue
		var spell = all_spells[chest_rng.randi() % all_spells.size()]
		_scrolls[cell] = spell.id
		var n = ScrollEntityScene.instantiate()
		n.position = map.map_to_local(cell)
		var sp = n.get_node("Sprite")
		sp.texture = _cached_texture("scroll", func() -> ImageTexture:
			var img := Image.create(24, 32, false, Image.FORMAT_RGBA8)
			img.fill_rect(Rect2i(0, 0, 24, 32), Color(0.3, 0.15, 0.5))
			img.fill_rect(Rect2i(0, 0, 4, 32), Color(0.5, 0.3, 0.7))
			img.fill_rect(Rect2i(20, 0, 4, 32), Color(0.5, 0.3, 0.7))
			return ImageTexture.create_from_image(img))
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

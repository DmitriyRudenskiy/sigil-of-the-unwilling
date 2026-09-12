extends Node
class_name ResourceNodeManager

const ResourceNodeScene = preload("res://scenes/entities/ResourceNode.tscn")


var _nodes: Dictionary = {}
var _container: Node2D = null
var _rng: RandomNumberGenerator = null
var _resource_registry: Node = null
var _map_to_local_fn: Callable = Callable()

enum NodeError {
	OK,
	NODE_NOT_FOUND,
	INVALID_RESOURCE_DEF,
	ALREADY_DISCOVERED,
	NOT_DISCOVERED,
	EXTRACTION_KEY_MISSING,
}

signal resource_discovered(cell: Vector2i, resource_id: StringName)
signal resource_extracted(cell: Vector2i, resource_id: StringName, amount: int)
signal resource_exhausted(cell: Vector2i, resource_id: StringName)

func _get_def(id: StringName) -> ResourceDef:
	var reg := _resolve_registry()
	if reg == null:
		return null
	return reg.get_resource(id) as ResourceDef

func _get_hidden_by_biome(biome: String) -> Array:
	var reg := _resolve_registry()
	if reg == null:
		return []
	var all: Array = reg.get_by_biome(biome)
	var hidden: Array = []
	for item in all:
		if reg.is_hidden_resource((item as ResourceDef).id):
			hidden.append(item)
	return hidden

func _resolve_registry() -> Node:
	if _resource_registry == null:
		push_error("ResourceNodeManager: resource registry unavailable")
	return _resource_registry

func _get_biome_name(terrain_id: StringName) -> String:
	for i in HexUtils.TERRAIN_NAMES.size():
		if HexUtils.TERRAIN_NAMES[i] == terrain_id:
			return terrain_id as String
	return ""

func setup(container: Node2D, rng: RandomNumberGenerator, resource_registry: Node, map_to_local_fn: Callable = Callable()) -> void:
	_container = container
	_rng = rng
	_resource_registry = resource_registry
	_map_to_local_fn = map_to_local_fn

func apply_fog_visibility(vis) -> void:
	if vis == null:
		return
	for cell in _nodes:
		_nodes[cell].visible = vis.is_visible(cell)

func get_node_at(cell: Vector2i) -> ResourceNode:
	return _nodes.get(cell, null)

func generate_nodes_for_map(map_data: Dictionary) -> void:
	"""Generate hidden resource nodes based on biome data."""
	if _rng == null or _container == null:
		return

	var terrain_map: Dictionary = map_data.get("terrain", {})
	var width: int = map_data.get("width", 0)
	var height: int = map_data.get("height", 0)
	if width == 0 or height == 0:
		return

	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			if not terrain_map.has(cell):
				continue
			var terrain_id: int = int(terrain_map[cell])
			var biome: String = _terrain_to_biome(terrain_id)
			if biome == "":
				continue

			if _rng.randf() < 0.08:
				var hidden: Array = _get_hidden_by_biome(biome)
				if hidden.is_empty():
					continue

				var def: ResourceDef = hidden[_rng.randi() % hidden.size()] as ResourceDef
				var yield_amt := _rng.randi_range(def.yield_min, def.yield_max)
				_spawn_node(cell, def.id, yield_amt)

func _terrain_to_biome(terrain_id: int) -> String:
	if terrain_id < 0 or terrain_id >= HexUtils.TERRAIN_NAMES.size():
		return ""
	return HexUtils.TERRAIN_NAMES[terrain_id]

func _spawn_node(cell: Vector2i, resource_id: StringName, yield_amount: int) -> ResourceNode:
	var node: ResourceNode = ResourceNodeScene.instantiate()
	node.init_node(resource_id, cell, yield_amount)
	if _container:
		_container.add_child(node)
		if _map_to_local_fn.is_valid():
			node.position = _map_to_local_fn.call(cell)
	_nodes[cell] = node
	return node

func try_discover(cell: Vector2i, discovery_keys: Dictionary) -> Dictionary:
	"""Try to discover a hidden resource at cell.
	Returns {"error": NodeError, "discovered": bool}.
	discovery_keys: {skill_name: level, time: "noon"/"night", auto_tags: [...] }
	"""
	var node: ResourceNode = _nodes.get(cell, null)
	if node == null:
		return {"error": NodeError.NODE_NOT_FOUND, "discovered": false}
	if not node.is_hidden():
		return {"error": NodeError.ALREADY_DISCOVERED, "discovered": false}

	var def: ResourceDef = _get_def(node.resource_id)
	if def == null:
		GameLogger.error("ResourceNodeManager: unknown resource '%s' at %s" % [node.resource_id, cell], "World")
		return {"error": NodeError.INVALID_RESOURCE_DEF, "discovered": false}

	if def.discovery_auto:
		for tag in def.discovery_auto_tags:
			if discovery_keys.get(tag, false):
				node.discover()
				resource_discovered.emit(cell, node.resource_id)
				GameEventBus.resource_discovered.emit(cell, node.resource_id)
				return {"error": NodeError.OK, "discovered": true}

	if not def.discovery_skill.is_empty():
		var skill_level: int = int(discovery_keys.get(def.discovery_skill, 0))
		if skill_level >= 1:
			if not def.discovery_time.is_empty():
				var time_match: bool = discovery_keys.get("time", "") == def.discovery_time
				if not time_match:
					return {"error": NodeError.OK, "discovered": false}
			node.discover()
			resource_discovered.emit(cell, node.resource_id)
			GameEventBus.resource_discovered.emit(cell, node.resource_id)
			return {"error": NodeError.OK, "discovered": true}

	return {"error": NodeError.OK, "discovered": false}

func try_extract(cell: Vector2i, extraction_keys: Dictionary) -> Dictionary:
	"""Try to extract resources. Returns {"error": NodeError, "amount": int}.
	extraction_keys: {tag: bool, skill: int, unit: bool, tool: bool, consumable: bool, fire: bool}
	"""
	var node: ResourceNode = _nodes.get(cell, null)
	if node == null:
		return {"error": NodeError.NODE_NOT_FOUND, "amount": 0}
	if not node.is_discovered():
		return {"error": NodeError.NOT_DISCOVERED, "amount": 0}

	var def: ResourceDef = _get_def(node.resource_id)
	if def == null:
		GameLogger.error("ResourceNodeManager: unknown resource '%s' at %s" % [node.resource_id, cell], "World")
		return {"error": NodeError.INVALID_RESOURCE_DEF, "amount": 0}

	if not _check_extraction(def, extraction_keys):
		GameLogger.warn("ResourceNodeManager: extraction denied at %s (missing keys for '%s')" % [cell, def.id], "World")
		return {"error": NodeError.EXTRACTION_KEY_MISSING, "amount": 0}

	var amount: int = node.get_yield()
	node.reduce_yield(amount)
	if node.is_exhausted():
		resource_exhausted.emit(cell, node.resource_id)
		GameEventBus.resource_exhausted.emit(cell, node.resource_id)
	resource_extracted.emit(cell, node.resource_id, amount)
	GameEventBus.resource_extracted.emit(cell, node.resource_id, amount)
	return {"error": NodeError.OK, "amount": amount}

func _check_extraction(def: ResourceDef, keys: Dictionary) -> bool:

	if not def.extraction_tag.is_empty():
		if not keys.get(def.extraction_tag, false):
			return false

	if not def.extraction_skill.is_empty():
		if int(keys.get(def.extraction_skill, 0)) < 1:
			return false

	if not def.extraction_unit.is_empty():
		if not keys.get(def.extraction_unit, false):
			return false

	if not def.extraction_tool.is_empty():
		if not keys.get(def.extraction_tool, false):
			return false

	if not def.extraction_consumable.is_empty():
		if not keys.get(def.extraction_consumable, false):
			return false

	if def.extraction_fire:
		if not keys.get("fire", false):
			return false

	return true

func tick_daily() -> Array[Vector2i]:
	"""Called at end of day. Returns cells ready for removal."""
	var remove_cells: Array[Vector2i] = []
	for cell in _nodes:
		var node: ResourceNode = _nodes[cell]
		if node.is_exhausted():
			if node.tick_day() <= 0:
				remove_cells.append(cell)

	for cell in remove_cells:
		var node: ResourceNode = _nodes[cell]
		if node:
			node.queue_free()
		_nodes.erase(cell)

	return remove_cells

func remove_node(cell: Vector2i) -> void:
	if _nodes.has(cell):
		var node: ResourceNode = _nodes[cell]
		node.queue_free()
		_nodes.erase(cell)

func mark_discovered(cell: Vector2i) -> void:
	var node: ResourceNode = _nodes.get(cell, null)
	if node == null:
		return

	if node.is_hidden():
		node.discover()

func mark_exhausted(cell: Vector2i) -> void:
	var node: ResourceNode = _nodes.get(cell, null)
	if node == null:
		return

	if node.is_hidden():
		node.discover()

	if node.is_discovered():
		node.exhaust()

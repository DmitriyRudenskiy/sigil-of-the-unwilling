extends Node
class_name ResourceNodeManager
## Manages resource node lifecycle: generation, discovery, extraction, removal.

var _nodes: Dictionary = {}  # cell -> ResourceNode
var _container: Node2D = null
var _rng: RandomNumberGenerator = null

signal resource_discovered(cell: Vector2i, resource_id: StringName)
signal resource_extracted(cell: Vector2i, resource_id: StringName, amount: int)
signal resource_exhausted(cell: Vector2i, resource_id: StringName)


func setup(container: Node2D, rng: RandomNumberGenerator) -> void:
	_container = container
	_rng = rng


func get_node_at(cell: Vector2i) -> ResourceNode:
	return _nodes.get(cell, null)


func generate_nodes_for_map(map_data: Dictionary) -> void:
	"""Generate hidden resource nodes based on biome data."""
	if _rng == null or _container == null:
		return

	var terrain_map := map_data.get("terrain", {})
	var width := map_data.get("width", 0)
	var height := map_data.get("height", 0)
	if width == 0 or height == 0:
		return

	# Determine biome for each cell and spawn appropriate resources
	for y in height:
		for x in width:
			var cell := Vector2i(x, y)
			if not terrain_map.has(cell):
				continue
			var terrain_id := terrain_map[cell]
			var biome := _terrain_to_biome(terrain_id)
			if biome == "":
				continue

			# Hidden resource chance
			if _rng.randf() < 0.08:  # 8% chance per cell
				var candidates := ResourceRegistry.get_by_biome(biome)
				# Filter out non-hidden
				var hidden: Array = []
				for def in candidates:
					if ResourceRegistry.is_hidden_resource(def.id):
						hidden.append(def)
				if hidden.is_empty():
					continue

				var def := hidden[_rng.randi() % hidden.size()]
				var yield_amt := _rng.randi_range(def.yield_min, def.yield_max)
				_spawn_node(cell, def.id, yield_amt)


func _terrain_to_biome(terrain_id: StringName) -> String:
	match terrain_id:
		&"grass", &"forest": return "grass"
		&"sand", &"desert": return "sand"
		&"snow", &"ice": return "snow"
		&"swamp", &"marsh": return "swamp"
		&"mountain", &"volcano": return "mountain"
		_ : return ""


func _spawn_node(cell: Vector2i, resource_id: StringName, yield_amount: int) -> ResourceNode:
	var node := ResourceNode.new()
	node.init_node(resource_id, cell, yield_amount)
	if _container:
		_container.add_child(node)
	_nodes[cell] = node
	return node


func try_discover(cell: Vector2i, discovery_keys: Dictionary) -> bool:
	"""Try to discover a hidden resource at cell.
	discovery_keys: {skill_name: level, time: "noon"/"night", auto_tags: [...] }
	"""
	var node := _nodes.get(cell, null)
	if node == null or not node.is_hidden():
		return false

	var def := ResourceRegistry.get(node.resource_id)
	if def == null:
		return false

	# Check auto-discovery (undead/lizard units)
	if def.discovery_auto:
		for tag in def.discovery_auto_tags:
			if discovery_keys.get(tag, false):
				node.discover()
				resource_discovered.emit(cell, node.resource_id)
				return true

	# Check skill-based discovery
	if not def.discovery_skill.is_empty():
		var skill_level := discovery_keys.get(def.discovery_skill, 0)
		if skill_level >= 1:
			# Check time requirement
			if not def.discovery_time.is_empty():
				var time_match := discovery_keys.get("time", "") == def.discovery_time
				if not time_match:
					return false
			node.discover()
			resource_discovered.emit(cell, node.resource_id)
			return true

	return false


func try_extract(cell: Vector2i, extraction_keys: Dictionary) -> int:
	"""Try to extract resources. Returns amount extracted, 0 on failure.
	extraction_keys: {tag: bool, skill: int, unit: bool, tool: bool, consumable: bool, fire: bool}
	"""
	var node := _nodes.get(cell, null)
	if node == null or not node.is_discovered():
		return 0

	var def := ResourceRegistry.get(node.resource_id)
	if def == null:
		return 0

	if not _check_extraction(def, extraction_keys):
		return 0

	var amount := node.get_yield()
	node.reduce_yield(amount)
	if node.is_exhausted():
		resource_exhausted.emit(cell, node.resource_id)
	resource_extracted.emit(cell, node.resource_id, amount)
	return amount


func _check_extraction(def: ResourceRegistry.ResourceDef, keys: Dictionary) -> bool:
	# Tag-based extraction (e.g. strong_strike)
	if not def.extraction_tag.is_empty():
		if keys.get(def.extraction_tag, false):
			return true

	# Skill-based extraction
	if not def.extraction_skill.is_empty():
		if keys.get(def.extraction_skill, 0) >= 1:
			return true

	# Unit-based (requires matching unit type)
	if not def.extraction_unit.is_empty():
		if keys.get(def.extraction_unit, false):
			# May also need tool
			if not def.extraction_tool.is_empty():
				if keys.get(def.extraction_tool, false):
					# May also need consumable
					if not def.extraction_consumable.is_empty():
						if keys.get(def.extraction_consumable, false):
							return true
						return false
					return true
			return true

	# Fire-based extraction
	if def.extraction_fire:
		if keys.get("fire", false):
			return true

	return false


func tick_daily() -> Array[Vector2i]:
	"""Called at end of day. Returns cells ready for removal."""
	var remove_cells: Array[Vector2i] = []
	for cell in _nodes:
		var node: ResourceNode = _nodes[cell]
		if node.is_exhausted():
			if node.tick_day() <= 0:
				remove_cells.append(cell)

	for cell in remove_cells:
		var node := _nodes[cell]
		if node:
			node.queue_free()
		_nodes.erase(cell)

	return remove_cells


func remove_node(cell: Vector2i) -> void:
	if _nodes.has(cell):
		var node := _nodes[cell]
		node.queue_free()
		_nodes.erase(cell)

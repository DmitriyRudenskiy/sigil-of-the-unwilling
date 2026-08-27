class_name ResourceChainService
extends RefCounted
## Discovery / extraction key building + cache for resource nodes.

var _cached_extraction_keys: Dictionary = {}
var _extraction_cache_valid: bool = false


func build_discovery_keys(hero: HeroController) -> Dictionary:
	var keys: Dictionary = {}

	keys[&"nature_sense"] = hero.skills.get_skill(&"nature_sense")
	keys[&"keen_eye"] = hero.skills.get_skill(&"keen_eye")
	keys[&"navigation"] = hero.skills.get_skill(&"navigation")
	keys[&"geology"] = hero.skills.get_skill(&"geology")
	keys[&"alchemy"] = hero.skills.get_skill(&"alchemy")
	keys["time"] = hero.time.get_period_name()

	# Check for undead/lizard army tags
	var army_stacks: Array[UnitStack] = hero.army.get_army_for_battle()
	for stack in army_stacks:
		var unit_def = UnitRegistry.get_definition(stack.get_key())
		if unit_def:
			for tag in unit_def.tags:
				if tag in [&"undead", &"lizard"]:
					keys[StringName(tag)] = true

	return keys


func build_extraction_keys(hero: HeroController) -> Dictionary:
	if _extraction_cache_valid:
		return _cached_extraction_keys

	var keys: Dictionary = {}
	var army_stacks: Array[UnitStack] = hero.army.get_army_for_battle()

	# Tags and unit keys from army
	for stack in army_stacks:
		var unit_def = UnitRegistry.get_definition(stack.get_key())
		if unit_def:
			for tag in unit_def.tags:
				keys[StringName(tag)] = true
		keys[StringName(stack.get_key())] = true

	# Skills
	for skill in hero.skills.get_all():
		keys[StringName(skill)] = hero.skills.get_skill(skill)

	# Tools
	for tool_type in HeroTools.TOOL_TYPES:
		keys[StringName(tool_type)] = hero.tools.has_tool(StringName(tool_type))

	# Fire capability
	keys["fire"] = false

	_cached_extraction_keys = keys
	_extraction_cache_valid = true
	return keys


func invalidate_extraction_cache() -> void:
	_extraction_cache_valid = false


func try_extract(mgr: ResourceNodeManager, hero: HeroController, cell: Vector2i) -> int:
	if mgr == null:
		return 0
	var keys: Dictionary = build_extraction_keys(hero)
	return mgr.try_extract(cell, keys)

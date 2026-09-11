class_name ResourceChainService
extends RefCounted

const ToolType = preload("res://scripts/data/ToolType.gd")

var _extraction_cache: Dictionary = {}
var _discovery_cache: Dictionary = {}

func invalidate_extraction_cache() -> void:
	_extraction_cache.clear()
	_discovery_cache.clear()

func build_discovery_keys(hero: HeroController) -> Dictionary:
	if hero == null:
		return {}
	return _cached(hero.get_instance_id(), _discovery_cache,
		_discovery_fingerprint(hero), _build_discovery_keys.bind(hero))

func _build_discovery_keys(hero: HeroController) -> Dictionary:
	var keys: Dictionary = {}

	keys[&"nature_sense"] = hero.skills.get_skill(&"nature_sense")
	keys[&"keen_eye"] = hero.skills.get_skill(&"keen_eye")
	keys[&"navigation"] = hero.skills.get_skill(&"navigation")
	keys[&"geology"] = hero.skills.get_skill(&"geology")
	keys[&"alchemy"] = hero.skills.get_skill(&"alchemy")
	keys["time"] = hero.time.get_period_name()

	var units_reg: Node = Services.resolve(&"units")
	if hero.army != null:
		for stack in hero.army.army:
			if stack == null or not stack.is_alive(): continue
			var unit_def = units_reg.get_definition(stack.get_key())
			if unit_def:
				for tag in unit_def.tags:
					if tag in [&"undead", &"lizard"]:
						keys[StringName(tag)] = true

	return keys

func _discovery_fingerprint(hero: HeroController) -> String:
	var fp := ""
	if hero.skills != null:
		for skill in hero.skills.get_all():
			fp += StringName(skill) + ":" + str(int(hero.skills.get_skill(skill))) + ";"
	if hero.time != null:
		fp += "time:" + hero.time.get_period_name() + ";"
	if hero.army != null:
		for stack in hero.army.army:
			if stack == null or not stack.is_alive(): continue
			fp += StringName(stack.get_key()) + ";"
	return fp

func build_extraction_keys(hero: HeroController) -> Dictionary:
	if hero == null:
		return {}
	return _cached(hero.get_instance_id(), _extraction_cache,
		_extraction_fingerprint(hero), _build_extraction_keys.bind(hero))

func _build_extraction_keys(hero: HeroController) -> Dictionary:
	var keys: Dictionary = {}

	var units_reg: Node = Services.resolve(&"units")
	if hero.army != null:
		for stack in hero.army.army:
			if stack == null or not stack.is_alive(): continue
			var unit_def = units_reg.get_definition(stack.get_key())
			if unit_def:
				for tag in unit_def.tags:
					keys[StringName(tag)] = true
			keys[StringName(stack.get_key())] = true

	if hero.skills != null:
		for skill in hero.skills.get_all():
			keys[StringName(skill)] = hero.skills.get_skill(skill)

	if hero.tools != null:
		for tool_id in HeroTools.tool_types():
			keys[ToolType.to_name(tool_id)] = hero.tools.has_tool(tool_id)

	keys["fire"] = false

	return keys

func _cached(iid: int, cache: Dictionary, fp: String, build: Callable) -> Dictionary:
	var cached: Dictionary = cache.get(iid, {})
	if cached.has("fp") and cached["fp"] == fp and cached.has("keys"):
		return cached["keys"]
	var keys: Dictionary = build.call()
	cache[iid] = {"fp": fp, "keys": keys}
	return keys

func _extraction_fingerprint(hero: HeroController) -> String:
	var fp := ""
	if hero.army != null:
		for stack in hero.army.army:
			if stack == null or not stack.is_alive(): continue
			fp += StringName(stack.get_key()) + ";"
	if hero.skills != null:
		for skill in hero.skills.get_all():
			fp += StringName(skill) + ":" + str(int(hero.skills.get_skill(skill))) + ";"
	if hero.tools != null:
		for tool_id in HeroTools.tool_types():
			if hero.tools.has_tool(tool_id):
				fp += "T" + ToolType.to_name(tool_id)
	return fp

func try_extract(mgr: ResourceNodeManager, hero: HeroController, cell: Vector2i) -> Dictionary:
	if mgr == null:
		return {"error": ResourceNodeManager.NodeError.NODE_NOT_FOUND, "amount": 0}
	var keys: Dictionary = build_extraction_keys(hero)
	return mgr.try_extract(cell, keys)

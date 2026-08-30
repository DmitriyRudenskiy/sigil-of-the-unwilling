class_name ResourceChainService
extends RefCounted
## Discovery / extraction key building + cache for resource nodes.

const ServiceContainer = preload("res://core/ServiceContainer.gd")
const ServiceLocator = preload("res://core/ServiceLocator.gd")

var _services: ServiceContainer = null
# Кэш extraction-ключей: hero instance id → {"fp": fingerprint, "keys": Dictionary}.
# Fingerprint покрывает все входы (живые юниты + навыки + инструменты),
# поэтому кэш не может отдать устаревшие ключи; invalidate_extraction_cache()
# — публичный сброс (world persistence / смена мира).
var _extraction_cache: Dictionary = {}

func setup(services: ServiceContainer) -> void:
	_services = services


func invalidate_extraction_cache() -> void:
	_extraction_cache.clear()


func build_discovery_keys(hero: HeroController) -> Dictionary:
	var keys: Dictionary = {}

	keys[&"nature_sense"] = hero.skills.get_skill(&"nature_sense")
	keys[&"keen_eye"] = hero.skills.get_skill(&"keen_eye")
	keys[&"navigation"] = hero.skills.get_skill(&"navigation")
	keys[&"geology"] = hero.skills.get_skill(&"geology")
	keys[&"alchemy"] = hero.skills.get_skill(&"alchemy")
	keys["time"] = hero.time.get_period_name()

	# Check for undead/lizard army tags
	var units_reg: Node = ServiceLocator.resolve(null, &"units")
	for stack in hero.army.army:
		if stack == null or not stack.is_alive(): continue
		var unit_def = units_reg.get_definition(stack.get_key())
		if unit_def:
			for tag in unit_def.tags:
				if tag in [&"undead", &"lizard"]:
					keys[StringName(tag)] = true

	return keys


func build_extraction_keys(hero: HeroController) -> Dictionary:
	var iid: int = hero.get_instance_id()
	var fp := _extraction_fingerprint(hero)
	var cached: Dictionary = _extraction_cache.get(iid, {})
	if cached.has("fp") and cached["fp"] == fp and cached.has("keys"):
		return cached["keys"]
	var keys: Dictionary = {}

	# Tags and unit keys from army
	var units_reg: Node = ServiceLocator.resolve(null, &"units")
	for stack in hero.army.army:
		if stack == null or not stack.is_alive(): continue
		var unit_def = units_reg.get_definition(stack.get_key())
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

	_extraction_cache[iid] = {"fp": fp, "keys": keys}
	return keys


func _extraction_fingerprint(hero: HeroController) -> String:
	## Дешёвый отпечаток всех входов build_extraction_keys: если совпал —
	## полные ключи из кэша остаются корректными.
	var fp := ""
	if hero.army != null:
		for stack in hero.army.army:
			if stack == null or not stack.is_alive(): continue
			fp += StringName(stack.get_key()) + ";"
	if hero.skills != null:
		for skill in hero.skills.get_all():
			fp += StringName(skill) + ":" + str(int(hero.skills.get_skill(skill))) + ";"
	if hero.tools != null:
		for tool_type in HeroTools.TOOL_TYPES:
			if hero.tools.has_tool(StringName(tool_type)):
				fp += "T" + StringName(tool_type)
	return fp


func try_extract(mgr: ResourceNodeManager, hero: HeroController, cell: Vector2i) -> Dictionary:
	if mgr == null:
		return {"error": ResourceNodeManager.NodeError.NODE_NOT_FOUND, "amount": 0}
	var keys: Dictionary = build_extraction_keys(hero)
	return mgr.try_extract(cell, keys)

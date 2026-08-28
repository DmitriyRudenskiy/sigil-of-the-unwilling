extends Node
class_name ResourceRegistry
## Autoload: Resources. 11 hidden veins + 2 basic (wood/stone).

const ResourceDef = preload("res://data/ResourceDef.gd")

enum Rarity { COMMON, RARE }

var _resources: Dictionary = {}

func _ready() -> void:
	ensure_definitions()

func reset() -> void:
	_resources.clear()

func ensure_definitions() -> void:
	if not _resources.is_empty():
		return

	# grass/forest — Oak
	_add(&"oak", "Дуб", ["grass", "forest"], Rarity.COMMON,
		&"nature_sense", "", false, [],
		&"strong_strike", "", "", "", "", false,
		3, 5, 2.0, "🪵")

	# grass — Silver
	_add(&"silver", "Серебро", ["grass"], Rarity.RARE,
		&"keen_eye", "night", false, [],
		&"precise_strike", "", "", "", "", false,
		1, 2, 1.0, "🥈")

	# sand — Quartz
	_add(&"quartz", "Кварц", ["sand"], Rarity.COMMON,
		&"navigation", "noon", false, [],
		"", &"", &"worker", &"cart", "", false,
		2, 4, 1.0, "💎")

	# sand — Saltpeter
	_add(&"saltpeter", "Селитра", ["sand"], Rarity.COMMON,
		&"geology", "", false, [],
		"", &"", &"worker", "", &"skin_protection", false,
		2, 3, 1.0, "🧪")

	# sand — Turquoise
	_add(&"turquoise", "Бирюза", ["sand"], Rarity.RARE,
		&"geology", "", false, [],
		&"precise_strike", "", "", "", "", false,
		1, 1, 0.5, "🟢")

	# snow — Limonite
	_add(&"limonite", "Лимонит", ["snow"], Rarity.COMMON,
		&"", "", false, [],  # discovered via excavation: worker + shovel
		"", &"", "", "", "", true,  # fire aura or fire spell
		2, 3, 2.0, "🟤")

	# snow — Coal
	_add(&"coal", "Уголь", ["snow"], Rarity.COMMON,
		&"geology", "", false, [],
		"", &"", &"miner", "", "", false,
		3, 5, 1.0, "⬛")

	# snow — Gold
	_add(&"gold_ore", "Золото", ["snow"], Rarity.RARE,
		&"geology", "", false, [],
		"", &"", &"miner", &"precise_strike", "", false,
		1, 2, 1.0, "🥇")

	# swamp — Coal (auto-discovered)
	_add(&"coal_swamp", "Уголь (болото)", ["swamp"], Rarity.COMMON,
		"", "", true, [&"undead", &"lizard"],
		"", &"", &"miner", "", "", false,
		3, 5, 1.0, "⬛")

	# swamp — Bog Iron
	_add(&"bog_iron", "Болотное железо", ["swamp"], Rarity.COMMON,
		&"keen_eye", "", false, [],
		"", &"", "", "", "", false,
		2, 4, 2.0, "🔩")

	# swamp — Cinnabar
	_add(&"cinnabar", "Киноварь", ["swamp"], Rarity.RARE,
		&"alchemy", "", false, [],
		&"poison_immune", "", "", "", "", false,
		1, 1, 1.0, "🔴")

	# Basic resources (not hidden nodes)
	_add(&"wood", "Дерево", ["grass", "forest"], Rarity.COMMON,
		"", "", false, [],
		"", &"", &"worker", "", "", false,
		2, 2, 0.0, "🌲")

	_add(&"stone", "Камень", ["mountain"], Rarity.COMMON,
		"", "", false, [],
		"", &"", &"worker", "", "", false,
		2, 2, 0.0, "🪨")


func _add(id: StringName, name: String, biomes: Array[String], rarity: int,
		discovery_skill: StringName, discovery_time: String, discovery_auto: bool, discovery_auto_tags: Array[StringName],
		extraction_tag: StringName, extraction_skill: StringName, extraction_unit: StringName, extraction_tool: StringName, extraction_consumable: StringName, extraction_fire: bool,
		ymin: int, ymax: int, weight: float, icon: String) -> void:
	var def := ResourceDef.new()
	def.id = id
	def.display_name = name
	def.biomes = biomes
	def.rarity = rarity
	def.discovery_skill = discovery_skill
	def.discovery_time = discovery_time
	def.discovery_auto = discovery_auto
	def.discovery_auto_tags = discovery_auto_tags
	def.extraction_tag = extraction_tag
	def.extraction_skill = extraction_skill
	def.extraction_unit = extraction_unit
	def.extraction_tool = extraction_tool
	def.extraction_consumable = extraction_consumable
	def.extraction_fire = extraction_fire
	def.yield_min = ymin
	def.yield_max = ymax
	def.weight_per_unit = weight
	def.icon = icon
	_resources[id] = def


func get_resource(id: StringName) -> ResourceDef:
	ensure_definitions()
	return _resources.get(id, null) as ResourceDef


func get_all() -> Array[ResourceDef]:
	ensure_definitions()
	var result: Array[ResourceDef] = []
	for id in _resources:
		result.append(_resources[id])
	return result


func get_by_biome(biome: String) -> Array[ResourceDef]:
	ensure_definitions()
	var result: Array[ResourceDef] = []
	for id in _resources:
		var def: ResourceDef = _resources[id]
		if biome in def.biomes:
			result.append(def)
	return result


func is_hidden_resource(id: StringName) -> bool:
	return id != &"wood" and id != &"stone"


func get_hidden_resource_ids() -> Array[StringName]:
	ensure_definitions()
	var ids: Array[StringName] = []
	for id in _resources:
		if is_hidden_resource(id):
			ids.append(id)
	return ids

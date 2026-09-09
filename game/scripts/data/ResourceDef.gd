extends RefCounted
class_name ResourceDef

var id: StringName
var display_name: String
var biomes: Array[String] = []
var rarity: int
var discovery_skill: StringName = &""
var discovery_time: String = ""
var discovery_auto: bool = false
var discovery_auto_tags: Array[StringName] = []
var extraction_tag: StringName = &""
var extraction_skill: StringName = &""
var extraction_unit: StringName = &""
var extraction_tool: StringName = &""
var extraction_consumable: StringName = &""
var extraction_fire: bool = false
var yield_min: int = 1
var yield_max: int = 3
var weight_per_unit: float = 1.0
var icon: String = "⛏️"
var category: int = 0
var capacity: float = INF
var binom_pair: StringName = &""
var tier: int = 1

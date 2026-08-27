extends RefCounted
class_name ResourceDef

var id: StringName
var display_name: String
var biomes: Array[String] = []
var rarity: int  # 0=common, 1=rare
# Discovery keys
var discovery_skill: StringName = &""
var discovery_time: String = ""  # "noon" / "night" / ""
var discovery_auto: bool = false  # auto-marked on entry
var discovery_auto_tags: Array[StringName] = []
# Extraction keys
var extraction_tag: StringName = &""      # e.g. "strong_strike"
var extraction_skill: StringName = &""    # alternative skill key
var extraction_unit: StringName = &""     # e.g. "worker"
var extraction_tool: StringName = &""     # e.g. "cart"
var extraction_consumable: StringName = &""  # e.g. "skin_protection"
var extraction_fire: bool = false  # fire spell/aura alternative
# Yield and weight
var yield_min: int = 1
var yield_max: int = 3
var weight_per_unit: float = 1.0
# Icon emoji
var icon: String = "⛏️"

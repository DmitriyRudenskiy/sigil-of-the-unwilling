class_name Artifact
extends Resource
## Immutable definition of an artifact.

enum Rarity { MINOR, MAJOR, RELIC }
enum Slot {
    HEAD, NECK, TORSO, WEAPON, SHIELD,
    LEGS, BOOTS, RING_L, RING_R,
    MISC_A, MISC_B, SPELLBOOK,
}

@export var id: StringName
@export var display_name: String
@export var slot: Slot
@export var rarity: Rarity
@export var icon: Texture2D
@export var modifiers: Dictionary = {}
@export var special_effect: StringName = &""
@export var is_two_handed: bool = false
@export var value_gold: int = 0
@export var description: String = ""


func _init(
    p_id: StringName = &"",
    p_display_name: String = "",
    p_slot: Slot = Slot.MISC_A,
    p_rarity: Rarity = Rarity.MINOR,
    p_modifiers: Dictionary = {},
    p_special_effect: StringName = &"",
    p_is_two_handed: bool = false,
    p_value_gold: int = 0,
    p_description: String = ""
) -> void:
    id = p_id
    display_name = p_display_name
    slot = p_slot
    rarity = p_rarity
    modifiers = p_modifiers.duplicate()
    special_effect = p_special_effect
    is_two_handed = p_is_two_handed
    value_gold = p_value_gold
    description = p_description


func get_attack() -> int:
    return int(modifiers.get("attack", 0))


func get_defense() -> int:
    return int(modifiers.get("defense", 0))


func get_spell_power() -> int:
    return int(modifiers.get("spell_power", 0))


func get_knowledge() -> int:
    return int(modifiers.get("knowledge", 0))


func get_luck() -> int:
    return int(modifiers.get("luck", 0))


func get_morale() -> int:
    return int(modifiers.get("morale", 0))


func get_movement() -> int:
    return int(modifiers.get("movement", 0))


func get_stack_hp_bonus() -> int:
    return int(modifiers.get("stack_hp", 0))


func get_stack_hp_percent() -> float:
    return float(modifiers.get("stack_hp_percent", 0.0))


func get_stack_speed_bonus() -> int:
    return int(modifiers.get("stack_speed", 0))


func get_daily_gems() -> int:
    return int(modifiers.get("daily_gems", 0))


func get_castle_growth_percent() -> int:
    return int(modifiers.get("castle_growth_percent", 0))


func is_ring() -> bool:
    return slot == Slot.RING_L or slot == Slot.RING_R


func get_rarity_name() -> String:
    match rarity:
        Rarity.MINOR: return "Minor"
        Rarity.MAJOR: return "Major"
        Rarity.RELIC: return "Relic"
    return ""


func get_slot_name() -> String:
    match slot:
        Slot.HEAD: return "Head"
        Slot.NECK: return "Neck"
        Slot.TORSO: return "Torso"
        Slot.WEAPON: return "Weapon"
        Slot.SHIELD: return "Shield"
        Slot.LEGS: return "Legs"
        Slot.BOOTS: return "Boots"
        Slot.RING_L: return "Ring (Left)"
        Slot.RING_R: return "Ring (Right)"
        Slot.MISC_A: return "Misc A"
        Slot.MISC_B: return "Misc B"
        Slot.SPELLBOOK: return "Spellbook"
    return ""

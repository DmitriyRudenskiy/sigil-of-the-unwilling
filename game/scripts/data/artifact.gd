class_name Artifact
extends Resource

enum Rarity { MINOR, MAJOR, RELIC }
enum Slot {
    HEAD, NECK, TORSO, WEAPON, SHIELD,
    LEGS, BOOTS, RING_L, RING_R,
    MISC_A, MISC_B, SPELLBOOK,
}

enum DamageType { SLASHING, PIERCING, BLUDGEONING }
enum WeaponSize { TINY, SMALL, MEDIUM, LARGE }
enum WeaponCategory { SIMPLE, MARTIAL, EXOTIC }

enum AcBonusType { NONE, ARMOR, SHIELD, NATURAL, DEFLECTION, DODGE }

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
@export var weight: float = 0.0

var combat: Dictionary = {}
var armor: Dictionary = {}
var ac_bonus_type: AcBonusType = AcBonusType.NONE
var tier: int = 1  # social-stats-weapon-tech: тир оружия (1..5)

static func from_dict(data: Dictionary) -> Artifact:
    var a := Artifact.new()
    a.id = StringName(data.get("id", &""))
    a.display_name = str(data.get("display_name", ""))
    a.slot = data.get("slot", Slot.MISC_A)
    a.rarity = data.get("rarity", Rarity.MINOR)
    a.modifiers = (data.get("modifiers", {}) as Dictionary).duplicate()
    a.special_effect = StringName(data.get("special_effect", &""))
    a.is_two_handed = bool(data.get("is_two_handed", false))
    a.value_gold = int(data.get("value_gold", 0))
    a.description = str(data.get("description", ""))
    a.weight = float(data.get("weight", 0.0))
    a.combat = (data.get("combat", {}) as Dictionary).duplicate(true)
    a.armor = (data.get("armor", {}) as Dictionary).duplicate(true)
    a.ac_bonus_type = data.get("ac_bonus_type", AcBonusType.NONE)
    return a

func _init(
    p_id: StringName = &"",
    p_display_name: String = "",
    p_slot: Slot = Slot.MISC_A,
    p_rarity: Rarity = Rarity.MINOR,
    p_modifiers: Dictionary = {},
    p_special_effect: StringName = &"",
    p_is_two_handed: bool = false,
    p_value_gold: int = 0,
    p_description: String = "",
    p_weight: float = 0.0,
    p_combat: Dictionary = {},
    p_armor: Dictionary = {},
    p_ac_bonus_type: AcBonusType = AcBonusType.NONE
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
    weight = p_weight
    combat = p_combat.duplicate(true)
    armor = p_armor.duplicate(true)
    ac_bonus_type = p_ac_bonus_type

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

func get_damage_dice() -> String:
    return str(combat.get("damage_dice", ""))

func get_damage_types() -> Array:
    return combat.get("damage_types", []).duplicate()

func has_damage_type(dt: DamageType) -> bool:
    return get_damage_types().has(dt)

func get_crit_threat() -> int:
    return int(combat.get("crit_threat", 20))

func get_crit_multiplier() -> float:
    return float(combat.get("crit_multiplier", 2.0))

func get_proficiency() -> Array:
    return combat.get("proficiency", []).duplicate()

func is_proficient_in(cat: StringName) -> bool:
    return get_proficiency().has(cat)

func get_weapon_size() -> WeaponSize:
    return combat.get("weapon_size", WeaponSize.MEDIUM) as WeaponSize

func is_ranged() -> bool:
    return bool(combat.get("is_ranged", false))

func get_base_ac() -> int:
    return int(armor.get("base_ac", 0))

func get_max_dex_bonus() -> int:
    return int(armor.get("max_dex_bonus", 100))

func get_acp() -> int:
    return int(armor.get("acp", 0))

func get_asf() -> float:
    return float(armor.get("asf", 0.0))

func has_armor() -> bool:
    return armor.size() > 0 and get_base_ac() > 0

func get_ac_bonus_type() -> AcBonusType:
    return ac_bonus_type

static func damage_type_name(dt: DamageType) -> String:
    match dt:
        DamageType.SLASHING: return "Рубящий"
        DamageType.PIERCING: return "Колющий"
        DamageType.BLUDGEONING: return "Дробящий"
    return ""

func is_ring() -> bool:
    return slot == Slot.RING_L or slot == Slot.RING_R

func get_rarity_name() -> String:
    match rarity:
        Rarity.MINOR: return "Minor"
        Rarity.MAJOR: return "Major"
        Rarity.RELIC: return "Relic"
    return ""

func get_rarity_color() -> Color:
    match rarity:
        Rarity.MINOR: return ThemeConfig.C_RARITY_MINOR
        Rarity.MAJOR: return ThemeConfig.C_RARITY_MAJOR
        Rarity.RELIC: return ThemeConfig.C_RARITY_RELIC
    return Color.WHITE

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

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

## Габарит предмета в клетках сетки снаряжения (grid-inventory-and-merchant).
## Позиция — не производная от слота: копьё и лук живут в одном слоте WEAPON и
## занимают разное число клеток, поэтому габарит — поле данных. Значение по
## умолчанию берётся от слота; явное значение в данных перебивает таблицу.
## Числа — заявка на баланс (docs/07-balance.md §10).
const SLOT_CELLS: Dictionary = {
    Slot.HEAD: Vector2i(2, 2),
    Slot.NECK: Vector2i(1, 2),
    Slot.TORSO: Vector2i(2, 3),
    Slot.WEAPON: Vector2i(2, 3),
    Slot.SHIELD: Vector2i(2, 2),
    Slot.LEGS: Vector2i(2, 2),
    Slot.BOOTS: Vector2i(1, 2),
    Slot.RING_L: Vector2i(1, 1),
    Slot.RING_R: Vector2i(1, 1),
    Slot.MISC_A: Vector2i(1, 1),
    Slot.MISC_B: Vector2i(1, 1),
    Slot.SPELLBOOK: Vector2i(2, 2),
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
@export var weight: float = 0.0
## Габарит в клетках сетки; ZERO = «в данных не задан» → SLOT_CELLS по слоту.
## Поворот разрешён всем неквадратным предметам, отдельного флага нет.
@export var cells: Vector2i = Vector2i.ZERO

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
    var raw_cells = data.get("cells", Vector2i.ZERO)
    if raw_cells is Array and raw_cells.size() >= 2:
        a.cells = Vector2i(int(raw_cells[0]), int(raw_cells[1]))
    elif raw_cells is Vector2i:
        a.cells = raw_cells
    a.combat = (data.get("combat", {}) as Dictionary).duplicate(true)
    a.armor = (data.get("armor", {}) as Dictionary).duplicate(true)
    a.ac_bonus_type = data.get("ac_bonus_type", AcBonusType.NONE)
    a.tier = int(data.get("tier", 1))
    return a


## true, если предмет есть в статическом реестре (лоут/каталог).
## Крафтовые предметы (динамические id) сериализуются полностью (to_dict).
static func is_registry_artifact(art: Artifact) -> bool:
    if art == null:
        return false
    var art_reg: Node = Services.resolve(&"artifacts")
    if art_reg == null:
        return false
    return art_reg.get_by_id(art.id) != null


## Полная сериализация (для предметов вне статического реестра — крафт).
func to_dict() -> Dictionary:
    return {
        "id": str(id),
        "display_name": display_name,
        "slot": slot,
        "rarity": rarity,
        "modifiers": modifiers.duplicate(true),
        "special_effect": str(special_effect),
        "is_two_handed": is_two_handed,
        "value_gold": value_gold,
        "description": description,
        "weight": weight,
        "cells": [cells.x, cells.y],
        "combat": combat.duplicate(true),
        "armor": armor.duplicate(true),
        "ac_bonus_type": ac_bonus_type,
        "tier": tier,
    }

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
    p_ac_bonus_type: AcBonusType = AcBonusType.NONE,
    p_cells: Vector2i = Vector2i.ZERO
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
    cells = p_cells
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

# --- Габарит в сетке (grid-inventory-and-merchant) ---

static func is_valid_cells(c: Vector2i) -> bool:
    return c.x > 0 and c.y > 0

## Габарит по умолчанию для слота; ZERO — слота нет в таблице.
static func default_cells_for_slot(p_slot: Slot) -> Vector2i:
    return SLOT_CELLS.get(p_slot, Vector2i.ZERO)

## Действующий габарит: явный из данных, иначе — по слоту.
func resolved_cells() -> Vector2i:
    return cells if is_valid_cells(cells) else default_cells_for_slot(slot)

func cell_count() -> int:
    var c := resolved_cells()
    return c.x * c.y

## Причина, по которой габарит считать нечем; "" — данных достаточно.
## Явный, но бессмысленный габарит — ошибка, а не повод молча взять дефолт слота.
func cells_error() -> String:
    if cells != Vector2i.ZERO and not is_valid_cells(cells):
        return "габарит %s: стороны должны быть больше нуля" % str(cells)
    if is_valid_cells(default_cells_for_slot(slot)):
        return ""
    return "габарит не задан, слот %s не в таблице SLOT_CELLS" % str(slot)

## Габарит для игрока: «6 клеток» / «2 клетки» / «1 клетка».
func cells_text() -> String:
    var n := cell_count()
    if n % 10 == 1 and n % 100 != 11:
        return "%d клетка" % n
    if n % 10 in [2, 3, 4] and not (n % 100 in [12, 13, 14]):
        return "%d клетки" % n
    return "%d клеток" % n

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

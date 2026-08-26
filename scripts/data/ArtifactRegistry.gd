class_name ArtifactRegistry
extends RefCounted
## Static registry of all 30 artifacts.

static var _artifacts: Dictionary = {}
static var _by_rarity: Dictionary = {}


static func ensure_definitions() -> void:
    if not _artifacts.is_empty():
        return

    # ===== MINOR (10) =====
    _register(&"helm_sentinel", "Sentinel's Helm", Artifact.Slot.HEAD, Artifact.Rarity.MINOR,
        {"defense": 1}, &"", false, 500, "Light helm worn by watchmen.")

    _register(&"amulet_mourning", "Amulet of Mourning", Artifact.Slot.NECK, Artifact.Rarity.MINOR,
        {"morale": 1}, &"", false, 400, "A dark amulet that lifts spirits.")

    _register(&"leather_vest", "Leather Vest", Artifact.Slot.TORSO, Artifact.Rarity.MINOR,
        {"defense": 1}, &"", false, 300, "Sturdy leather armor.")

    _register(&"wooden_sword", "Wooden Sword", Artifact.Slot.WEAPON, Artifact.Rarity.MINOR,
        {"attack": 1}, &"", false, 200, "A training sword.")

    _register(&"buckler", "Small Buckler", Artifact.Slot.SHIELD, Artifact.Rarity.MINOR,
        {"defense": 1}, &"", false, 250, "A small shield.")

    _register(&"cloth_pants", "Cloth Pants", Artifact.Slot.LEGS, Artifact.Rarity.MINOR,
        {"defense": 1}, &"", false, 200, "Simple cloth pants.")

    _register(&"sandals", "Leather Sandals", Artifact.Slot.BOOTS, Artifact.Rarity.MINOR,
        {"morale": 1}, &"", false, 300, "Comfortable sandals.")

    _register(&"ring_vitality", "Ring of Vitality", Artifact.Slot.RING_L, Artifact.Rarity.MINOR,
        {"stack_hp": 10}, &"", false, 600, "+10 HP to all friendly stacks.")

    _register(&"ring_cunning", "Ring of Cunning", Artifact.Slot.RING_R, Artifact.Rarity.MINOR,
        {"luck": 1}, &"", false, 500, "Increases luck.")

    _register(&"lucky_clover", "Four-Leaf Clover", Artifact.Slot.MISC_A, Artifact.Rarity.MINOR,
        {"luck": 1}, &"", false, 400, "A lucky charm.")

    # ===== MAJOR (10) =====
    _register(&"crown_magi", "Crown of the Magi", Artifact.Slot.HEAD, Artifact.Rarity.MAJOR,
        {"spell_power": 2, "knowledge": 1}, &"", false, 3000, "Crown of an archmage.")

    _register(&"pendant_life", "Pendant of Life", Artifact.Slot.NECK, Artifact.Rarity.MAJOR,
        {"stack_hp_percent": 0.20}, &"", false, 4000, "+20% HP to all friendly stacks.")

    _register(&"breastplate_brimestone", "Breastplate of Brimstone", Artifact.Slot.TORSO, Artifact.Rarity.MAJOR,
        {"defense": 3}, &"", false, 3500, "Heat-resistant armor.")

    _register(&"sword_hellstorm", "Sword of Hellstorm", Artifact.Slot.WEAPON, Artifact.Rarity.MAJOR,
        {"attack": 3}, &"", true, 4000, "Two-handed flaming sword.")

    _register(&"shield_sentinel", "Sentinel's Shield", Artifact.Slot.SHIELD, Artifact.Rarity.MAJOR,
        {"defense": 3}, &"", false, 3500, "Heavy shield.")

    _register(&"greaves_snake", "Snake Greaves", Artifact.Slot.LEGS, Artifact.Rarity.MAJOR,
        {"defense": 2, "stack_speed": 1}, &"", false, 2800, "+1 speed to all friendly stacks.")

    _register(&"boots_polar", "Polar Boots", Artifact.Slot.BOOTS, Artifact.Rarity.MAJOR,
        {"movement": 3}, &"boots_levitation", false, 3000, "+3 MP/day, walk on water.")

    _register(&"ring_wayfarer", "Wayfarer's Ring", Artifact.Slot.RING_L, Artifact.Rarity.MAJOR,
        {"movement": 2}, &"", false, 2500, "+2 MP/day.")

    _register(&"ring_mage", "Mage's Ring", Artifact.Slot.RING_R, Artifact.Rarity.MAJOR,
        {"spell_power": 2}, &"", false, 3000, "Amplifies magical power.")

    _register(&"cloak_undead", "Cloak of the Undead King", Artifact.Slot.MISC_A, Artifact.Rarity.MAJOR,
        {"morale": 1}, &"undead_morale", false, 5000, "+1 morale to undead stacks.")

    # ===== RELIC (10) =====
    _register(&"helm_heavenly", "Helm of Heavenly Enlightenment", Artifact.Slot.HEAD, Artifact.Rarity.RELIC,
        {"attack": 6, "defense": 6}, &"", false, 20000, "Legendary helm of angels.")

    _register(&"pendant_negation", "Pendant of Negation", Artifact.Slot.NECK, Artifact.Rarity.RELIC,
        {}, &"magic_immunity_low", false, 15000, "Immunity to level 1-2 magic.")

    _register(&"armor_wonder", "Armor of Wonder", Artifact.Slot.TORSO, Artifact.Rarity.RELIC,
        {"defense": 6}, &"", false, 18000, "Unbreakable armor.")

    _register(&"sword_judgment", "Sword of Judgment", Artifact.Slot.WEAPON, Artifact.Rarity.RELIC,
        {"attack": 6}, &"", true, 18000, "Two-handed divine blade.")

    _register(&"shield_damned", "Shield of the Damned", Artifact.Slot.SHIELD, Artifact.Rarity.RELIC,
        {"defense": 6}, &"retaliation_weakness", false, 16000, "Heavy cursed shield.")

    _register(&"boots_levitation", "Boots of Levitation", Artifact.Slot.BOOTS, Artifact.Rarity.RELIC,
        {}, &"hero_flight", false, 12000, "Hero can fly over water and mountains.")

    _register(&"ring_arcanum", "Arcanum Ring", Artifact.Slot.RING_L, Artifact.Rarity.RELIC,
        {"spell_power": 3}, &"", false, 10000, "Arcane focus ring.")

    _register(&"ring_infinite_gems", "Ring of Infinite Gems", Artifact.Slot.RING_R, Artifact.Rarity.RELIC,
        {"daily_gems": 1}, &"", false, 10000, "+1 gem per day.")

    _register(&"spellbinders_hat", "Spellbinder's Hat", Artifact.Slot.MISC_A, Artifact.Rarity.RELIC,
        {}, &"level_5_spells", false, 25000, "Grants all level 5 spells.")

    _register(&"statue_legion", "Statue of Legion", Artifact.Slot.MISC_B, Artifact.Rarity.RELIC,
        {"castle_growth_percent": 50}, &"", false, 20000, "+50% creature growth in castles.")

    # Build rarity index
    _by_rarity.clear()
    for id in _artifacts:
        var art: Artifact = _artifacts[id]
        if not _by_rarity.has(art.rarity):
            _by_rarity[art.rarity] = []
        _by_rarity[art.rarity].append(art)


static func _register(
    id: StringName,
    display_name: String,
    slot: Artifact.Slot,
    rarity: Artifact.Rarity,
    modifiers: Dictionary,
    special_effect: StringName,
    two_handed: bool,
    gold: int,
    description: String
) -> void:
    var art := Artifact.new(
        id, display_name, slot, rarity,
        modifiers, special_effect, two_handed, gold, description
    )
    _artifacts[id] = art


static func get_by_id(id: StringName) -> Artifact:
    ensure_definitions()
    return _artifacts.get(id, null)


static func get_all() -> Array[Artifact]:
    ensure_definitions()
    var result: Array[Artifact] = []
    for id in _artifacts:
        result.append(_artifacts[id])
    return result


static func get_by_rarity(rarity: Artifact.Rarity) -> Array[Artifact]:
    ensure_definitions()
    var result: Array[Artifact] = []
    if _by_rarity.has(rarity):
        for art in _by_rarity[rarity]:
            result.append(art)
    return result


static func random_of_rarity(rarity: Artifact.Rarity, rng: RandomNumberGenerator) -> Artifact:
    var pool := get_by_rarity(rarity)
    if pool.is_empty():
        return null
    return pool[rng.randi_range(0, pool.size() - 1)]


static func random_any(rng: RandomNumberGenerator) -> Artifact:
    ensure_definitions()
    var all := get_all()
    if all.is_empty():
        return null
    return all[rng.randi_range(0, all.size() - 1)]

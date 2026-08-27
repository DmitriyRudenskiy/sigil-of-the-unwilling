extends Node
## Autoload: UnitRegistry. Registry of unit definitions — instance node, not static.
## Call reset() in tests to isolate data between runs.
## Call reset() in tests to isolate data between runs.

const _UnitStack = preload("res://scripts/unit_stack.gd")
const _UnitStats = preload("res://scripts/unit_stats.gd")

const UNITS_BASE := {
    # базовые (герой + старые враги)
    "swordsmen": ["Swordsman", 4, 10, 5, 2], "archers": ["Archer", 3, 8, 4, 1],
    "cavalry": ["Cavalry", 5, 15, 7, 2], "mages": ["Mage", 7, 12, 5, 2],
    "guardians": ["Guardian", 6, 25, 3, 3], "archmages": ["Archmage", 9, 14, 6, 2],
    "champions": ["Champion", 12, 30, 8, 3], "knights": ["Knight", 8, 20, 9, 3],
    "goblins": ["Goblin", 2, 8, 4, 1], "wolves": ["Wolf", 4, 10, 6, 1], "trolls": ["Troll", 8, 20, 3, 2],
    # набор 1
    "pikeman": ["Pikeman", 2, 10, 4, 1], "halberdier": ["Halberdier", 3, 13, 5, 2],
    "lancer": ["Lancer", 4, 18, 6, 2], "alchemist": ["Alchemist", 5, 20, 5, 2],
    "berserker": ["Berserker", 5, 22, 6, 2], "griffin": ["Griffin", 6, 25, 6, 3],
    "royal_griffin": ["Royal Griffin", 7, 30, 7, 4], "pegasus": ["Pegasus", 8, 30, 8, 4],
    "gargoyle": ["Gargoyle", 6, 22, 6, 3], "titan": ["Titan", 20, 150, 7, 6],
    "dwarf": ["Dwarf", 4, 20, 3, 2], "battle_dwarf": ["Battle Dwarf", 5, 25, 4, 3],
    # набор 2
    "centaur": ["Centaur", 3, 10, 6, 1], "elf": ["Elf", 4, 15, 6, 2],
    "grand_elf": ["Grand Elf", 5, 18, 7, 2], "druid": ["Druid", 4, 18, 5, 2],
    "great_druid": ["Great Druid", 5, 22, 6, 3], "unicorn": ["Unicorn", 10, 40, 7, 4],
    "war_unicorn": ["War Unicorn", 12, 45, 8, 5], "treant": ["Treant", 9, 55, 3, 4],
    "dryad": ["Dryad", 5, 20, 6, 3], "green_dragon": ["Green Dragon", 25, 180, 6, 8],
    "gold_dragon": ["Gold Dragon", 30, 250, 7, 9], "black_dragon": ["Black Dragon", 35, 300, 9, 10],
    # набор 3
    "skeleton": ["Skeleton", 3, 10, 4, 1], "zombie": ["Zombie", 2, 15, 3, 1],
    "ghost": ["Ghost", 5, 18, 7, 3], "wraith": ["Wraith", 6, 22, 8, 4],
    "vampire": ["Vampire", 8, 30, 8, 5], "lich": ["Lich", 12, 35, 6, 5],
    "orc": ["Orc", 4, 15, 4, 1], "ogre": ["Ogre", 6, 30, 4, 2],
    "behemoth": ["Behemoth", 12, 60, 5, 4], "harpy": ["Harpy", 5, 18, 6, 2],
    "minotaur": ["Minotaur", 8, 35, 5, 4], "hydra": ["Hydra", 14, 70, 4, 5],
    # набор 4
    "gremlin": ["Gremlin", 2, 8, 4, 1], "master_gremlin": ["Master Gremlin", 3, 10, 5, 1],
    "stone_golem": ["Stone Golem", 5, 30, 3, 3], "iron_golem": ["Iron Golem", 6, 35, 4, 4],
    "gold_golem": ["Gold Golem", 7, 40, 4, 5], "diamond_golem": ["Diamond Golem", 8, 45, 4, 6],
    "magus": ["Magus", 7, 20, 5, 3], "genie": ["Genie", 10, 35, 7, 5],
    "master_genie": ["Master Genie", 12, 40, 8, 6], "naga": ["Naga", 10, 45, 5, 5],
    "naga_queen": ["Naga Queen", 12, 50, 6, 6], "giant": ["Giant", 15, 100, 7, 6],
    # набор 5
    "gnoll": ["Gnoll", 2, 10, 4, 1], "gnoll_marauder": ["Gnoll Marauder", 3, 12, 5, 1],
    "lizardman": ["Lizardman", 3, 14, 4, 2], "lizard_warrior": ["Lizard Warrior", 4, 16, 5, 2],
    "serpent_fly": ["Serpent Fly", 4, 18, 6, 2], "dragon_fly": ["Dragon Fly", 5, 20, 7, 3],
    "basilisk": ["Basilisk", 6, 30, 5, 3], "greater_basilisk": ["Greater Basilisk", 7, 35, 6, 4],
    "wyvern": ["Wyvern", 8, 35, 6, 4], "wyvern_monarch": ["Wyvern Monarch", 9, 40, 7, 5],
    "gorgon": ["Gorgon", 10, 50, 4, 5], "mighty_gorgon": ["Mighty Gorgon", 12, 60, 5, 6],
    # набор 6
    "hobgoblin": ["Hobgoblin", 2, 8, 5, 1], "wolf_rider": ["Wolf Rider", 4, 12, 6, 2],
    "wolf_raider": ["Wolf Raider", 5, 14, 7, 2], "orc_chieftain": ["Orc Chieftain", 5, 18, 4, 2],
    "ogre_mage": ["Ogre Mage", 7, 30, 4, 3], "roc": ["Roc", 8, 35, 6, 4],
    "thunderbird": ["Thunderbird", 9, 40, 7, 5], "cyclops": ["Cyclops", 10, 50, 4, 4],
    "cyclops_king": ["Cyclops King", 12, 60, 5, 5], "air_elemental": ["Air Elemental", 6, 25, 7, 4],
    "fire_elemental": ["Fire Elemental", 8, 30, 6, 4], "water_elemental": ["Water Elemental", 7, 35, 5, 4],
    # набор 7
    "earth_elemental": ["Earth Elemental", 8, 40, 4, 5], "storm_elemental": ["Storm Elemental", 7, 30, 8, 4],
    "ice_elemental": ["Ice Elemental", 7, 35, 5, 4], "magma_elemental": ["Magma Elemental", 9, 40, 4, 5],
    "phoenix": ["Phoenix", 15, 90, 9, 6], "firebird": ["Firebird", 12, 80, 8, 5],
    "troglodyte": ["Troglodyte", 3, 12, 4, 1], "beholder": ["Beholder", 5, 18, 5, 3],
    "medusa": ["Medusa", 7, 25, 5, 4], "manticore": ["Manticore", 10, 45, 7, 5],
    "red_dragon": ["Red Dragon", 28, 220, 7, 9], "rust_dragon": ["Rust Dragon", 26, 200, 6, 8],
}

const FACTION_SETS := [
    ["pikeman","halberdier","lancer","alchemist","berserker","griffin","royal_griffin","pegasus","gargoyle","titan","dwarf","battle_dwarf"],
    ["centaur","elf","grand_elf","druid","great_druid","unicorn","war_unicorn","treant","dryad","green_dragon","gold_dragon","black_dragon"],
    ["skeleton","zombie","ghost","wraith","vampire","lich","orc","ogre","behemoth","harpy","minotaur","hydra"],
    ["gremlin","master_gremlin","stone_golem","iron_golem","gold_golem","diamond_golem","magus","genie","master_genie","naga","naga_queen","giant"],
    ["gnoll","gnoll_marauder","lizardman","lizard_warrior","serpent_fly","dragon_fly","basilisk","greater_basilisk","wyvern","wyvern_monarch","gorgon","mighty_gorgon"],
    ["hobgoblin","wolf_rider","wolf_raider","orc_chieftain","ogre_mage","roc","thunderbird","cyclops","cyclops_king","air_elemental","fire_elemental","water_elemental"],
    ["earth_elemental","storm_elemental","ice_elemental","magma_elemental","phoenix","firebird","troglodyte","beholder","medusa","manticore","red_dragon","rust_dragon"],
]

const UNIT_ATTACK := {
    # Пример переопределения:
    # "swordsmen": 8,
}

const UNIT_TAGS := {
    "swordsmen": ["melee"],
    "archers": ["ranged"],
    "cavalry": ["melee"],
    "mages": ["ranged"],
    "guardians": ["melee"],
    "archmages": ["ranged"],
    "champions": ["melee", "double_strike", "morale", "charge", "strong_strike"],
    "knights": ["melee"],
    "goblins": ["melee"],
    "wolves": ["melee"],
    "trolls": ["melee", "strong_strike"],

    "pikeman": ["melee"],
    "halberdier": ["melee"],
    "lancer": ["melee"],
    "alchemist": ["ranged", "alchemy"],
    "berserker": ["melee", "strong_strike"],
    "griffin": ["flying"],
    "royal_griffin": ["flying", "no_retaliation", "double_strike", "first_strike"],
    "pegasus": ["flying"],
    "gargoyle": ["flying"],
    "titan": ["ranged"],
    "dwarf": ["melee", "magic_resistant", "worker", "miner"],
    "battle_dwarf": ["melee", "magic_resistant", "worker", "miner"],

    "centaur": ["melee"],
    "elf": ["ranged", "precise_strike"],
    "grand_elf": ["ranged", "double_strike", "precise_strike"],
    "druid": ["ranged"],
    "great_druid": ["ranged"],
    "unicorn": ["melee"],
    "war_unicorn": ["melee"],
    "treant": ["melee", "mind_immune"],
    "dryad": ["melee"],
    "green_dragon": ["flying", "dragon"],
    "gold_dragon": ["flying", "dragon"],
    "black_dragon": ["flying", "dragon"],

    "skeleton": ["undead"],
    "zombie": ["undead"],
    "ghost": ["undead"],
    "wraith": ["undead"],
    "vampire": ["flying", "undead", "no_retaliation", "vampiric", "poison_immune"],
    "lich": ["ranged", "undead", "poison_immune"],
    "orc": ["melee"],
    "ogre": ["melee"],
    "behemoth": ["melee"],
    "harpy": ["flying"],
    "minotaur": ["melee"],
    "hydra": ["melee"],

    "gremlin": ["melee"],
    "master_gremlin": ["ranged"],
    "stone_golem": ["melee", "mind_immune"],
    "iron_golem": ["melee", "mind_immune"],
    "gold_golem": ["melee", "mind_immune"],
    "diamond_golem": ["melee", "mind_immune"],
    "magus": ["ranged"],
    "genie": ["flying"],
    "master_genie": ["flying"],
    "naga": ["melee"],
    "naga_queen": ["melee"],
    "giant": ["melee"],

    "gnoll": ["melee"],
    "gnoll_marauder": ["melee"],
    "lizardman": ["melee", "lizard"],
    "lizard_warrior": ["melee", "lizard"],
    "serpent_fly": ["flying"],
    "dragon_fly": ["flying"],
    "basilisk": ["melee"],
    "greater_basilisk": ["melee"],
    "wyvern": ["flying"],
    "wyvern_monarch": ["flying"],
    "gorgon": ["ranged"],
    "mighty_gorgon": ["ranged"],

    "hobgoblin": ["melee"],
    "wolf_rider": ["melee"],
    "wolf_raider": ["melee", "double_strike"],
    "orc_chieftain": ["melee"],
    "ogre_mage": ["melee"],
    "roc": ["flying"],
    "thunderbird": ["flying"],
    "cyclops": ["ranged"],
    "cyclops_king": ["ranged"],
    "air_elemental": ["flying", "elemental"],
    "fire_elemental": ["elemental"],
    "water_elemental": ["elemental"],

    "earth_elemental": ["elemental"],
    "storm_elemental": ["flying", "elemental"],
    "ice_elemental": ["flying", "elemental"],
    "magma_elemental": ["elemental"],
    "phoenix": ["flying", "rebirth"],
    "firebird": ["flying"],
    "troglodyte": ["melee"],
    "beholder": ["ranged", "no_retaliation"],
    "medusa": ["ranged", "no_retaliation"],
    "manticore": ["flying"],
    "red_dragon": ["flying", "dragon", "breath", "petrify", "blind"],
    "rust_dragon": ["flying", "dragon", "breath"],
}

var _definitions: Dictionary = {}


func ensure_definitions() -> void:
    if not _definitions.is_empty():
        return

    for key in UNITS_BASE:
        var raw: Array = UNITS_BASE[key]

        var display_name: String = str(raw[0])
        var base_damage: int = int(raw[1])
        var hp: int = int(raw[2])
        var speed: int = int(raw[3])
        var defense: int = int(raw[4])

        var attack: int = int(UNIT_ATTACK.get(
            key,
            int(round(float(base_damage + defense) / 2.0))
        ))

        var raw_tags: Array = UNIT_TAGS.get(key, ["melee"])
        var tags: Array[String] = []
        tags.assign(raw_tags)

        _definitions[key] = UnitStats.new(
            key,
            display_name,
            attack,
            base_damage,
            hp,
            speed,
            defense,
            tags
        )


func reset() -> void:
    ## Для тестов: сброс определений.
    _definitions.clear()


func get_all_keys() -> Array[String]:
    ensure_definitions()

    var keys: Array[String] = []
    for k in _definitions.keys():
        keys.append(str(k))

    keys.sort()
    return keys


func get_definition(key: String) -> UnitStats:
    ensure_definitions()
    return _definitions.get(key, null)


func make_stack(key: String, rng: RandomNumberGenerator) -> UnitStack:
    var stats: UnitStats = get_definition(key)
    if stats == null:
        return null
    var count := clampi(
        int(float(rng.randi_range(30, 80)) * 6.0 / float(stats.base_damage)),
        3,
        120
    )
    return UnitStack.new(stats, count)


func make_fixed_stack(key: String, count: int) -> UnitStack:
    var stats: UnitStats = get_definition(key)
    if stats == null:
        return null
    return UnitStack.new(stats, count)

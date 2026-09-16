extends Node
class_name ArtifactRegistry

var _artifacts: Dictionary = {}
var _by_rarity: Dictionary = {}

func _ready() -> void:
	ensure_definitions()

func reset() -> void:
	_artifacts.clear()
	_by_rarity.clear()

func ensure_definitions() -> void:
	if not _artifacts.is_empty():
		return

	_register(&"helm_sentinel", "Sentinel's Helm", Artifact.Slot.HEAD, Artifact.Rarity.MINOR,
		{"defense": 1}, &"", false, 500, "Light helm worn by watchmen.",
		{}, {"base_ac": 1, "max_dex_bonus": 100, "acp": 0, "asf": 0.0}, Artifact.AcBonusType.NONE, 1.5)

	_register(&"amulet_mourning", "Amulet of Mourning", Artifact.Slot.NECK, Artifact.Rarity.MINOR,
		{"morale": 1}, &"", false, 400, "A dark amulet that lifts spirits.",
		{}, {"base_ac": 1}, Artifact.AcBonusType.NATURAL, 0.5)

	_register(&"leather_vest", "Leather Vest", Artifact.Slot.TORSO, Artifact.Rarity.MINOR,
		{"defense": 1}, &"", false, 300, "Sturdy leather armor.",
		{}, {"base_ac": 4, "max_dex_bonus": 3, "acp": -2, "asf": 10.0}, Artifact.AcBonusType.NONE, 3.0)

	# social-stats-weapon-tech: изделия WeaponCatalog (вес из MATERIALS по тиру)
	_register(&"club", "Дубина", Artifact.Slot.WEAPON, Artifact.Rarity.MINOR,
		{"attack": 1}, &"", false, 5, "Простая палка. Верная, как смерть.",
		{"damage_dice": "1d4", "damage_types": [Artifact.DamageType.BLUDGEONING], "crit_threat": 20, "crit_multiplier": 2.0, "proficiency": [Artifact.WeaponCategory.SIMPLE], "weapon_size": Artifact.WeaponSize.MEDIUM}, {}, Artifact.AcBonusType.NONE, 1.0)

	_register(&"stone_axe", "Каменный топор", Artifact.Slot.WEAPON, Artifact.Rarity.MINOR,
		{"attack": 1}, &"", true, 8, "Окаменевшее терпение.",
		{"damage_dice": "1d6", "damage_types": [Artifact.DamageType.SLASHING], "crit_threat": 20, "crit_multiplier": 2.0, "proficiency": [Artifact.WeaponCategory.SIMPLE], "weapon_size": Artifact.WeaponSize.LARGE}, {}, Artifact.AcBonusType.NONE, 1.0)

	_register(&"iron_sword", "Железный меч", Artifact.Slot.WEAPON, Artifact.Rarity.MINOR,
		{"attack": 2}, &"", false, 20, "Первый настоящий клинок.",
		{"damage_dice": "1d8", "damage_types": [Artifact.DamageType.PIERCING], "crit_threat": 20, "crit_multiplier": 2.0, "proficiency": [Artifact.WeaponCategory.MARTIAL], "weapon_size": Artifact.WeaponSize.MEDIUM}, {}, Artifact.AcBonusType.NONE, 2.0)

	_register(&"steel_longsword", "Стальной длинный меч", Artifact.Slot.WEAPON, Artifact.Rarity.MAJOR,
		{"attack": 3}, &"", true, 45, "Тяжёлая сталь тяжёлых решений.",
		{"damage_dice": "2d6", "damage_types": [Artifact.DamageType.SLASHING], "crit_threat": 19, "crit_multiplier": 2.0, "proficiency": [Artifact.WeaponCategory.MARTIAL], "weapon_size": Artifact.WeaponSize.LARGE}, {}, Artifact.AcBonusType.NONE, 1.8)

	_register(&"runic_blade", "Рунный клинок", Artifact.Slot.WEAPON, Artifact.Rarity.MAJOR,
		{"attack": 3, "spell_power": 1}, &"", false, 90, "Руны шепчут о будущем враге.",
		{"damage_dice": "2d8", "damage_types": [Artifact.DamageType.PIERCING], "crit_threat": 19, "crit_multiplier": 2.0, "proficiency": [Artifact.WeaponCategory.MARTIAL], "weapon_size": Artifact.WeaponSize.MEDIUM}, {}, Artifact.AcBonusType.NONE, 2.5)

	_register(&"rune_sword", "Рун. меч", Artifact.Slot.WEAPON, Artifact.Rarity.RELIC,
		{"attack": 4, "spell_power": 2}, &"", false, 160, "Легенда, которую можно воткнуть в кого-нибудь.",
		{"damage_dice": "3d8", "damage_types": [Artifact.DamageType.PIERCING], "crit_threat": 18, "crit_multiplier": 2.0, "proficiency": [Artifact.WeaponCategory.MARTIAL], "weapon_size": Artifact.WeaponSize.MEDIUM}, {}, Artifact.AcBonusType.NONE, 2.5)

	_register(&"wooden_sword", "Wooden Sword", Artifact.Slot.WEAPON, Artifact.Rarity.MINOR,
		{"attack": 1}, &"", false, 200, "A training sword.",
		{"damage_dice": "1d6", "damage_types": [Artifact.DamageType.BLUDGEONING], "crit_threat": 20, "crit_multiplier": 2.0, "proficiency": [Artifact.WeaponCategory.SIMPLE], "weapon_size": Artifact.WeaponSize.MEDIUM}, {}, Artifact.AcBonusType.NONE, 2.0)

	_register(&"buckler", "Small Buckler", Artifact.Slot.SHIELD, Artifact.Rarity.MINOR,
		{"defense": 1}, &"", false, 250, "A small shield.",
		{}, {"base_ac": 1}, Artifact.AcBonusType.SHIELD, 1.0)

	_register(&"cloth_pants", "Cloth Pants", Artifact.Slot.LEGS, Artifact.Rarity.MINOR,
		{"defense": 1}, &"", false, 200, "Simple cloth pants.", {}, {}, Artifact.AcBonusType.NONE, 1.0)

	_register(&"sandals", "Leather Sandals", Artifact.Slot.BOOTS, Artifact.Rarity.MINOR,
		{"morale": 1}, &"", false, 300, "Comfortable sandals.", {}, {}, Artifact.AcBonusType.NONE, 1.0)

	_register(&"ring_vitality", "Ring of Vitality", Artifact.Slot.RING_L, Artifact.Rarity.MINOR,
		{"stack_hp": 10}, &"", false, 600, "+10 HP to all friendly stacks.", {}, {}, Artifact.AcBonusType.NONE, 0.5)

	_register(&"ring_cunning", "Ring of Cunning", Artifact.Slot.RING_R, Artifact.Rarity.MINOR,
		{"luck": 1}, &"", false, 500, "Increases luck.", {}, {}, Artifact.AcBonusType.NONE, 0.5)

	_register(&"lucky_clover", "Four-Leaf Clover", Artifact.Slot.MISC_A, Artifact.Rarity.MINOR,
		{"luck": 1}, &"", false, 400, "A lucky charm.", {}, {}, Artifact.AcBonusType.NONE, 0.5)

	_register(&"crown_magi", "Crown of the Magi", Artifact.Slot.HEAD, Artifact.Rarity.MAJOR,
		{"spell_power": 2, "knowledge": 1}, &"", false, 3000, "Crown of an archmage.",
		{}, {"base_ac": 1, "max_dex_bonus": 100}, Artifact.AcBonusType.NONE, 2.0)

	_register(&"pendant_life", "Pendant of Life", Artifact.Slot.NECK, Artifact.Rarity.MAJOR,
		{"stack_hp_percent": 0.20}, &"", false, 4000, "+20% HP to all friendly stacks.", {}, {}, Artifact.AcBonusType.NONE, 1.0)

	_register(&"breastplate_brimestone", "Breastplate of Brimstone", Artifact.Slot.TORSO, Artifact.Rarity.MAJOR,
		{"defense": 3}, &"", false, 3500, "Heat-resistant armor.",
		{}, {"base_ac": 7, "max_dex_bonus": 0, "acp": -5, "asf": 20.0}, Artifact.AcBonusType.NONE, 8.0)

	_register(&"sword_hellstorm", "Sword of Hellstorm", Artifact.Slot.WEAPON, Artifact.Rarity.MAJOR,
		{"attack": 3}, &"", true, 4000, "Two-handed flaming sword.", {}, {}, Artifact.AcBonusType.NONE, 4.0)

	_register(&"shield_sentinel", "Sentinel's Shield", Artifact.Slot.SHIELD, Artifact.Rarity.MAJOR,
		{"defense": 3}, &"", false, 3500, "Heavy shield.",
		{}, {"base_ac": 3}, Artifact.AcBonusType.SHIELD, 3.0)

	_register(&"greaves_snake", "Snake Greaves", Artifact.Slot.LEGS, Artifact.Rarity.MAJOR,
		{"defense": 2, "stack_speed": 1}, &"", false, 2800, "+1 speed to all friendly stacks.",
		{}, {"base_ac": 2, "max_dex_bonus": 100}, Artifact.AcBonusType.NONE, 4.0)

	_register(&"boots_polar", "Polar Boots", Artifact.Slot.BOOTS, Artifact.Rarity.MAJOR,
		{"movement": 3}, &"boots_levitation", false, 3000, "+3 MP/day, walk on water.",
		{}, {"base_ac": 1, "max_dex_bonus": 100}, Artifact.AcBonusType.NONE, 2.0)

	_register(&"ring_wayfarer", "Wayfarer's Ring", Artifact.Slot.RING_L, Artifact.Rarity.MAJOR,
		{"movement": 2}, &"", false, 2500, "+2 MP/day.", {}, {}, Artifact.AcBonusType.NONE, 0.5)

	_register(&"ring_mage", "Mage's Ring", Artifact.Slot.RING_R, Artifact.Rarity.MAJOR,
		{"spell_power": 2}, &"", false, 3000, "Amplifies magical power.", {}, {}, Artifact.AcBonusType.NONE, 0.5)

	_register(&"cloak_undead", "Cloak of the Undead King", Artifact.Slot.MISC_A, Artifact.Rarity.MAJOR,
		{"morale": 1}, &"undead_morale", false, 5000, "+1 morale to undead stacks.", {}, {}, Artifact.AcBonusType.NONE, 2.0)

	_register(&"helm_heavenly", "Helm of Heavenly Enlightenment", Artifact.Slot.HEAD, Artifact.Rarity.RELIC,
		{"attack": 6, "defense": 6}, &"", false, 20000, "Legendary helm of angels.",
		{}, {"base_ac": 2, "max_dex_bonus": 100}, Artifact.AcBonusType.NONE, 2.0)

	_register(&"pendant_negation", "Pendant of Negation", Artifact.Slot.NECK, Artifact.Rarity.RELIC,
		{}, &"magic_immunity_low", false, 15000, "Immunity to level 1-2 magic.", {}, {}, Artifact.AcBonusType.NONE, 1.0)

	_register(&"armor_wonder", "Armor of Wonder", Artifact.Slot.TORSO, Artifact.Rarity.RELIC,
		{"defense": 6}, &"", false, 18000, "Unbreakable armor.",
		{}, {"base_ac": 8, "max_dex_bonus": 1, "acp": -4, "asf": 10.0}, Artifact.AcBonusType.NONE, 10.0)

	_register(&"sword_judgment", "Sword of Judgment", Artifact.Slot.WEAPON, Artifact.Rarity.RELIC,
		{"attack": 6}, &"", true, 18000, "Two-handed divine blade.", {}, {}, Artifact.AcBonusType.NONE, 5.0)

	_register(&"shield_damned", "Shield of the Damned", Artifact.Slot.SHIELD, Artifact.Rarity.RELIC,
		{"defense": 6}, &"retaliation_weakness", false, 16000, "Heavy cursed shield.",
		{}, {"base_ac": 4}, Artifact.AcBonusType.SHIELD, 5.0)

	_register(&"boots_levitation", "Boots of Levitation", Artifact.Slot.BOOTS, Artifact.Rarity.RELIC,
		{}, &"hero_flight", false, 12000, "Hero can fly over water and mountains.", {}, {}, Artifact.AcBonusType.NONE, 1.0)

	_register(&"ring_arcanum", "Arcanum Ring", Artifact.Slot.RING_L, Artifact.Rarity.RELIC,
		{"spell_power": 3}, &"", false, 10000, "Arcane focus ring.",
		{}, {"base_ac": 1}, Artifact.AcBonusType.DEFLECTION, 0.5)

	_register(&"ring_infinite_gems", "Ring of Infinite Gems", Artifact.Slot.RING_R, Artifact.Rarity.RELIC,
		{"daily_gems": 1}, &"", false, 10000, "+1 gem per day.", {}, {}, Artifact.AcBonusType.NONE, 0.5)

	_register(&"spellbinders_hat", "Spellbinder's Hat", Artifact.Slot.MISC_A, Artifact.Rarity.RELIC,
		{}, &"level_5_spells", false, 25000, "Grants all level 5 spells.", {}, {}, Artifact.AcBonusType.NONE, 2.0)

	_register(&"statue_legion", "Statue of Legion", Artifact.Slot.MISC_B, Artifact.Rarity.RELIC,
		{"castle_growth_percent": 50}, &"", false, 20000, "+50% creature growth in castles.", {}, {}, Artifact.AcBonusType.NONE, 10.0)

	_register(&"greatsword_might", "Warlord's Greatsword", Artifact.Slot.WEAPON, Artifact.Rarity.RELIC,
		{"attack": 8}, &"", true, 22000, "Two-handed greatsword of a warlord.",
		{"damage_dice": "2d6", "damage_types": [Artifact.DamageType.SLASHING], "crit_threat": 19, "crit_multiplier": 2.0, "proficiency": [Artifact.WeaponCategory.MARTIAL], "weapon_size": Artifact.WeaponSize.LARGE, "is_two_handed": true}, {}, Artifact.AcBonusType.NONE, 6.0)

	_register(&"helm_bulwark", "Bulwark Helm", Artifact.Slot.HEAD, Artifact.Rarity.RELIC,
		{"defense": 6}, &"", false, 20000, "Heavy helm that refuses to fall.",
		{}, {"base_ac": 2, "max_dex_bonus": 100}, Artifact.AcBonusType.NONE, 2.0)

	_register(&"plate_dread", "Dread Plate", Artifact.Slot.TORSO, Artifact.Rarity.RELIC,
		{"defense": 8}, &"", false, 21000, "Plating forged in dread.",
		{}, {"base_ac": 8, "max_dex_bonus": 0, "acp": -5, "asf": 20.0}, Artifact.AcBonusType.NONE, 12.0)

	_register(&"greaves_juggernaut", "Juggernaut Greaves", Artifact.Slot.LEGS, Artifact.Rarity.RELIC,
		{"defense": 5, "stack_hp": 20}, &"", false, 19000, "Massive greaves; +20 HP to stacks.",
		{}, {"base_ac": 3, "max_dex_bonus": 100}, Artifact.AcBonusType.NONE, 6.0)

	_register(&"boots_titan", "Titan's Boots", Artifact.Slot.BOOTS, Artifact.Rarity.RELIC,
		{"defense": 3, "movement": 4}, &"", false, 18000, "Strides of a titan.",
		{}, {"base_ac": 2, "max_dex_bonus": 100}, Artifact.AcBonusType.NONE, 3.0)

	_register(&"shield_greatwall", "Greatwall Shield", Artifact.Slot.SHIELD, Artifact.Rarity.RELIC,
		{"defense": 7}, &"", false, 20000, "A shield like a fortress wall.",
		{}, {"base_ac": 4}, Artifact.AcBonusType.SHIELD, 6.0)

	_register(&"longbow_hawk", "Hawksey Longbow", Artifact.Slot.WEAPON, Artifact.Rarity.RELIC,
		{"attack": 5}, &"", false, 16000, "A longbow with hawk-eyed precision.",
		{"damage_dice": "1d8", "damage_types": [Artifact.DamageType.PIERCING], "crit_threat": 20, "crit_multiplier": 3.0, "proficiency": [Artifact.WeaponCategory.MARTIAL], "weapon_size": Artifact.WeaponSize.LARGE, "is_ranged": true}, {}, Artifact.AcBonusType.NONE, 3.0)

	_register(&"hood_wraith", "Wraith Hood", Artifact.Slot.HEAD, Artifact.Rarity.RELIC,
		{"defense": 3, "luck": 1}, &"", false, 15000, "A hood that shrouds the wearer.",
		{}, {"base_ac": 1, "max_dex_bonus": 100}, Artifact.AcBonusType.NONE, 1.5)

	_register(&"leather_stalker", "Stalker's Leather", Artifact.Slot.TORSO, Artifact.Rarity.RELIC,
		{"defense": 4, "movement": 2}, &"", false, 15500, "Light leather for the stalker.",
		{}, {"base_ac": 5, "max_dex_bonus": 5, "acp": -2, "asf": 10.0}, Artifact.AcBonusType.NONE, 4.0)

	_register(&"wraps_peregrine", "Peregrine Wraps", Artifact.Slot.LEGS, Artifact.Rarity.RELIC,
		{"defense": 2, "stack_speed": 2}, &"", false, 14000, "Wraps of the peregrine; +2 speed to stacks.", {}, {}, Artifact.AcBonusType.NONE, 2.0)

	_register(&"boots_zephyr", "Zephyr Boots", Artifact.Slot.BOOTS, Artifact.Rarity.RELIC,
		{"movement": 5, "stack_speed": 1}, &"", false, 14500, "Boots swift as the zephyr.",
		{}, {"base_ac": 1}, Artifact.AcBonusType.DODGE, 1.5)

	_register(&"buckler_ripple", "Ripple Buckler", Artifact.Slot.SHIELD, Artifact.Rarity.RELIC,
		{"defense": 4, "luck": 1}, &"", false, 14000, "A small shield that ripples with luck.",
		{}, {"base_ac": 2}, Artifact.AcBonusType.SHIELD, 1.5)

	_register(&"staff_void", "Staff of the Void", Artifact.Slot.WEAPON, Artifact.Rarity.RELIC,
		{"spell_power": 8, "attack": 1}, &"", false, 18000, "A staff hollowed by the void.",
		{"damage_dice": "1d6", "damage_types": [Artifact.DamageType.BLUDGEONING], "crit_threat": 20, "crit_multiplier": 2.0, "proficiency": [Artifact.WeaponCategory.SIMPLE], "weapon_size": Artifact.WeaponSize.LARGE}, {}, Artifact.AcBonusType.NONE, 3.0)

	_register(&"circlet_aurora", "Circlet of Aurora", Artifact.Slot.HEAD, Artifact.Rarity.RELIC,
		{"spell_power": 5, "knowledge": 2}, &"", false, 17000, "A circlet that glows with the aurora.",
		{}, {"base_ac": 1, "max_dex_bonus": 100}, Artifact.AcBonusType.NONE, 1.5)

	_register(&"robes_astronomer", "Astronomer's Robes", Artifact.Slot.TORSO, Artifact.Rarity.RELIC,
		{"spell_power": 4, "knowledge": 3}, &"", false, 17500, "Robes charting the moving stars.",
		{}, {"base_ac": 2, "max_dex_bonus": 100}, Artifact.AcBonusType.NONE, 3.0)

	_register(&"skirt_conjunction", "Skirt of Conjunction", Artifact.Slot.LEGS, Artifact.Rarity.RELIC,
		{"defense": 2, "spell_power": 3}, &"", false, 13000, "The folds align hostile conjuctions.",
		{}, {"base_ac": 1, "max_dex_bonus": 100}, Artifact.AcBonusType.NONE, 2.0)

	_register(&"soles_mercury", "Mercury Soles", Artifact.Slot.BOOTS, Artifact.Rarity.RELIC,
		{"movement": 3, "stack_speed": 2}, &"", false, 13500, "Soles that flow like mercury.",
		{}, {"base_ac": 1}, Artifact.AcBonusType.DODGE, 1.5)

	_register(&"ward_arcane", "Arcane Ward", Artifact.Slot.SHIELD, Artifact.Rarity.RELIC,
		{"defense": 3, "spell_power": 2}, &"magic_ward", false, 13000, "A ward woven from arcane force.",
		{}, {"base_ac": 3}, Artifact.AcBonusType.SHIELD, 3.0)

	_register(&"amulet_prescience", "Amulet of Prescience", Artifact.Slot.NECK, Artifact.Rarity.RELIC,
		{"knowledge": 4, "spell_power": 3}, &"", false, 16000, "Grants foresight and spellcraft.",
		{}, {"base_ac": 2}, Artifact.AcBonusType.NATURAL, 1.0)

	_register(&"charm_beast", "Beast Heart Charm", Artifact.Slot.MISC_A, Artifact.Rarity.RELIC,
		{"attack": 3, "morale": 2}, &"", false, 12000, "A charm carved from a beast's heart.", {}, {}, Artifact.AcBonusType.NONE, 1.0)

	_register(&"trinket_epoch", "Trinket of Epoch", Artifact.Slot.MISC_B, Artifact.Rarity.RELIC,
		{"daily_gems": 3, "movement": 2}, &"", false, 15000, "A trinket that ticks with days.", {}, {}, Artifact.AcBonusType.NONE, 1.0)

	_register(&"ring_giant", "Ring of the Giant", Artifact.Slot.RING_L, Artifact.Rarity.RELIC,
		{"stack_hp": 50, "attack": 2}, &"", false, 14000, "+50 HP to stacks; +2 attack.",
		{}, {"base_ac": 1}, Artifact.AcBonusType.DEFLECTION, 0.5)

	_register(&"ring_lexicon", "Ring of the Lexicon", Artifact.Slot.RING_R, Artifact.Rarity.RELIC,
		{"spell_power": 5, "knowledge": 2}, &"", false, 14500, "A ring holding a living lexicon.",
		{}, {"base_ac": 1}, Artifact.AcBonusType.DEFLECTION, 0.5)

	_register(&"tome_infinity", "Tome of Infinity", Artifact.Slot.SPELLBOOK, Artifact.Rarity.RELIC,
		{"spell_power": 8, "daily_gems": 1}, &"", false, 16000, "A tome of endless spells; +1 gem/day.", {}, {}, Artifact.AcBonusType.NONE, 3.0)

	_by_rarity.clear()
	for id in _artifacts:
		var art: Artifact = _artifacts[id]
		if not _by_rarity.has(art.rarity):
			_by_rarity[art.rarity] = []
		_by_rarity[art.rarity].append(art)

func _register(
	id: StringName,
	display_name: String,
	slot: Artifact.Slot,
	rarity: Artifact.Rarity,
	modifiers: Dictionary,
	special_effect: StringName,
	two_handed: bool,
	gold: int,
	description: String,
	combat: Dictionary = {},
	armor: Dictionary = {},
	ac_type: Artifact.AcBonusType = Artifact.AcBonusType.NONE,
	p_weight: float = 0.0
) -> void:
	var art := Artifact.from_dict({
		"id": id, "display_name": display_name, "slot": slot, "rarity": rarity,
		"modifiers": modifiers, "special_effect": special_effect,
		"is_two_handed": two_handed, "value_gold": gold, "description": description,
		"weight": p_weight, "combat": combat, "armor": armor, "ac_bonus_type": ac_type,
	})
	_artifacts[id] = art

func get_by_id(id: StringName) -> Artifact:
	ensure_definitions()
	return _artifacts.get(id, null)

func get_all() -> Array[Artifact]:
	ensure_definitions()
	var result: Array[Artifact] = []
	for id in _artifacts:
		result.append(_artifacts[id])
	return result

func get_by_rarity(rarity: Artifact.Rarity) -> Array[Artifact]:
	ensure_definitions()
	var result: Array[Artifact] = []
	if _by_rarity.has(rarity):
		for art in _by_rarity[rarity]:
			result.append(art)
	return result

func random_of_rarity(rarity: Artifact.Rarity, rng: RandomNumberGenerator) -> Artifact:
	var pool := get_by_rarity(rarity)
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]

func random_any(rng: RandomNumberGenerator) -> Artifact:
	ensure_definitions()
	var all := get_all()
	if all.is_empty():
		return null
	return all[rng.randi_range(0, all.size() - 1)]

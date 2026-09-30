class_name DNDArmorClass

## D&D 5e Armor Class Calculation
# Supports all armor types, shields, and DEX modifiers

enum ArmorType {
	NONE,           # No armor
	PADDED,         # Light armor
	LEATHER,        # Light armor
	STUDDED_LEATHER,# Light armor
	HIDE,           # Medium armor
	CHAIN_SHIRT,    # Medium armor
	SCALE_MAIL,     # Medium armor
	BREASTPLATE,    # Medium armor
	HALF_PLATE,     # Medium armor
	RING_MAIL,      # Heavy armor
	CHAIN_MAIL,     # Heavy armor
	SPLINT,         # Heavy armor
	PLATE           # Heavy armor
}

# Armor data: base AC, max DEX bonus, stealth disadvantage, strength requirement
const ARMOR_DATA = {
	ArmorType.NONE: { "ac": 10, "max_dex": 99, "stealth_disadv": false, "str_req": 0 },
	ArmorType.PADDED: { "ac": 11, "max_dex": 99, "stealth_disadv": true, "str_req": 0 },
	ArmorType.LEATHER: { "ac": 11, "max_dex": 99, "stealth_disadv": false, "str_req": 0 },
	ArmorType.STUDDED_LEATHER: { "ac": 12, "max_dex": 99, "stealth_disadv": false, "str_req": 0 },
	ArmorType.HIDE: { "ac": 12, "max_dex": 2, "stealth_disadv": false, "str_req": 0 },
	ArmorType.CHAIN_SHIRT: { "ac": 13, "max_dex": 2, "stealth_disadv": false, "str_req": 0 },
	ArmorType.SCALE_MAIL: { "ac": 14, "max_dex": 2, "stealth_disadv": true, "str_req": 0 },
	ArmorType.BREASTPLATE: { "ac": 14, "max_dex": 2, "stealth_disadv": false, "str_req": 0 },
	ArmorType.HALF_PLATE: { "ac": 15, "max_dex": 2, "stealth_disadv": true, "str_req": 0 },
	ArmorType.RING_MAIL: { "ac": 14, "max_dex": 0, "stealth_disadv": true, "str_req": 0 },
	ArmorType.CHAIN_MAIL: { "ac": 16, "max_dex": 0, "stealth_disadv": true, "str_req": 13 },
	ArmorType.SPLINT: { "ac": 17, "max_dex": 0, "stealth_disadv": true, "str_req": 15 },
	ArmorType.PLATE: { "ac": 18, "max_dex": 0, "stealth_disadv": true, "str_req": 15 }
}

const SHIELD_BONUS = 2

# Current equipment
var armor_type: ArmorType = ArmorType.NONE
var has_shield: bool = false
var shield_proficient: bool = true

# Dexterity modifier (passed from ability scores)
var dex_modifier: int = 0

# Natural armor (for creatures with natural AC calculation)
var natural_armor_base: int = 10
var use_natural_armor: bool = false

# Magical bonuses
var armor_bonus: int = 0  # +1, +2, +3 magic armor
var shield_bonus: int = 0  # +1, +2, +3 magic shield


func _init(p_armor_type: ArmorType = ArmorType.NONE, p_dex_mod: int = 0):
	armor_type = p_armor_type
	dex_modifier = p_dex_mod


## Calculate total Armor Class
func calculate_ac() -> int:
	var ac: int = 0
	
	if use_natural_armor:
		# Natural armor: base + CON mod (typically)
		ac = natural_armor_base + dex_modifier
	else:
		# Get armor base AC
		if armor_type in ARMOR_DATA:
			var armor_info = ARMOR_DATA[armor_type]
			ac = armor_info["ac"]
			
			# Add DEX modifier (limited by armor type)
			var max_dex = armor_info["max_dex"]
			if max_dex == 0:
				# Heavy armor: DEX ignored entirely (no negative penalty)
				pass
			elif max_dex < 99:
				ac += min(dex_modifier, max_dex)
			else:
				ac += dex_modifier
		else:
			# No armor: 10 + DEX
			ac = 10 + dex_modifier
	
	# Add magical bonuses
	ac += armor_bonus
	
	# Add shield bonus if proficient
	if has_shield and shield_proficient:
		ac += SHIELD_BONUS + shield_bonus
	
	return ac


## Check if character meets strength requirement for current armor
func meets_strength_requirement(str_score: int) -> bool:
	if armor_type in ARMOR_DATA:
		var str_req = ARMOR_DATA[armor_type]["str_req"]
		return str_score >= str_req
	return true


## Check if armor imposes stealth disadvantage
func has_stealth_disadvantage() -> bool:
	if armor_type in ARMOR_DATA:
		return ARMOR_DATA[armor_type]["stealth_disadv"]
	return false


## Set armor type
func set_armor(type: ArmorType):
	armor_type = type


## Equip or unequip shield
func set_shield(equipped: bool):
	has_shield = equipped


## Set magical bonus for armor
func set_armor_bonus(bonus: int):
	armor_bonus = clamp(bonus, 0, 3)


## Set magical bonus for shield
func set_shield_bonus(bonus: int):
	shield_bonus = clamp(bonus, 0, 3)


## Get AC breakdown as string (for tooltips)
func get_ac_breakdown() -> String:
	var breakdown: Array[String] = []
	
	if use_natural_armor:
		breakdown.append("Natural: %d" % natural_armor_base)
	elif armor_type in ARMOR_DATA:
		var armor_info = ARMOR_DATA[armor_type]
		breakdown.append("Armor: %d" % armor_info["ac"])
		
		var max_dex = armor_info["max_dex"]
		if max_dex < 99:
			breakdown.append("DEX: +%d (max %d)" % [min(dex_modifier, max_dex), max_dex])
		else:
			breakdown.append("DEX: +%d" % dex_modifier)
	else:
		breakdown.append("Unarmored: 10")
		breakdown.append("DEX: +%d" % dex_modifier)
	
	if armor_bonus > 0:
		breakdown.append("Magic Armor: +%d" % armor_bonus)
	
	if has_shield and shield_proficient:
		var total_shield = SHIELD_BONUS + shield_bonus
		breakdown.append("Shield: +%d" % total_shield)
	
	var total = calculate_ac()
	breakdown.append("Total: %d" % total)
	
	return ", ".join(breakdown)


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"armor_type": armor_type,
		"has_shield": has_shield,
		"shield_proficient": shield_proficient,
		"dex_modifier": dex_modifier,
		"use_natural_armor": use_natural_armor,
		"natural_armor_base": natural_armor_base,
		"armor_bonus": armor_bonus,
		"shield_bonus": shield_bonus
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary) -> DNDArmorClass:
	var ac_calc = DNDArmorClass.new()
	ac_calc.armor_type = data.get("armor_type", ArmorType.NONE)
	ac_calc.has_shield = data.get("has_shield", false)
	ac_calc.shield_proficient = data.get("shield_proficient", true)
	ac_calc.dex_modifier = data.get("dex_modifier", 0)
	ac_calc.use_natural_armor = data.get("use_natural_armor", false)
	ac_calc.natural_armor_base = data.get("natural_armor_base", 10)
	ac_calc.armor_bonus = data.get("armor_bonus", 0)
	ac_calc.shield_bonus = data.get("shield_bonus", 0)
	return ac_calc

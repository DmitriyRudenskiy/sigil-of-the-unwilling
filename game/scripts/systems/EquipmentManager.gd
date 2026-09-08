class_name EquipmentManager
extends RefCounted

const ARMOR_SLOTS := [
	Artifact.Slot.HEAD, Artifact.Slot.TORSO, Artifact.Slot.LEGS, Artifact.Slot.BOOTS,
]

const NON_PROFICIENCY_PENALTY := -4


func _init() -> void:
	pass


func compute_ac(equipped: Dictionary, dex_mod: int = 0) -> Dictionary:
	var base := 10.0

	var armor_ac := 0
	var dex_cap := 100
	var armored := false
	for slot in ARMOR_SLOTS:
		var a: Artifact = equipped.get(slot, null)
		if a != null and a.has_armor():
			armored = true
			armor_ac += a.get_base_ac()
			dex_cap = min(dex_cap, a.get_max_dex_bonus())
	var effective_dex: int = min(dex_mod, dex_cap)

	var shield_ac := 0
	var shield_item: Artifact = equipped.get(Artifact.Slot.SHIELD, null)
	if shield_item != null and shield_item.get_ac_bonus_type() == Artifact.AcBonusType.SHIELD:
		shield_ac = shield_item.get_base_ac()

	var natural_ac := _highest_type(equipped, Artifact.Slot.NECK, Artifact.AcBonusType.NATURAL)

	var deflection_ac := _highest_type(equipped, Artifact.Slot.RING_R, Artifact.AcBonusType.DEFLECTION,
		Artifact.Slot.RING_L, Artifact.AcBonusType.DEFLECTION)

	var dodge_ac := _sum_type(equipped, Artifact.AcBonusType.DODGE)

	var total: int = int(base) + effective_dex + armor_ac + shield_ac + natural_ac + deflection_ac + dodge_ac

	return {
		"total": total,
		"base": int(base),
		"dex_mod": int(dex_mod),
		"dex_cap": dex_cap,
		"effective_dex": int(effective_dex),
		"armor": int(armor_ac),
		"shield": int(shield_ac),
		"natural": int(natural_ac),
		"deflection": int(deflection_ac),
		"dodge": int(dodge_ac),
		"armored": armored,
	}


func _highest_type(equipped: Dictionary, a_slot: Artifact.Slot, a_type: Artifact.AcBonusType,
		b_slot: Artifact.Slot = -1, b_type: Artifact.AcBonusType = -1) -> int:
	var best := 0
	for slot in [a_slot]:
		var a: Artifact = equipped.get(slot, null)
		if a != null and a.get_ac_bonus_type() == a_type:
			best = max(best, a.get_base_ac())
	if b_slot >= 0:
		var b: Artifact = equipped.get(b_slot, null)
		if b != null and b.get_ac_bonus_type() == b_type:
			best = max(best, b.get_base_ac())
	return best


func _sum_type(equipped: Dictionary, target_type: Artifact.AcBonusType) -> int:
	var total := 0
	for slot in equipped:
		var a: Artifact = equipped.get(slot, null)
		if a != null and a.get_ac_bonus_type() == target_type:
			total += a.get_base_ac()
	return total


func evaluate_attack(equipped: Dictionary, proficiencies: Array,
		str_mod: int = 0, dex_mod: int = 0) -> Dictionary:
	var w: Artifact = equipped.get(Artifact.Slot.WEAPON, null)
	if w == null:
		return {"weapon": null, "damage_dice": "", "damage_types": [], "attack": 0,
			"crit_threat": 20, "crit_multiplier": 2.0, "proficient": true,
			"is_ranged": false, "is_two_handed": false}

	var damage_types := w.get_damage_types()
	var crit_threat := w.get_crit_threat()
	var crit_multiplier := w.get_crit_multiplier()
	var is_ranged := w.is_ranged()

	var proficient := w.get_proficiency().is_empty()
	for cat in w.get_proficiency():
		if proficiencies.has(cat):
			proficient = true
			break
	var prof_penalty := 0 if proficient else NON_PROFICIENCY_PENALTY

	var atk := w.get_attack() + prof_penalty
	if is_ranged:
		atk += dex_mod
	else:
		atk += str_mod

	return {
		"weapon": w,
		"damage_dice": w.get_damage_dice(),
		"damage_types": damage_types,
		"attack": int(atk),
		"crit_threat": crit_threat,
		"crit_multiplier": crit_multiplier,
		"proficient": proficient,
		"proficiency_penalty": prof_penalty,
		"is_ranged": is_ranged,
		"is_two_handed": w.is_two_handed,
	}




func apply_damage(damage: int, dt: Artifact.DamageType, options: Dictionary = {}) -> Dictionary:
	var dt_name := Artifact.damage_type_name(dt)

	if options.get("immunities", []).has(dt_name):
		return {"final": 0, "reduction_applied": int(damage), "reason": "immunity"}

	var reduction := int(options.get("reductions", {}).get(dt_name, 0))
	if reduction <= 0:
		return {"final": int(damage), "reduction_applied": 0, "reason": ""}

	var bypass := false
	var mat: StringName = options.get("weapon_material", &"")
	if options.get("is_magic", false):
		bypass = true
	if options.has("bypass_materials") and options["bypass_materials"] is Dictionary:
		var bm: Dictionary = options["bypass_materials"]
		if bm.has(dt_name) and (bm[dt_name] is Array and bm[dt_name].has(mat) or bm[dt_name] == mat):
			bypass = true

	if bypass:
		return {"final": int(damage), "reduction_applied": 0, "reason": "bypassed"}

	return {"final": max(0, damage - reduction), "reduction_applied": reduction, "reason": "reduction"}

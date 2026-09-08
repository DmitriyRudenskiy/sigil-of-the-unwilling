class_name BattleActionResolver
extends RefCounted

const BattleDamageResolver = preload("res://scripts/systems/BattleDamageResolver.gd")


static func apply_attack(
	state: BattleState,
	atk: BattleState.BattleUnit,
	def: BattleState.BattleUnit,
	is_melee_attack: bool,
	rng: RandomNumberGenerator,
	consume_action: bool = true
) -> Dictionary:
	if atk == null or def == null or not atk.is_alive() or not def.is_alive():
		return {}

	var bonuses := _get_hero_bonuses(state, atk, def)
	var attacker_bonus: int = bonuses[0]
	var defender_bonus: int = bonuses[1]

	var first_strike_triggered := _apply_first_strike(
		state, atk, def, is_melee_attack, rng, attacker_bonus, defender_bonus
	)

	var charge_mult := _get_charge_multiplier(atk)

	var ctx := {
		"is_melee": is_melee_attack,
		"rng": rng,
		"atk_bonus": attacker_bonus,
		"def_bonus": defender_bonus,
	}
	var result: Dictionary = BattleDamageResolver.resolve(state, atk, def, ctx)
	if result.is_empty():
		return result

	if first_strike_triggered:
		result["first_strike"] = true
	result = _apply_charge(atk, def, result, charge_mult)

	def.set_count(def.get_count() - int(result.get("kills", 0)))
	if consume_action:
		atk.has_moved = true

	if def.get_count() <= 0:
		if not _try_rebirth(state, def, rng, result):
			state.kill_unit(def)

	state.invalidate_board_cache()
	state.check_end()
	return result


static func apply_spell(
	state: BattleState,
	spell_id: StringName,
	caster: BattleState.BattleUnit,
	target: BattleState.BattleUnit,
	caster_hero_bonus: Dictionary,
	target_hero_bonus: Dictionary,
	rng: RandomNumberGenerator,
	registry: Node = null  
) -> Dictionary:
	var is_res := spell_id == &"resurrection"
	if caster == null or target == null or not caster.is_alive():
		return {"result": "invalid_target"}
	if is_res and target.is_alive():
		return {"result": "invalid_target"}
	if not is_res and not target.is_alive():
		return {"result": "invalid_target"}

	# ИСПРАВЛЕНИЕ: единый путь
	var spell_registry: Node = registry if registry != null else Services.resolve(&"spells")

	var result := SpellCaster.cast(
		spell_id, target, caster_hero_bonus, target_hero_bonus, rng, spell_registry
	)

	if result.get("result") == "success":
		if result.has("damage") and int(result.get("damage", 0)) > 0:
			var kills := int(result.get("kills", 0))
			target.set_count(target.get_count() - kills)
			if target.get_count() <= 0:
				state.kill_unit(target)
		if result.has("heal") and int(result.get("heal", 0)) > 0:
			var hp: int = maxi(1, int(target.get_hp()))
			var healed := mini(int(result.get("heal", 0)) / hp, target.max_count - target.get_count())
			if healed > 0:
				target.set_count(target.get_count() + healed)
				result["healed"] = healed
		if result.has("revive_count"):
			target.set_count(int(result["revive_count"]))
			state.revive_unit(target)
			result["revived"] = true

	state.invalidate_board_cache()
	state.check_end()
	return result


static func apply_sacrifice(
	state: BattleState,
	acting: BattleState.BattleUnit,
	sacrifice: Dictionary,
	target: BattleState.BattleUnit,
	cost: Variant,
	rng: RandomNumberGenerator
) -> Dictionary:
	if acting == null or not acting.is_alive():
		return {"result": "invalid_actor"}
	if target == null or not target.is_alive():
		return {"result": "invalid_target"}
	if sacrifice == null:
		return {"result": "invalid_cost"}

	var cost_type := String(sacrifice.get("type", "")).to_lower()
	var res_id: Variant = null
	var amount: int = 0
	var slot: Variant = null
	var storage: Variant = null
	if cost_type == &"follower":
		var follower: BattleState.BattleUnit = sacrifice.get("unit", null)
		if follower == null or not follower.is_alive() or follower.side != acting.side:
			return {"result": "invalid_cost"}
	elif cost_type == &"resource":
		storage = cost
		if not (storage is Dictionary):
			return {"result": "insufficient_cost"}
		res_id = sacrifice.get("resource", null)
		amount = int(sacrifice.get("amount", 0))
		if res_id == null or not storage.has(res_id):
			return {"result": "insufficient_cost"}
		if int(storage.get(res_id, 0)) < amount:
			return {"result": "insufficient_cost"}
	elif cost_type == &"artifact":
		slot = sacrifice.get("slot", null)
		if slot == null:
			return {"result": "invalid_cost"}
		if cost == null or not _artifact_available(cost, slot):
			return {"result": "invalid_cost"}
	else:
		return {"result": "invalid_cost"}

	target.set_count(0)
	state.kill_unit(target)

	if cost_type == &"follower":
		state.kill_unit(sacrifice.get("unit"))
	elif cost_type == &"resource":
		(storage as Dictionary)[res_id] = int(storage.get(res_id, 0)) - amount
	elif cost_type == &"artifact":
		_inventory_remove_artifact(cost, slot)

	acting.has_moved = true
	state.invalidate_board_cache()
	state.check_end()

	return {"result": "success", "finished": target, "cost_type": cost_type}

static func _artifact_available(inventory: Variant, slot: Variant) -> bool:
	if inventory == null:
		return false
	if inventory.has_method("get_equipped"):
		return inventory.get_equipped(slot) != null
	if inventory is Dictionary:
		return inventory.has(slot) and inventory[slot] != null
	return false

static func _inventory_remove_artifact(inventory: Variant, slot: Variant) -> void:
	if inventory == null:
		return
	if inventory.has_method("unequip"):
		inventory.unequip(slot)
	elif inventory is Dictionary:
		inventory[slot] = null

static func _get_hero_bonuses(
	state: BattleState,
	atk: BattleState.BattleUnit,
	def: BattleState.BattleUnit
) -> Array:
	var atk_bonus: int = int(state.attacker_hero_bonus.get(&"attack", 0)) \
		if atk.side == BattleState.Side.ATTACKER \
		else int(state.defender_hero_bonus.get(&"attack", 0))
	var def_bonus: int = int(state.defender_hero_bonus.get(&"defense", 0)) \
		if def.side == BattleState.Side.DEFENDER \
		else int(state.attacker_hero_bonus.get(&"defense", 0))
	return [atk_bonus, def_bonus]


static func _apply_first_strike(
	state: BattleState,
	atk: BattleState.BattleUnit,
	def: BattleState.BattleUnit,
	is_melee: bool,
	rng: RandomNumberGenerator,
	atk_bonus: int,
	def_bonus: int
) -> bool:
	if not (is_melee and def.has_tag("first_strike") and not def.has_retaliated):
		return false
	def.has_retaliated = true
	var fs_result = BattleRules.calculate_attack(def, atk, true, rng, def_bonus, atk_bonus)
	if not fs_result.is_empty():
		atk.set_count(atk.get_count() - int(fs_result.get("kills", 0)))
		if atk.get_count() <= 0:
			state.kill_unit(atk)
	return true


static func _get_charge_multiplier(atk: BattleState.BattleUnit) -> float:
	if atk.has_tag("charge") and atk.distance_moved_this_turn >= 3:
		return GameNumbers.CHARGE_MULT
	return 1.0


static func _apply_charge(
	atk: BattleState.BattleUnit,
	def: BattleState.BattleUnit,
	result: Dictionary,
	charge_mult: float
) -> Dictionary:
	if charge_mult <= 1.0:
		return result
	result["damage"] = int(result["damage"] * charge_mult)
	var hp: int = max(1, def.get_hp())
	result["kills"] = max(1, result["damage"] / hp)
	result["kills"] = min(result["kills"], def.get_count())
	result["charge"] = true
	return result


static func _try_rebirth(
	state: BattleState,
	def: BattleState.BattleUnit,
	rng: RandomNumberGenerator,
	result: Dictionary
) -> bool:
	if def == null or not def.has_tag("rebirth") or def.already_reborn:
		return false
	if rng.randf() >= GameNumbers.REBIRTH_CHANCE:
		return false
	def.already_reborn = true
	def.set_count(max(1, int(def.max_count * 0.5)))
	state.revive_unit(def)
	result["rebirth"] = true
	return true

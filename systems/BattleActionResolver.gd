## scripts/battle/BattleActionResolver.gd
class_name BattleActionResolver
extends RefCounted
## Вся боевая логика: атака, заклинания, чардж, ребёрт, первый удар.
## BattleState передаётся как параметр — резолвер НЕ хранит состояние.
##
## Использование:
##   var result := BattleActionResolver.apply_attack(state, atk, def, true, rng)
##   var spell_result := BattleActionResolver.apply_spell(state, id, caster, target, ...)

const ServiceContainer = preload("res://core/ServiceContainer.gd")
const ServiceLocator = preload("res://core/ServiceLocator.gd")
const BattleDamageResolver = preload("res://systems/BattleDamageResolver.gd")


# ==================== АТАКА ====================
## Полный цикл атаки: первый удар → урон → чардж → ребёрт → мутация состояния.
## Возвращает Dictionary с результатом (damage, kills, first_strike, charge, rebirth, ...).
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

	# Первый удар (до основной атаки)
	var first_strike_triggered := _apply_first_strike(
		state, atk, def, is_melee_attack, rng, attacker_bonus, defender_bonus
	)

	# Множитель чарджа
	var charge_mult := _get_charge_multiplier(atk)

	# Основной расчёт урона через BattleDamageResolver
	var ctx := {
		"is_melee": is_melee_attack,
		"rng": rng,
		"atk_bonus": attacker_bonus,
		"def_bonus": defender_bonus,
	}
	var result: Dictionary = BattleDamageResolver.resolve(state, atk, def, ctx)
	if result.is_empty():
		return result

	# Чардж
	if first_strike_triggered:
		result["first_strike"] = true
	result = _apply_charge(atk, def, result, charge_mult)

	# Мутация состояния
	def.set_count(def.get_count() - int(result.get("kills", 0)))
	if consume_action:
		atk.has_moved = true

	if def.get_count() <= 0:
		if not _try_rebirth(state, def, rng, result):
			state.kill_unit(def)

	state.invalidate_board_cache()
	state.check_end()
	return result


# ==================== ЗАКЛИНАНИЕ ====================
## Полный цикл каста: валидация → урон/эффект → мутация состояния.
## `registry` — SpellRegistry (инъекция вместо autoload `Spells`).
static func apply_spell(
	state: BattleState,
	spell_id: StringName,
	caster: BattleState.BattleUnit,
	target: BattleState.BattleUnit,
	caster_hero_bonus: Dictionary,
	target_hero_bonus: Dictionary,
	rng: RandomNumberGenerator,
	registry: Node = null  # SpellRegistry; null → ServiceContainer.current.spells
) -> Dictionary:
	var is_res := spell_id == &"resurrection"
	if caster == null or target == null or not caster.is_alive():
		return {"result": "invalid_target"}
	if is_res and target.is_alive():
		return {"result": "invalid_target"}
	if not is_res and not target.is_alive():
		return {"result": "invalid_target"}

	# Инъекция реестра: параметр → ServiceLocator → autoload
	var spell_registry: Node = ServiceLocator.resolve(registry, &"spells")

	var result := SpellCaster.cast(
		spell_id, target, caster_hero_bonus, target_hero_bonus, rng, spell_registry
	)

	if result.get("result") == "success":
		# Обработка урона
		if result.has("damage") and int(result.get("damage", 0)) > 0:
			var kills := int(result.get("kills", 0))
			target.set_count(target.get_count() - kills)
			if target.get_count() <= 0:
				state.kill_unit(target)
		# Обработка исцеления
		if result.has("heal") and int(result.get("heal", 0)) > 0:
			var hp: int = maxi(1, int(target.get_hp()))
			var healed := mini(int(result.get("heal", 0)) / hp, target.max_count - target.get_count())
			if healed > 0:
				target.set_count(target.get_count() + healed)
				result["healed"] = healed
		# Обработка воскрешения (РФ4-2)
		if result.has("revive_count"):
			target.set_count(int(result["revive_count"]))
			state.revive_unit(target)
			result["revived"] = true

	state.invalidate_board_cache()
	state.check_end()
	return result


# ==================== ПРИВАТНЫЕ ХЕЛПЕРЫ ====================
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
		return GameSettings.CHARGE_MULT
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
	if rng.randf() >= GameSettings.REBIRTH_CHANCE:
		return false
	def.already_reborn = true
	def.set_count(max(1, int(def.max_count * 0.5)))
	state.revive_unit(def)
	result["rebirth"] = true
	return true

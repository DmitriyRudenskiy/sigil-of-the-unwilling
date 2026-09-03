## R2 (world-controller-decoupling): боевая эмуляция + тестирование заклинаний
## вынесены из SocketController в отдельный класс (weak coupling, KISS).
## RefCounted, без class_name — detached-тесты не грузят автозагрузки.
extends RefCounted

# Все типы ниже — class_name (автозагрузки), поэтому типизировать можно
# напрямую, без preload.
const BattleSpellBridge = preload("res://scripts/data/BattleSpellBridge.gd")
const ServiceLocatorScript = preload("res://scripts/core/ServiceLocator.gd")

# ---------- SPELL TESTING ----------

## Вернуть все заклинания из автозагруженного SpellRegistry («Spells»). ##
func get_spells() -> Dictionary:
	var reg = ServiceLocatorScript.resolve(null, &"spells")
	if reg == null:
		return {"error": "SpellRegistry (autoload 'Spells') not found"}
	if reg.get_all_spells().is_empty():
		reg.ensure_definitions()
	var list = reg.get_all_spells()
	var out: Array = []
	for s in list:
		out.append({"id": str(s.id), "name": s.display_name, "school": s.school, "level": s.level, "mana": s.base_mana})
	return {"spells": out, "count": out.size()}

## Бросить заклинание по синтетическому юниту и вернуть результат SpellCaster. ##
func cast_spell(args: Dictionary) -> Dictionary:
	var spell_id: Variant = args.get("spell_id", "")
	if not (spell_id is String) or spell_id.is_empty():
		return {"error": "Field 'spell_id' is required and must be a non-empty string"}
	var tags: Array = args.get("tags", [])
	if not (tags is Array):
		tags = []
	var hp: int = int(args.get("hp", 100))
	var count: int = 10 if not args.has("count") else int(args.get("count"))
	var resistant: bool = bool(args.get("resistant", false))
	if resistant and not tags.has("magic_resistant"):
		tags.append("magic_resistant")
	var stats := UnitStats.new("test_target", "Test Target", 3, 2, hp, 4, 5, tags)
	var stack := UnitStack.new(stats, count)
	var unit := BattleState.BattleUnit.new(stack)
	unit.max_count = maxi(count, 10)
	if unit.get_count() <= 0:
		unit.set_count(count)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var reg = ServiceLocatorScript.resolve(null, &"spells")
	if reg != null and reg.get_all_spells().is_empty():
		reg.ensure_definitions()
	var caster_bonus := {"spell_power": 8, "attack": 6, "defense": 5, "knowledge": 5}
	var target_bonus := {"knowledge": int(resistant), "defense": 5}
	return SpellCaster.cast(StringName(spell_id), unit, caster_bonus, target_bonus, rng, null)

# ---------- BATTLE EMULATION ----------

## Построить UnitStack из спецификации {id, hp, count, tags, attack, ...}. ##
func army_stack(spec: Dictionary) -> UnitStack:
	var tags: Array = []
	if spec.has("tags") and spec["tags"] is Array:
		tags = spec["tags"]
	var stats := UnitStats.new(
		str(spec.get("id", "unit")),
		str(spec.get("name", spec.get("id", "unit"))),
		int(spec.get("attack", 3)),
		int(spec.get("base_damage", 3)),
		int(spec.get("hp", 50)),
		int(spec.get("speed", 5)),
		int(spec.get("defense", 3)),
		tags
	)
	return UnitStack.new(stats, maxi(1, int(spec.get("count", 10))))

func side_name(side: int) -> String:
	return "attacker" if side == BattleState.Side.ATTACKER else "defender"

func summarize(units: Array) -> Array:
	var out: Array = []
	for u in units:
		if u != null and u.is_alive():
			out.append({"name": u.get_display_name(), "count": u.get_count(), "hp": u.get_hp()})
	return out

func nearest_enemy(ref_cell: Vector2i, units: Array) -> BattleState.BattleUnit:
	var best: BattleState.BattleUnit = null
	var best_d := 1 << 30
	for u in units:
		if u != null and u.is_alive():
			var d := HexUtils.hex_distance(ref_cell, u.cell)
			if d < best_d:
				best_d = d
				best = u
	return best

## Простой авто-ИИ: идти к ближайшему врагу и бить, когда в зоне доступа. ##
func advance_toward(state: BattleState, u: BattleState.BattleUnit, target: BattleState.BattleUnit) -> void:
	var blocked := state.build_all_blocked(u, {})
	var reachable := state.get_reachable_for_unit(u, func() -> Dictionary: return blocked)
	var best := u.cell
	var best_d := HexUtils.hex_distance(u.cell, target.cell)
	for c in reachable:
		var d := HexUtils.hex_distance(c, target.cell)
		if d < best_d:
			best_d = d
			best = c
	if best != u.cell:
		state.do_move(u, best)

## Полный цикл боя до победы или лимита ходов. ##
func run_auto_battle(state: BattleState, rng: RandomNumberGenerator) -> Dictionary:
	state.build_queue()
	var events: Array = []
	var turn := 0
	const MAX_TURNS := 400
	while not state.battle_over and turn < MAX_TURNS:
		state.advance_turn()
		turn += 1
		if state.battle_over:
			break
		var u: BattleState.BattleUnit = state.active_unit
		if u == null or not u.is_alive():
			continue
		if u.is_stunned():
			u.has_moved = true
			continue
		var enemy_side := BattleState.Side.DEFENDER if u.side == BattleState.Side.ATTACKER else BattleState.Side.ATTACKER
		var target := nearest_enemy(u.cell, state.get_units_by_side(enemy_side))
		if target == null:
			break
		var dist := HexUtils.hex_distance(u.cell, target.cell)
		var melee := not u.is_ranged()
		var adjacent := dist == 1
		var ranged_shot := u.is_ranged() and dist > 1
		if adjacent or ranged_shot:
			var res := state.apply_attack(u, target, melee, rng, true)
			events.append({"turn": turn, "unit": u.get_display_name(), "action": "attack", "result": res})
		else:
			advance_toward(state, u, target)
	return {
		"winner": side_name(state.battle_winner),
		"battle_over": state.battle_over,
		"turns": turn,
		"atk_survivors": summarize(state.get_units_by_side(BattleState.Side.ATTACKER)),
		"def_survivors": summarize(state.get_units_by_side(BattleState.Side.DEFENDER)),
		"events": events,
	}

## Эмуляция боя: построить армии, прогнать авто-бой, вернуть результат. ##
func emulate_battle(req: Dictionary) -> Dictionary:
	var atk_specs: Variant = req.get("attacker_army", [])
	var def_specs: Variant = req.get("defender_army", [])
	if not (atk_specs is Array) or not (def_specs is Array):
		return {"error": "Fields 'attacker_army' and 'defender_army' must be arrays"}
	var atk_stacks: Array[UnitStack] = []
	var def_stacks: Array[UnitStack] = []
	for s in atk_specs:
		if s is Dictionary:
			atk_stacks.append(army_stack(s))
	for s in def_specs:
		if s is Dictionary:
			def_stacks.append(army_stack(s))
	if atk_stacks.is_empty() or def_stacks.is_empty():
		return {"error": "Both armies must have at least one stack"}
	var atk_bonus := {"attack": 0, "defense": 0, "spell_power": 0, "knowledge": 0}
	var def_bonus := {"attack": 0, "defense": 0, "spell_power": 0, "knowledge": 0}
	if req.has("attacker_bonus") and req["attacker_bonus"] is Dictionary:
		atk_bonus = req["attacker_bonus"]
	if req.has("defender_bonus") and req["defender_bonus"] is Dictionary:
		def_bonus = req["defender_bonus"]
	var state := BattleState.new()
	state.set_hero_bonuses(atk_bonus, def_bonus)
	state.place_army(atk_stacks, def_stacks)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var report := run_auto_battle(state, rng)
	report["atk_loss"] = total_count(atk_specs)
	report["def_loss"] = total_count(def_specs)
	return report

func total_count(specs: Array) -> int:
	var total := 0
	for s in specs:
		if s is Dictionary:
			total += maxi(0, int(s.get("count", 0)))
	return total

## Проверить одно заклинание в контексте боя (apply_spell, как в игре). ##
func cast_in_battle(args: Dictionary) -> Dictionary:
	var spell_id: Variant = args.get("spell_id", "")
	if not (spell_id is String) or spell_id.is_empty():
		return {"error": "Field 'spell_id' is required and must be a non-empty string"}
	var caster_tags: Array = args.get("caster_tags", [])
	if not (caster_tags is Array):
		caster_tags = []
	var target_tags: Array = args.get("target_tags", [])
	if not (target_tags is Array):
		target_tags = []
	var caster_hp: int = int(args.get("caster_hp", 60))
	var caster_count: int = maxi(1, int(args.get("caster_count", 10)))
	var target_hp: int = int(args.get("target_hp", 100))
	var target_count: int = int(args.get("target_count", 10))
	var resistant: bool = bool(args.get("resistant", false))
	if resistant and not target_tags.has("magic_resistant"):
		target_tags.append("magic_resistant")
	var caster_bonus: Dictionary = args.get("caster_bonus", {"spell_power": 8, "attack": 6, "defense": 5, "knowledge": 5})
	var target_bonus: Dictionary = args.get("target_bonus", {"knowledge": int(resistant), "defense": 5})
	var reg = ServiceLocatorScript.resolve(null, &"spells")
	if reg != null and reg.get_all_spells().is_empty():
		reg.ensure_definitions()
	var caster_stack := UnitStack.new(
		UnitStats.new("caster", "Caster", 6, 3, caster_hp, 6, 5, caster_tags), caster_count)
	var target_stack := UnitStack.new(
		UnitStats.new("target", "Target", 3, 2, target_hp, 4, 5, target_tags), maxi(1, target_count))
	var state := BattleState.new()
	state.set_hero_bonuses(caster_bonus, target_bonus)
	state.place_army([caster_stack], [target_stack])
	var caster_unit: BattleState.BattleUnit = state.attacker_units[0]
	var target_unit: BattleState.BattleUnit = state.defender_units[0]
	if spell_id == &"resurrection" or target_count <= 0:
		target_unit.set_count(0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return state.apply_spell(
		StringName(spell_id), caster_unit, target_unit, caster_bonus, target_bonus, rng)

## Выполнить последовательность шагов на ОДНО BattleState подряд (ротация). ##
func sequence_battle(args: Dictionary) -> Dictionary:
	var sequence: Variant = args.get("sequence", [])
	if not (sequence is Array):
		return {"error": "Field 'sequence' must be an array of steps"}
	var caster_tags: Array = args.get("caster_tags", [])
	if not (caster_tags is Array):
		caster_tags = []
	var target_tags: Array = args.get("target_tags", [])
	if not (target_tags is Array):
		target_tags = []
	var caster_hp: int = maxi(1, int(args.get("caster_hp", 100)))
	var caster_start_hp: int = maxi(1, int(args.get("caster_start_hp", caster_hp)))
	var caster_count: int = maxi(1, int(args.get("caster_count", 10)))
	var target_hp: int = maxi(1, int(args.get("target_hp", 200)))
	var target_count: int = maxi(1, int(args.get("target_count", 20)))
	var resistant: bool = bool(args.get("resistant", false))
	if resistant and not target_tags.has("magic_resistant"):
		target_tags.append("magic_resistant")
	var caster_bonus: Dictionary = args.get("caster_bonus", {"spell_power": 8, "attack": 6, "defense": 5, "knowledge": 5})
	var target_bonus: Dictionary = args.get("target_bonus", {"knowledge": int(resistant), "defense": 5})
	var reg = ServiceLocatorScript.resolve(null, &"spells")
	if reg != null and reg.get_all_spells().is_empty():
		reg.ensure_definitions()
	var caster_stack := UnitStack.new(
		UnitStats.new("caster", "Caster", 6, 3, caster_hp, 6, 5, caster_tags), caster_count)
	var target_stack := UnitStack.new(
		UnitStats.new("target", "Target", 3, 2, target_hp, 4, 5, target_tags), target_count)
	var state := BattleState.new()
	state.set_hero_bonuses(caster_bonus, target_bonus)
	state.place_army([caster_stack], [target_stack])
	var caster_unit: BattleState.BattleUnit = state.attacker_units[0]
	var target_unit: BattleState.BattleUnit = state.defender_units[0]
	if caster_start_hp < caster_unit.get_hp():
		caster_unit.stats.hp = caster_start_hp
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var steps: Array = []
	for cmd in sequence:
		if not (cmd is Dictionary):
			steps.append({"skipped": str(cmd)})
			continue
		var kind: String = cmd.get("cmd", "")
		if kind == "cast":
			var sid: Variant = cmd.get("spell", "")
			if not (sid is String) or sid.is_empty():
				steps.append({"cmd": "cast", "error": "Field 'spell' required"})
				continue
			var target_for: BattleState.BattleUnit = target_unit
			if bool(cmd.get("self", false)):
				target_for = caster_unit
			if sid == "resurrection":
				target_unit.set_count(0)
			var r = state.apply_spell(
				StringName(sid), caster_unit, target_for, caster_bonus, target_bonus, rng)
			steps.append({"cmd": "cast", "spell": sid, "result": r})
		elif kind == "attack":
			var r = state.apply_attack(caster_unit, target_unit, not caster_unit.is_ranged(), rng, true)
			steps.append({"cmd": "attack", "result": r})
		elif kind == "enemy":
			var r = state.apply_attack(target_unit, caster_unit, not target_unit.is_ranged(), rng, true)
			steps.append({"cmd": "enemy", "result": r})
	return {
		"steps": steps,
		"caster_hp": caster_unit.get_hp(),
		"caster_max_hp": caster_unit.get_hp(),
		"caster_alive": caster_unit.is_alive(),
		"caster_count": caster_unit.get_count(),
		"target_hp": target_unit.get_hp(),
		"target_alive": target_unit.is_alive(),
		"target_count": target_unit.get_count(),
	}

## Конвертировать боевое заклинание в карточное и применить его в бою. ##
func battle_spell(args: Dictionary) -> Dictionary:
	var spell_id: Variant = args.get("spell_id", "")
	if not (spell_id is String) or spell_id.is_empty():
		return {"error": "Field 'spell_id' is required and must be a non-empty string"}
	var reg = ServiceLocatorScript.resolve(null, &"spells")
	if reg == null:
		return {"error": "SpellRegistry (autoload 'Spells') not found"}
	if reg.get_all_spells().is_empty():
		reg.ensure_definitions()
	var def: SpellRegistry.SpellDef = reg.get_spell(StringName(spell_id))
	if def == null:
		return {"spell": null, "apply": {"result": "not_found", "spell_id": spell_id}, "registered": false}
	var spell = BattleSpellBridge.to_spell(def)
	var spell_reg = ServiceLocatorScript.resolve(null, &"spellbook")
	var registered := false
	if spell_reg != null:
		spell_reg.register(spell)
		registered = true
	var tags: Array = args.get("tags", [])
	if not (tags is Array):
		tags = []
	var hp: int = int(args.get("hp", 100))
	var count: int = 10 if not args.has("count") else int(args.get("count"))
	var resistant: bool = bool(args.get("resistant", false))
	if resistant and not tags.has("magic_resistant"):
		tags.append("magic_resistant")
	var stats := UnitStats.new("test_target", "Test Target", 3, 2, hp, 4, 5, tags)
	var stack := UnitStack.new(stats, count)
	var unit := BattleState.BattleUnit.new(stack)
	unit.max_count = maxi(count, 10)
	if unit.get_count() <= 0:
		unit.set_count(count)
	if str(spell.template) == "REVIVE":
		unit.set_count(0)
	var caster_bonus := {"spell_power": 8, "attack": 6, "defense": 5, "knowledge": 5}
	var target_bonus := {"knowledge": int(resistant), "defense": 5}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var apply_result = BattleSpellBridge.apply_spell(spell, unit, caster_bonus, target_bonus, rng)
	return {"spell": spell.to_dict(), "apply": apply_result, "registered": registered}

## Состояние карточной системы (для проверки интеграции конвертации). ##
func spell_registry() -> Dictionary:
	var spell_reg = ServiceLocatorScript.resolve(null, &"spellbook")
	if spell_reg == null:
		return {"error": "SpellbookRegistry (autoload 'Spellbook') not found"}
	return {"count": spell_reg.get_count(), "template_count": spell_reg.get_template_count()}

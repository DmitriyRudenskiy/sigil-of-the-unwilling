class_name DnDBattleFactory
extends RefCounted

## Production entry point for building and resolving D&D battles from explicit
## character definitions. This moves the per-character D&D combat model from a
## test-only capability to a production API: a game scenario/event can describe
## a set of D&D characters (class/race/abilities/HP/weapon) and get back a
## resolved battle (winner + surviving characters) without touching the
## stack-model battle flow (WorldBattleCoordinator / BattleFlow).
##
## The factory is the seam between "game content" (D&D character definitions)
## and the battle engine (BattleStateBuilder + BattleEmulator). It is
## deterministic (a given seed resolves the same battle) and headless-verifiable.

## String -> DNDAbilityScores.Ability mapping (for DnDCharacterDef.abilities).
const _ABILITY_KEYS := {
	"str": DNDAbilityScores.Ability.STR,
	"dex": DNDAbilityScores.Ability.DEX,
	"con": DNDAbilityScores.Ability.CON,
	"int": DNDAbilityScores.Ability.INT,
	"wis": DNDAbilityScores.Ability.WIS,
	"cha": DNDAbilityScores.Ability.CHA,
}


## A single D&D character definition (the input to the factory).
class DnDCharacterDef:
	var id: String = ""
	var name: String = ""
	## Class/race ids (empty = no class/racial tactical bonuses).
	var class_id: String = ""
	var race_id: String = ""
	var weapon: String = "longsword"
	var is_ranged: bool = false
	var max_hp: int = 10
	var speed: int = 5
	## Ability scores: "str"/"dex"/"con"/"int"/"wis"/"cha" -> score (1-30).
	var abilities: Dictionary = {}
	## DNDArmorClass.ArmorType (default NONE). AC is derived from DEX + armor.
	var armor_type: int = DNDArmorClass.ArmorType.NONE

	func _init(p_id: String = "", p_name: String = "") -> void:
		id = p_id
		name = p_name


## Build a DnDCombatantProfile from a definition.
## AC is derived from DEX + armor_type (see DnDCombatantProfile.get_ac()).
static func build_profile(def: DnDCharacterDef) -> DnDCombatantProfile:
	var p := DnDCombatantProfile.new(def.id, def.name)
	for key in def.abilities:
		var k := str(key).to_lower()
		if _ABILITY_KEYS.has(k):
			p.abilities.set_score(_ABILITY_KEYS[k], int(def.abilities[key]))
	p.class_id = def.class_id
	p.race_id = def.race_id
	p.weapon = def.weapon
	p.is_ranged = def.is_ranged
	p.max_hp = maxi(1, def.max_hp)
	p.armor.armor_type = def.armor_type
	return p


## Build a UnitStack carrying the D&D profile (a single per-character combatant).
## count = 1 (a D&D character is one unit on the board); speed from the def.
static func build_stack(def: DnDCharacterDef) -> UnitStack:
	var stats := UnitStats.new(def.id, def.name, 0, 0, 1, def.speed, 0, [def.id])
	var stack := UnitStack.new(stats, 1)
	stack.dnd_profile = build_profile(def)
	return stack


## Build a full BattleState from two sides of D&D character definitions.
## (BattleStateBuilder transfers each dnd_profile to its BattleUnit and inits
## the HP pool.)
static func build_battle(ally_defs: Array, enemy_defs: Array) -> BattleState:
	var builder := BattleStateBuilder.new()
	builder.set_attacker_army(_defs_to_stacks(ally_defs))
	builder.set_defender_army(_defs_to_stacks(enemy_defs))
	return builder.build()


## Resolve a D&D battle to completion (winner + surviving characters) via the
## emulator. Deterministic for a given seed. Returns the BattleEmulator result:
## {winner, atk_survivors, def_survivors, ...}.
static func simulate(ally_defs: Array, enemy_defs: Array, seed: int) -> Dictionary:
	var state := build_battle(ally_defs, enemy_defs)
	state.seed_dnd(seed)  # T12: d20-путь dnd-юнитов детерминирован по seed
	var emu := BattleEmulator.new()
	return emu.run_auto_battle(state)


static func _defs_to_stacks(defs: Array) -> Array:
	var stacks: Array = []
	for d in defs:
		if d is DnDCharacterDef:
			stacks.append(build_stack(d))
	return stacks

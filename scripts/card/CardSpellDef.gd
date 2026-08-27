## scripts/card/CardSpellDef.gd
class_name CardSpellDef
extends RefCounted
## Определение карточного заклинания (LoR/MTG-стиль).
## Независимо от существующей системы BattleState/SpellRegistry (HoMM3-стиль).

enum TargetType {
	NONE,
	ALLY_UNIT,
	ENEMY_UNIT,
	ANY_UNIT,
	ALLY_NEXUS,
	ENEMY_NEXUS,
	ANY_NEXUS,
	ENEMY_SPELL,
	ENEMY_RELIC,
	ALL_ENEMY_UNITS,
	ALL_ALLY_UNITS,
	TWO_ALLY_UNITS,
	ALLY_UNIT_IN_HAND,
	ALLY_UNIT_IN_GRAVE,
	SELF,
	SAME_AS_PREVIOUS,
}

enum EffectType {
	DESTROY,
	EXILE,
	RETURN_TO_HAND,
	RETURN_TO_DECK,
	DEAL_DAMAGE,
	MODIFY_STAT_TEMP,
	MODIFY_STAT_PERM,
	APPLY_STATUS,
	DRAW,
	DISCARD,
	CANCEL,
	CREATE_TOKEN,
	SWAP_POSITION,
	MODIFY_POWER,
	MARKET_ACTION,
	ACTION_REPEAT,
	CHANGE_CONTROL,
	TRIGGER_ON_DISCARD,
	HEAL,
}

enum StatusEffect {
	SILENCE,
	FROZEN,
	STUN,
	QUICKDRAW,
	UNBLOCKABLE,
	OVERWHELM,
	ARMORED,
	WARD,
	CHALLENGE,
	CANNOT_BLOCK,
	CANNOT_ATTACK,
}

var id: StringName
var display_name: String
var spell_type: String = "fast"      # fast | slow | burst
var cost: int = 0
var school: StringName = &""         # привязка к школе
var rarity: int = 0                  # 0=common 1=rare 2=epic
var description: String = ""
var effects: Array[Dictionary] = []  # [{action, target, params}]
var condition: Dictionary = {}       # глобальное условие каста

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"type": spell_type,
		"cost": cost,
		"school": school,
		"rarity": rarity,
		"effects": effects,
		"condition": condition,
	}

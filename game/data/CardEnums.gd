## scripts/card/CardEnums.gd
class_name CardEnums
extends RefCounted
## Все перечисления карточной системы.

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
	DEAL_DAMAGE,
	DESTROY,
	EXILE,
	RETURN_TO_HAND,
	RETURN_TO_DECK,
	CANCEL,
	MODIFY_STAT_TEMP,
	MODIFY_STAT_PERM,
	APPLY_STATUS,
	DRAW,
	SEARCH,
	DISCARD,
	DISCARD_AND_DRAW,
	HEAL,
	CREATE_TOKEN,
	MODIFY_POWER,
	REDUCE_COST,
	MARKET_ACTION,
	TRIGGER_ON_DISCARD,
	ACTION_REPEAT,
	CHANGE_CONTROL,
	SWAP_POSITION,
	STEAL,
	TRIGGER_ABILITY,
}

enum StatusType {
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
	FLYING,
	DEADLY,
	LIFESTEAL,
	ENDURANCE,
	REGEN,
}

enum SpellSpeed {
	FAST,    # может быть разыграно в ответ (instant)
	SLOW,    # только в свой ход, main phase
	BURST,   # не может быть отвечено
}

enum CardColor {
	FIRE,
	TIME,
	JUSTICE,
	PRIMAL,
	SHADOW,
	MULTIFACTION,
	COLORLESS,
}

## Строка → enum. Для парсинга JSON.
static func parse_target(s: String) -> int:
	return TargetType.get(s.to_upper(), TargetType.NONE)

static func parse_effect(s: String) -> int:
	return EffectType.get(s.to_upper(), EffectType.DEAL_DAMAGE)

static func parse_status(s: String) -> int:
	return StatusType.get(s.to_upper(), StatusType.SILENCE)

static func parse_speed(s: String) -> int:
	match s.to_lower():
		"fast": return SpellSpeed.FAST
		"slow": return SpellSpeed.SLOW
		"burst": return SpellSpeed.BURST
	return SpellSpeed.FAST

static func parse_color(s: String) -> int:
	return CardColor.get(s.to_upper(), CardColor.COLORLESS)

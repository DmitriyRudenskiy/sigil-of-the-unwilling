class_name SpellEnums
extends RefCounted

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
	APPLY_STATUS,
	DRAW,
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
	FAST,
	SLOW,
	BURST,
}

enum SpellColor {
	FIRE,
	TIME,
	JUSTICE,
	PRIMAL,
	SHADOW,
	MULTIFACTION,
	COLORLESS,
}

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
	return SpellColor.get(s.to_upper(), SpellColor.COLORLESS)

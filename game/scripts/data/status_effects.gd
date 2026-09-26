extends RefCounted
class_name StatusEffects

enum Effect {
	HASTE, SLOW, BLESS, CURSE, SHIELD, STONESKIN,
	BLOODLUST, PRECISION, WIND_WALL, WEAKNESS, MISFORTUNE,
	PETRIFIED, BLIND
}

static func is_debuff(effect: int) -> bool:
	return effect in [Effect.SLOW, Effect.CURSE, Effect.WEAKNESS, Effect.MISFORTUNE, Effect.PETRIFIED, Effect.BLIND]

static func is_stun(effect: int) -> bool:
	return effect in [Effect.PETRIFIED, Effect.BLIND]

static func get_name(effect: int) -> String:
	match effect:
		Effect.HASTE: return "Haste"
		Effect.SLOW: return "Slow"
		Effect.BLESS: return "Bless"
		Effect.CURSE: return "Curse"
		Effect.SHIELD: return "Shield"
		Effect.STONESKIN: return "Stoneskin"
		Effect.BLOODLUST: return "Bloodlust"
		Effect.PRECISION: return "Precision"
		Effect.WIND_WALL: return "Wind Wall"
		Effect.WEAKNESS: return "Weakness"
		Effect.MISFORTUNE: return "Misfortune"
		Effect.PETRIFIED: return "Petrified"
		Effect.BLIND: return "Blind"
	return "Unknown"

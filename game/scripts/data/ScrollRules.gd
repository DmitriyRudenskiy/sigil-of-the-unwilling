class_name ScrollRules
extends RefCounted
## Scroll pickup, learn-on-pickup, and once-per-battle casting rules.
static func can_pickup(hero: Object, scroll_spell_id: StringName) -> bool:
	# Can always pick up a scroll; learning it is a separate concern.
	return true

static func apply_pickup(hero: Object, scroll_spell_id: StringName) -> void:
	# Learn-on-pickup: add to spellbook if not already known.
	if not hero.knows(scroll_spell_id):
		hero.learn(scroll_spell_id)

static func can_cast_in_battle(
	hero: Object,
	spell: Dictionary,
	scroll_remaining: int
) -> bool:
	if scroll_remaining <= 0:
		return false
	return hero.can_cast(spell)

static func consume_scroll() -> void:
	# Scrolls are consumed on cast; tracked externally via scroll_remaining.
	pass

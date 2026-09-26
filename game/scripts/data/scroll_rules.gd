class_name ScrollRules
extends RefCounted
static func can_pickup(_hero: Object, _scroll_spell_id: StringName) -> bool:
	return true

static func apply_pickup(hero: Object, scroll_spell_id: StringName) -> void:
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
	pass

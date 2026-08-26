class_name HeroMagic
extends RefCounted
## Magic of the hero: mana, schools, spellbook.
## Accounts for cost with anti_magic and spellbinders_hat semantics.
signal changed

var mana_current: int = 0
var mana_max: int = 0
var schools: Dictionary = {"air": 0, "fire": 0, "water": 0, "earth": 0}
var spellbook: Array[StringName] = []

func init_defaults() -> void:
	mana_max = 20
	mana_current = 20
	schools = {"air": 1, "fire": 0, "water": 0, "earth": 0}
	spellbook = [&"magic_arrow", &"haste"]
	changed.emit()

func knows(spell_id: StringName) -> bool:
	return spellbook.has(spell_id)

func learn(spell_id: StringName) -> bool:
	if knows(spell_id):
		return false
	spellbook.append(spell_id)
	changed.emit()
	return true

func forget(spell_id: StringName) -> bool:
	if not knows(spell_id):
		return false
	spellbook.erase(spell_id)
	changed.emit()
	return true

func can_cast(spell: Dictionary) -> bool:
	var school: String = spell.get("school", "")
	var level: int = spell.get("level", 1)
	var mana_cost := get_mana_cost(spell)
	if schools.get(school, 0) < level:
		return false
	if mana_current < mana_cost:
		return false
	return true

func get_mana_cost(spell: Dictionary) -> int:
	var base: int = spell.get("base_mana", 5)
	var tags: Array = spell.get("tags", [])
	if "anti_magic" in tags:
		return base + 2
	return base

func spend_mana(cost: int) -> bool:
	if mana_current < cost:
		return false
	mana_current -= cost
	changed.emit()
	return true

func refund_mana(cost: int) -> void:
	mana_current = min(mana_current + cost, mana_max)
	changed.emit()

func restore_full() -> void:
	mana_current = mana_max
	changed.emit()

func tick_restore(amount: int = 1) -> void:
	mana_current = min(mana_current + amount, mana_max)
	changed.emit()

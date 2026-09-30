class_name HeroMagic
extends RefCounted
signal changed

var mana_current: int = 0
var mana_max: int = 0
var schools: Dictionary = {}
var spellbook: Array[StringName] = []

func init_defaults() -> void:
	mana_max = 20
	mana_current = 20
	schools = { SchoolType.ID.AIR: 1, SchoolType.ID.FIRE: 0, SchoolType.ID.WATER: 0, SchoolType.ID.EARTH: 0 }
	spellbook = [&"magic_arrow", &"haste"]
	changed.emit()

func school_level(school_id: int) -> int: return int(schools.get(school_id, 0))

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

func can_cast(spell) -> bool:
	var school: String
	var level: int
	if spell is Dictionary:
		school = spell.get("school", "")
		level = spell.get("level", 1)
	else:
		school = spell.school if "school" in spell else ""
		level = spell.level if "level" in spell else 1
	school = school.to_lower()
	var school_id: int = SchoolType.from_key(school)
	var mana_cost := get_mana_cost(spell)
	if school_level(school_id) < level:
		return false
	if mana_current < mana_cost:
		return false
	return true

func get_mana_cost(spell) -> int:
	var base: int
	var tags: Array
	if spell is Dictionary:
		base = spell.get("base_mana", 5)
		tags = spell.get("tags", [])
	else:
		base = spell.base_mana if "base_mana" in spell else 5
		tags = spell.tags if "tags" in spell else []
	if "anti_magic" in tags:
		return base + 2
	return base

func can_cast_def(spell: SpellRegistry.SpellDef) -> bool:
	if spell == null:
		return false
	var school_id: int = SchoolType.from_key(spell.school.to_lower())
	if school_level(school_id) < spell.level:
		return false
	return mana_current >= get_mana_cost_def(spell)

func get_mana_cost_def(spell: SpellRegistry.SpellDef) -> int:
	if spell == null:
		return 0
	var cost := spell.base_mana
	if spell.tags.has("anti_magic"):
		cost += 2
	return cost

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

func serialize_schools() -> Dictionary:
	var out := {}
	for id in schools:
		out[SchoolType.to_key(int(id))] = int(schools[id])
	return out

func deserialize_schools(data: Dictionary) -> void:
	schools.clear()
	for key in data:
		var id: int = SchoolType.from_key(key)
		if SchoolType.is_valid(id): schools[id] = int(data[key])
	for id in SchoolType.all_ids():
		if not schools.has(id): schools[id] = 0

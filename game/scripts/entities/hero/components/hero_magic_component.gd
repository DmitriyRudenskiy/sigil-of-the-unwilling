class_name HeroMagicComponent
extends HeroComponent

var magic: HeroMagic = HeroMagic.new()

signal changed()

func setup_hero(hero: HeroController) -> void:
	super(hero)
	magic.changed.connect(changed.emit)

func initialize() -> void:
	magic.init_defaults()

func set_magic(v: HeroMagic) -> void:
	magic = v

func school_level(school_id: int) -> int:
	return magic.school_level(school_id)

func knows(spell_id: StringName) -> bool:
	return magic.knows(spell_id)

func learn(spell_id: StringName) -> bool:
	return magic.learn(spell_id)

func forget(spell_id: StringName) -> bool:
	return magic.forget(spell_id)

func can_cast(spell) -> bool:
	return magic.can_cast(spell)

func get_mana_cost(spell) -> int:
	return magic.get_mana_cost(spell)

func can_cast_def(spell: SpellRegistry.SpellDef) -> bool:
	return magic.can_cast_def(spell)

func get_mana_cost_def(spell: SpellRegistry.SpellDef) -> int:
	return magic.get_mana_cost_def(spell)

func spend_mana(cost: int) -> bool:
	return magic.spend_mana(cost)

func refund_mana(cost: int) -> void:
	magic.refund_mana(cost)

func restore_full() -> void:
	magic.restore_full()

func tick_restore(amount: int = 1) -> void:
	magic.tick_restore(amount)

func get_mana_current() -> int:
	return magic.mana_current

func set_mana_current(v: int) -> void:
	magic.mana_current = v

func get_mana_max() -> int:
	return magic.mana_max

func set_mana_max(v: int) -> void:
	magic.mana_max = v

func get_spellbook() -> Array[StringName]:
	return magic.spellbook

func set_spellbook(v: Array[StringName]) -> void:
	magic.spellbook = v

func get_schools() -> Dictionary:
	return magic.schools

func set_schools(v: Dictionary) -> void:
	magic.schools = v

func end_turn() -> void:
	var knowledge: int = 0
	if _hero != null:
		knowledge = int(_hero.stats.get("knowledge", 0))
	tick_restore(knowledge)

func serialize() -> Dictionary:
	return {
		"mana_current": magic.mana_current,
		"mana_max": magic.mana_max,
		"magic_schools": magic.serialize_schools(),
		"spellbook": magic.spellbook.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	magic.mana_current = int(data.get("mana_current", magic.mana_current))
	magic.mana_max = int(data.get("mana_max", magic.mana_max))
	magic.deserialize_schools(data.get("magic_schools", {}))
	var raw_spells: Array = data.get("spellbook", magic.spellbook)
	var book: Array[StringName] = []
	for s in raw_spells:
		book.append(StringName(str(s)))
	magic.spellbook = book

class_name BattleSpellbookPanel
extends Control
## Panel of castable spells during battle. Shown as a bottom bar in battle UI.
## Reads HeroMagic + SpellRegistry to list available spells.

signal spell_chosen(spell_id: StringName)

var _hero: HeroController
var _magic: HeroMagic

func setup(hero: HeroController, magic: HeroMagic) -> void:
	_hero = hero
	_magic = magic
	_refresh()

	if _magic != null:
		_magic.changed.connect(_refresh)

func _refresh() -> void:
	# Clear buttons
	for child in get_children():
		if child is Button:
			child.queue_free()

	if _magic == null:
		return

	for spell_id in _magic.spellbook:
		var spell = Spells.get_spell(spell_id)
		if spell == null:
			continue

		if not _magic.can_cast_def(spell):
			continue

		var btn := Button.new()
		btn.text = "%s (%d)" % [spell.display_name, _magic.get_mana_cost_def(spell)]
		btn.tooltip_text = "%s | Lv.%d" % [spell.school, spell.level]
		btn.custom_minimum_size = Vector2(90, 36)
		btn.pressed.connect(_on_spell_pressed.bind(spell_id))
		add_child(btn)

func _on_spell_pressed(spell_id: StringName) -> void:
	spell_chosen.emit(spell_id)

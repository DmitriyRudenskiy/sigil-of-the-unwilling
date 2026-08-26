extends Control
## Simple spellbook screen listing known spells with mana costs.
## Shows spell name, school, level, mana cost. Selectable for casting.

signal spell_selected(spell_id: StringName)

@onready var grid: GridContainer = $ScrollContainer/GridContainer
@onready var mana_label: Label = $ManaLabel

var hero_controller: HeroController
var _spells: Array[StringName] = []

func setup(hero: HeroController) -> void:
	hero_controller = hero
	_update_list()


func _update_list() -> void:
	# Clear existing
	for child in grid.get_children():
		child.queue_free()

	mana_label.text = "Mana: %d / %d" % [hero_controller.mana_current, hero_controller.mana_max]

	var SR = preload("res://scripts/data/SpellRegistry.gd")
	for spell_id in hero_controller.spellbook:
		var spell = SR.get_spell(spell_id)
		if spell == null:
			continue

		var school := hero_controller.magic_schools.get(spell.school, 0)
		if school < spell.level:
			continue

		var btn := Button.new()
		btn.text = "%s (%d MP)" % [spell.display_name, spell.base_mana]
		btn.tooltip_text = "%s | Lv.%d | %s" % [SR.get_school_name(spell.school), spell.level, spell.display_name]
		btn.disabled = hero_controller.mana_current < spell.base_mana
		btn.pressed.connect(_on_spell_pressed.bind(spell_id))
		grid.add_child(btn)


func _on_spell_pressed(spell_id: StringName) -> void:
	_update_list()
	spell_selected.emit(spell_id)

extends "res://tests/gut_base.gd"

## Spell registry: all 20 spells load and validate.


func test_spell_count() -> void:
	var errors := _check_spell_count()
	assert_eq(errors, 0, "test_spell_count — no errors")

func _check_spell_count() -> int:
	var all := Spells.get_all_spells()
	if all.size() != 20:
		printerr("Expected 20 spells, got %d" % all.size())
		return 1
	return 0



func test_all_spells_exist() -> void:
	var errors := _check_all_spells_exist()
	assert_eq(errors, 0, "test_all_spells_exist — no errors")

func _check_all_spells_exist() -> int:
	var expected := [&"magic_arrow", &"haste", &"lightning_bolt", &"precision", &"wind_wall",
		&"bloodlust", &"fireball", &"curse", &"misfortune", &"armageddon",
		&"bless", &"cure", &"slow", &"weakness", &"town_portal",
		&"shield", &"stoneskin", &"meteor_shower", &"slow_mass", &"resurrection"]

	var errors := 0
	for id in expected:
		if Spells.get_spell(id) == null:
			printerr("Missing spell: %s" % id)
			errors += 1
	return errors



func test_school_distribution() -> void:
	var errors := _check_school_distribution()
	assert_eq(errors, 0, "test_school_distribution — no errors")

func _check_school_distribution() -> int:
	var errors := 0
	for school in [SpellRegistry.School.AIR, SpellRegistry.School.FIRE,
		SpellRegistry.School.WATER, SpellRegistry.School.EARTH]:
		var spells := Spells.get_spells_by_school(school)
		if spells.size() != 5:
			printerr("School %s has %d spells, expected 5" % [Spells.get_school_name(school), spells.size()])
			errors += 1
	return errors



func test_level_range() -> void:
	var errors := _check_level_range()
	assert_eq(errors, 0, "test_level_range — no errors")

func _check_level_range() -> int:
	var errors := 0
	for spell in Spells.get_all_spells():
		if spell.level < 1 or spell.level > 4:
			printerr("Spell %s has invalid level %d" % [spell.id, spell.level])
			errors += 1
	return errors



func test_mana_positive() -> void:
	var errors := _check_mana_positive()
	assert_eq(errors, 0, "test_mana_positive — no errors")

func _check_mana_positive() -> int:
	var errors := 0
	for spell in Spells.get_all_spells():
		if spell.base_mana <= 0:
			printerr("Spell %s has non-positive mana %d" % [spell.id, spell.base_mana])
			errors += 1
	return errors



func test_target_type_valid() -> void:
	var errors := _check_target_type_valid()
	assert_eq(errors, 0, "test_target_type_valid — no errors")

func _check_target_type_valid() -> int:
	var errors := 0
	for spell in Spells.get_all_spells():
		if spell.target_type < 0 or spell.target_type > 5:
			printerr("Spell %s has invalid target_type %d" % [spell.id, spell.target_type])
			errors += 1
	return errors

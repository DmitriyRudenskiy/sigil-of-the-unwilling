extends SceneTree
## Spell registry: all 20 spells load and validate.

func _init() -> void:
	var failed := 0
	failed += _test_spell_count()
	failed += _test_all_spells_exist()
	failed += _test_school_distribution()
	failed += _test_level_range()
	failed += _test_mana_positive()
	failed += _test_target_type_valid()

	if failed == 0:
		print("test_spell_registry: 20/20 passed")
	else:
		printerr("test_spell_registry: %d failed" % failed)
	await process_frame
	quit(1 if failed > 0 else 0)


func _test_spell_count() -> int:
	var all := Spells.get_all_spells()
	if all.size() != 20:
		printerr("Expected 20 spells, got %d" % all.size())
		return 1
	return 0


func _test_all_spells_exist() -> int:
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


func _test_school_distribution() -> int:
	var errors := 0
	for school in [SpellRegistry.School.AIR, SpellRegistry.School.FIRE,
		SpellRegistry.School.WATER, SpellRegistry.School.EARTH]:
		var spells := Spells.get_spells_by_school(school)
		if spells.size() != 5:
			printerr("School %s has %d spells, expected 5" % [Spells.get_school_name(school), spells.size()])
			errors += 1
	return errors


func _test_level_range() -> int:
	var errors := 0
	for spell in Spells.get_all_spells():
		if spell.level < 1 or spell.level > 4:
			printerr("Spell %s has invalid level %d" % [spell.id, spell.level])
			errors += 1
	return errors


func _test_mana_positive() -> int:
	var errors := 0
	for spell in Spells.get_all_spells():
		if spell.base_mana <= 0:
			printerr("Spell %s has non-positive mana %d" % [spell.id, spell.base_mana])
			errors += 1
	return errors


func _test_target_type_valid() -> int:
	var errors := 0
	for spell in Spells.get_all_spells():
		if spell.target_type < 0 or spell.target_type > 5:
			printerr("Spell %s has invalid target_type %d" % [spell.id, spell.target_type])
			errors += 1
	return errors

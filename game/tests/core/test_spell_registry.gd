extends GdUnitTestSuite



func test_spell_count() -> void:
	var all := Spells.get_all_spells()
	assert_int(all.size()).is_equal(20).override_failure_message("Expected 20 spells")



func test_all_spells_exist() -> void:
	var expected := [&"magic_arrow", &"haste", &"lightning_bolt", &"precision", &"wind_wall",
		&"bloodlust", &"fireball", &"curse", &"misfortune", &"armageddon",
		&"bless", &"cure", &"slow", &"weakness", &"town_portal",
		&"shield", &"stoneskin", &"meteor_shower", &"slow_mass", &"resurrection"]

	for id in expected:
		assert_object(Spells.get_spell(id)).is_not_null().override_failure_message("Missing spell: %s" % id)



func test_school_distribution() -> void:
	for school in [SpellRegistry.School.AIR, SpellRegistry.School.FIRE,
		SpellRegistry.School.WATER, SpellRegistry.School.EARTH]:
		var spells := Spells.get_spells_by_school(school)
		assert_int(spells.size()).is_equal(5).override_failure_message("School %s should have 5 spells" % Spells.get_school_name(school))



func test_level_range() -> void:
	for spell in Spells.get_all_spells():
		assert_int(spell.level).is_between(1, 4).override_failure_message("Spell %s has invalid level %d" % [spell.id, spell.level])



func test_mana_positive() -> void:
	for spell in Spells.get_all_spells():
		assert_int(spell.base_mana).is_greater(0).override_failure_message("Spell %s has non-positive mana %d" % [spell.id, spell.base_mana])



func test_target_type_valid() -> void:
	for spell in Spells.get_all_spells():
		assert_int(spell.target_type).is_between(0, 5).override_failure_message("Spell %s has invalid target_type %d" % [spell.id, spell.target_type])

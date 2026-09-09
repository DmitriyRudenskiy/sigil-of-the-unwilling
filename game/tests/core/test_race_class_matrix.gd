extends GdUnitTestSuite

const _Registry = preload("res://scripts/data/RaceClassRegistry.gd")

var registry: Variant = null

func before_test() -> void:
	registry = _Registry.new()

func after_test() -> void:
	registry = null



func test_registry_loads() -> void:
	registry.ensure()
	assert_int(registry.count_races()).is_greater(0)

func test_registry_has_6_races() -> void:
	registry.ensure()
	assert_that(registry.count_races()).is_equal(6)

func test_registry_has_16_classes() -> void:
	registry.ensure()
	assert_that(registry.count_classes()).is_equal(16)

func test_races_are_unique() -> void:
	registry.ensure()
	var ids: Array = []
	for r in registry.all_races():
		assert_bool(not ids.has(r.id)).is_true()
		ids.append(r.id)

func test_classes_are_unique() -> void:
	registry.ensure()
	var ids: Array = []
	for c in registry.all_classes():
		assert_bool(not ids.has(c.id)).is_true()
		ids.append(c.id)



func test_elf_ability_adjustments() -> void:
	registry.ensure()
	var elf: Variant = registry.get_race(&"elf")
	assert_that(elf).is_not_null()
	assert_that(elf.name).is_equal("Elf")
	var aj: Dictionary = elf.ability_adjustments
	assert_that(aj.get(&"DEX", 0)).is_equal(2)
	assert_that(aj.get(&"INT", 0)).is_equal(2)
	assert_that(aj.get(&"CON", 0)).is_equal(-2)

func test_dwarf_ability_adjustments() -> void:
	registry.ensure()
	var d: Variant = registry.get_race(&"dwarf")
	assert_that(d).is_not_null()
	var aj: Dictionary = d.ability_adjustments
	assert_that(aj.get(&"CON", 0)).is_equal(2)
	assert_that(aj.get(&"WIS", 0)).is_equal(2)
	assert_that(aj.get(&"CHA", 0)).is_equal(-2)



func test_alchemist_features() -> void:
	registry.ensure()
	var alch: Variant = registry.get_class_def(&"alchemist")
	assert_that(alch).is_not_null()
	assert_bool(alch.hit_die >= 1).is_true()
	var has_mutagen := false
	for f in alch.features:
		if String(f).to_lower().contains("mutagen"):
			has_mutagen = true
	assert_bool(has_mutagen).is_true()

func test_wizard_is_spellcaster() -> void:
	registry.ensure()
	var wizard: Variant = registry.get_class_def(&"wizard")
	assert_that(wizard).is_not_null()
	assert_bool(wizard.is_spellcaster()).is_true()

func test_fighter_not_spellcaster() -> void:
	registry.ensure()
	var f: Variant = registry.get_class_def(&"fighter")
	assert_that(f).is_not_null()
	assert_bool(f.is_spellcaster()).is_false()

func test_class_has_4_archetypes() -> void:
	registry.ensure()
	var c: Variant = registry.get_class_def(&"barbarian")
	assert_that(c).is_not_null()
	assert_that(c.archetypes.size()).is_equal(4)



func test_pick_race_valid() -> void:
	registry.ensure()
	var rng := TestFactories.seeded(5842)
	rng.seed = 1
	var r: Variant = registry.pick_race(rng)
	assert_that(r).is_not_null()
	assert_bool(registry.all_races().any(func(x): return x.id == r.id)).is_true()

func test_pick_class_valid() -> void:
	registry.ensure()
	var rng := TestFactories.seeded(5842)
	rng.seed = 2
	var c: Variant = registry.pick_class(rng)
	assert_that(c).is_not_null()
	assert_bool(registry.all_classes().any(func(x): return x.id == c.id)).is_true()

func test_pick_archetype_valid() -> void:
	registry.ensure()
	var rng := TestFactories.seeded(5842)
	rng.seed = 3
	var c: Variant = registry.get_class_def(&"wizard")
	var arch: Variant = registry.pick_archetype(c, rng)
	assert_that(arch).is_not_null()
	assert_bool(arch.has("id")).is_true()



func test_subsystems_loaded() -> void:
	registry.ensure()
	assert_int(registry.get_bloodline(&"infernal").size()).is_greater(0)
	assert_int(registry.get_domain(&"war").size()).is_greater(0)
	assert_int(registry.get_feat(&"power_attack").size()).is_greater(0)

func test_reset_restores_state() -> void:
	registry.ensure()
	var before: int = registry.count_races()
	registry.reset()
	assert_that(registry.count_races()).is_equal(0)
	registry.ensure()
	assert_that(registry.count_races()).is_equal(before)

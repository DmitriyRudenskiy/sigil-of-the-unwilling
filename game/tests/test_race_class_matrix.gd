extends "res://tests/gut_base.gd"
## Тесты матрицы рас-классов: загрузка данных, доступ, взвешенный выбор.

const _Registry = preload("res://scripts/data/RaceClassRegistry.gd")

var registry: Variant = null

func before_each() -> void:
	registry = _Registry.new()

func after_each() -> void:
	## RaceClassRegistry — RefCounted; .free() на нём вызывает ошибку.
	registry = null


# ==================== ЗАГРУЗКА ДАННЫХ ====================

func test_registry_loads() -> void:
	registry.ensure()
	assert_gt(registry.count_races(), 0, "расы загружены")

func test_registry_has_6_races() -> void:
	registry.ensure()
	assert_eq(registry.count_races(), 6, "6 рас: aasimar, dwarf, elf, gnome, halfling, human")

func test_registry_has_16_classes() -> void:
	registry.ensure()
	assert_eq(registry.count_classes(), 16, "16 классов")

func test_races_are_unique() -> void:
	registry.ensure()
	var ids: Array = []
	for r in registry.all_races():
		assert_true(not ids.has(r.id), "race id unique: %s" % r.id)
		ids.append(r.id)

func test_classes_are_unique() -> void:
	registry.ensure()
	var ids: Array = []
	for c in registry.all_classes():
		assert_true(not ids.has(c.id), "class id unique: %s" % c.id)
		ids.append(c.id)


# ==================== СПЕЦИФИКАЦИЯ РАСЫ ====================

func test_elf_ability_adjustments() -> void:
	registry.ensure()
	var elf: Variant = registry.get_race(&"elf")
	assert_not_null(elf, "elf found")
	assert_eq(elf.name, "Elf", "elf name")
	var aj: Dictionary = elf.ability_adjustments
	assert_eq(aj.get(&"DEX", 0), 2, "elf +2 DEX")
	assert_eq(aj.get(&"INT", 0), 2, "elf +2 INT")
	assert_eq(aj.get(&"CON", 0), -2, "elf -2 CON")

func test_dwarf_ability_adjustments() -> void:
	registry.ensure()
	var d: Variant = registry.get_race(&"dwarf")
	assert_not_null(d, "dwarf found")
	var aj: Dictionary = d.ability_adjustments
	assert_eq(aj.get(&"CON", 0), 2, "dwarf +2 CON")
	assert_eq(aj.get(&"WIS", 0), 2, "dwarf +2 WIS")
	assert_eq(aj.get(&"CHA", 0), -2, "dwarf -2 CHA")


# ==================== СПЕЦИФИКАЦИЯ КЛАССА ====================

func test_alchemist_features() -> void:
	registry.ensure()
	var alch: Variant = registry.get_class_def(&"alchemist")
	assert_not_null(alch, "alchemist found")
	assert_true(alch.hit_die >= 1, "alchemist hit_die >= 1")
	var has_mutagen := false
	for f in alch.features:
		if String(f).to_lower().contains("mutagen"):
			has_mutagen = true
	assert_true(has_mutagen, "alchemist features include Mutagen")

func test_wizard_is_spellcaster() -> void:
	registry.ensure()
	var wizard: Variant = registry.get_class_def(&"wizard")
	assert_not_null(wizard, "wizard found")
	assert_true(wizard.is_spellcaster(), "wizard is spellcaster")

func test_fighter_not_spellcaster() -> void:
	registry.ensure()
	var f: Variant = registry.get_class_def(&"fighter")
	assert_not_null(f, "fighter found")
	assert_false(f.is_spellcaster(), "fighter not spellcaster")

func test_class_has_4_archetypes() -> void:
	registry.ensure()
	var c: Variant = registry.get_class_def(&"barbarian")
	assert_not_null(c, "barbarian found")
	assert_eq(c.archetypes.size(), 4, "barbarian has 4 archetypes")


# ==================== ВЗВЕШЕННЫЙ ВЫБОР ====================

func test_pick_race_valid() -> void:
	registry.ensure()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var r: Variant = registry.pick_race(rng)
	assert_not_null(r, "pick_race returned a race")
	assert_true(registry.all_races().any(func(x): return x.id == r.id), "picked valid race: %s" % r.id)

func test_pick_class_valid() -> void:
	registry.ensure()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var c: Variant = registry.pick_class(rng)
	assert_not_null(c, "pick_class returned a class")
	assert_true(registry.all_classes().any(func(x): return x.id == c.id), "picked valid class: %s" % c.id)

func test_pick_archetype_valid() -> void:
	registry.ensure()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var c: Variant = registry.get_class_def(&"wizard")
	var arch: Variant = registry.pick_archetype(c, rng)
	assert_not_null(arch, "pick_archetype returned an archetype")
	assert_true(arch.has("id"), "archetype has id")


# ==================== ПОДСИСТЕМЫ (ДАННЫЕ) ====================

func test_subsystems_loaded() -> void:
	registry.ensure()
	assert_gt(registry.get_bloodline(&"infernal").size(), 0, "infernal bloodline present")
	assert_gt(registry.get_domain(&"war").size(), 0, "war domain present")
	assert_gt(registry.get_feat(&"power_attack").size(), 0, "power attack feat present")

func test_reset_restores_state() -> void:
	registry.ensure()
	var before: int = registry.count_races()
	registry.reset()
	assert_eq(registry.count_races(), 0, "reset clears races")
	registry.ensure()
	assert_eq(registry.count_races(), before, "ensure reloads after reset")

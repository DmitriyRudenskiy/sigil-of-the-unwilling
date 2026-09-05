extends "res://tests/gut_base.gd"

func before_each() -> void:
	Artifacts.reset()

# ======== Artifact resource tests ========
func test_artifact_rarity_values() -> void:
	assert_eq(Artifact.Rarity.MINOR, 0)
	assert_eq(Artifact.Rarity.MAJOR, 1)
	assert_eq(Artifact.Rarity.RELIC, 2)

func test_artifact_slot_count() -> void:
	assert_true(Artifact.Slot.values().size() >= 11)

func test_artifact_stats() -> void:
	var a := Artifact.new()
	a.display_name = "Test"
	a.id = &"test_item"
	a.slot = Artifact.Slot.WEAPON
	a.rarity = Artifact.Rarity.MINOR
	a.modifiers = {"attack": 10, "defense": 5, "spell_power": 3}
	assert_eq(a.get_attack(), 10)
	assert_eq(a.get_defense(), 5)
	assert_eq(a.get_spell_power(), 3)
	assert_eq(a.get_knowledge(), 0)

func test_artifact_stack_modifiers() -> void:
	var a := Artifact.new()
	a.display_name = "Test"
	a.id = &"test_item"
	a.slot = Artifact.Slot.TORSO
	a.rarity = Artifact.Rarity.MAJOR
	a.modifiers = {"stack_hp": 15, "stack_hp_percent": 0.2, "stack_speed": 2}
	assert_eq(a.get_stack_hp_bonus(), 15)
	assert_eq(a.get_stack_hp_percent(), 0.2)
	assert_eq(a.get_stack_speed_bonus(), 2)

func test_artifact_is_ring() -> void:
	var a := Artifact.new()
	a.slot = Artifact.Slot.RING_L
	assert_true(a.is_ring())
	a.slot = Artifact.Slot.RING_R
	assert_true(a.is_ring())
	a.slot = Artifact.Slot.WEAPON
	assert_false(a.is_ring())

func test_artifact_is_two_handed() -> void:
	var a := Artifact.new()
	a.is_two_handed = true
	assert_true(a.is_two_handed)
	a.is_two_handed = false
	assert_false(a.is_two_handed)

# ======== ArtifactRegistry tests ========
func test_registry_has_54() -> void:
	# bfcf05f: +24 артефакта (6 типов x 3 класса + 6 аксессуаров).
	assert_eq(Artifacts.get_all().size(), 54)

func test_registry_rarity_distribution() -> void:
	assert_eq(Artifacts.get_by_rarity(Artifact.Rarity.MINOR).size(), 10)
	assert_eq(Artifacts.get_by_rarity(Artifact.Rarity.MAJOR).size(), 10)
	assert_eq(Artifacts.get_by_rarity(Artifact.Rarity.RELIC).size(), 34)

func test_registry_unique_ids() -> void:
	var seen: Dictionary = {}
	for art in Artifacts.get_all():
		assert_false(seen.has(art.id), "Duplicate artifact id: %s" % art.id)
		seen[art.id] = true

func test_registry_random_returns_valid() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 100:
		var art = Artifacts.random_of_rarity(Artifact.Rarity.MINOR, rng)
		assert_true(art != null)
		assert_eq(art.rarity, Artifact.Rarity.MINOR)

func test_registry_get_by_id() -> void:
	var arts := Artifacts.get_all()
	if arts.size() > 0:
		var found := Artifacts.get_by_id(arts[0].id)
		assert_true(found != null)
		assert_eq(found.id, arts[0].id)

# ======== HeroInventory tests ========
func test_inventory_init_empty() -> void:
	var inv := HeroInventory.new()
	assert_true(inv.equipped.size() >= 10)
	assert_eq(inv.backpack.size(), 0)

func test_inventory_equip_unequip() -> void:
	var inv := HeroInventory.new()
	var art := Artifact.new()
	art.id = &"inv_test"
	art.display_name = "Test"
	art.slot = Artifact.Slot.WEAPON
	art.rarity = Artifact.Rarity.MINOR
	inv.equip(art)
	assert_true(inv.has_slot(Artifact.Slot.WEAPON))
	assert_eq(inv.get_equipped(Artifact.Slot.WEAPON).id, &"inv_test")
	var returned := inv.unequip(Artifact.Slot.WEAPON)
	assert_eq(returned.id, &"inv_test")
	assert_false(inv.has_slot(Artifact.Slot.WEAPON))

func test_inventory_backpack_limit() -> void:
	var inv := HeroInventory.new()
	assert_eq(inv.MAX_BACKPACK, MapConfig.MAX_BACKPACK_SIZE)

func test_inventory_add_remove_backpack() -> void:
	var inv := HeroInventory.new()
	var art := Artifact.new()
	art.id = &"bp_test"
	art.display_name = "BP Test"
	art.slot = Artifact.Slot.WEAPON
	art.rarity = Artifact.Rarity.MINOR
	assert_true(inv.add_to_backpack(art))
	assert_eq(inv.backpack.size(), 1)
	var removed := inv.remove_from_backpack(0)
	assert_eq(removed.id, &"bp_test")
	assert_eq(inv.backpack.size(), 0)

func test_inventory_serialization() -> void:
	var inv := HeroInventory.new()
	var art := Artifacts.get_all()[0]
	inv.equip(art)
	var data := inv.serialize()
	assert_true(data.has("equipped"))
	assert_true(data.has("backpack"))
	var inv2 := HeroInventory.new()
	inv2.deserialize(data)
	var eq := inv2.get_equipped(art.slot)
	assert_true(eq != null)
	assert_eq(eq.id, art.id)

func test_inventory_total_modifiers() -> void:
	var inv := HeroInventory.new()
	var mods := inv.get_total_modifiers()
	assert_true(mods.has("attack"))
	assert_true(mods.has("stack_hp"))
	assert_eq(mods["attack"], 0)

func test_inventory_two_handed_excludes_shield() -> void:
	var inv := HeroInventory.new()
	var weapon := Artifact.new()
	weapon.id = &"th_weapon"
	weapon.display_name = "TH"
	weapon.slot = Artifact.Slot.WEAPON
	weapon.rarity = Artifact.Rarity.MINOR
	weapon.is_two_handed = true
	var shield := Artifact.new()
	shield.id = &"test_shield"
	shield.display_name = "SH"
	shield.slot = Artifact.Slot.SHIELD
	shield.rarity = Artifact.Rarity.MINOR
	inv.equip(shield)
	inv.equip(weapon)
	assert_true(inv.has_slot(Artifact.Slot.WEAPON))
	assert_false(inv.has_slot(Artifact.Slot.SHIELD))

func test_inventory_sell_artifact() -> void:
	var inv := HeroInventory.new()
	var art := Artifact.new()
	art.id = &"sell_test"
	art.display_name = "Sell"
	art.slot = Artifact.Slot.WEAPON
	art.rarity = Artifact.Rarity.MINOR
	art.value_gold = 200
	inv.add_to_backpack(art)
	var gold := inv.sell_artifact(0)
	assert_eq(gold, 100)

func test_inventory_no_duplicates() -> void:
	var inv := HeroInventory.new()
	var art1 := Artifact.new()
	art1.id = &"dup_test"
	art1.display_name = "Dup"
	art1.slot = Artifact.Slot.WEAPON
	art1.rarity = Artifact.Rarity.MINOR
	var art2 := Artifact.new()
	art2.id = &"dup_test"
	art2.display_name = "Dup"
	art2.slot = Artifact.Slot.WEAPON
	art2.rarity = Artifact.Rarity.MINOR
	assert_true(inv.add_to_backpack(art1))
	assert_false(inv.add_to_backpack(art2))

func test_inventory_special_effects() -> void:
	var inv := HeroInventory.new()
	assert_false(inv.has_special_effect(&"morale_aura"))
	var art := Artifact.new()
	art.id = &"aura_test"
	art.display_name = "Aura"
	art.slot = Artifact.Slot.NECK
	art.rarity = Artifact.Rarity.MAJOR
	art.special_effect = &"morale_aura"
	inv.equip(art)
	assert_true(inv.has_special_effect(&"morale_aura"))

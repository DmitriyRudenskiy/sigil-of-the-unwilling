extends GdUnitTestSuite

func before_test() -> void:
	Artifacts.reset()

func test_artifact_rarity_values() -> void:
	assert_that(Artifact.Rarity.MINOR).is_equal(0)
	assert_that(Artifact.Rarity.MAJOR).is_equal(1)
	assert_that(Artifact.Rarity.RELIC).is_equal(2)

func test_artifact_slot_count() -> void:
	assert_bool(Artifact.Slot.values().size() >= 11).is_true()

func test_artifact_stats() -> void:
	var a := Artifact.new()
	a.display_name = "Test"
	a.id = &"test_item"
	a.slot = Artifact.Slot.WEAPON
	a.rarity = Artifact.Rarity.MINOR
	a.modifiers = {"attack": 10, "defense": 5, "spell_power": 3}
	assert_that(a.get_attack()).is_equal(10)
	assert_that(a.get_defense()).is_equal(5)
	assert_that(a.get_spell_power()).is_equal(3)
	assert_that(a.get_knowledge()).is_equal(0)

func test_artifact_stack_modifiers() -> void:
	var a := Artifact.new()
	a.display_name = "Test"
	a.id = &"test_item"
	a.slot = Artifact.Slot.TORSO
	a.rarity = Artifact.Rarity.MAJOR
	a.modifiers = {"stack_hp": 15, "stack_hp_percent": 0.2, "stack_speed": 2}
	assert_that(a.get_stack_hp_bonus()).is_equal(15)
	assert_that(a.get_stack_hp_percent()).is_equal(0.2)
	assert_that(a.get_stack_speed_bonus()).is_equal(2)

func test_artifact_is_ring() -> void:
	var a := Artifact.new()
	a.slot = Artifact.Slot.RING_L
	assert_bool(a.is_ring()).is_true()
	a.slot = Artifact.Slot.RING_R
	assert_bool(a.is_ring()).is_true()
	a.slot = Artifact.Slot.WEAPON
	assert_bool(a.is_ring()).is_false()

func test_artifact_is_two_handed() -> void:
	var a := Artifact.new()
	a.is_two_handed = true
	assert_bool(a.is_two_handed).is_true()
	a.is_two_handed = false
	assert_bool(a.is_two_handed).is_false()

func test_registry_has_54() -> void:
	assert_that(Artifacts.get_all().size()).is_equal(54)

func test_registry_rarity_distribution() -> void:
	assert_that(Artifacts.get_by_rarity(Artifact.Rarity.MINOR).size()).is_equal(10)
	assert_that(Artifacts.get_by_rarity(Artifact.Rarity.MAJOR).size()).is_equal(10)
	assert_that(Artifacts.get_by_rarity(Artifact.Rarity.RELIC).size()).is_equal(34)

func test_registry_unique_ids() -> void:
	var seen: Dictionary = {}
	for art in Artifacts.get_all():
		assert_bool(seen.has(art.id)).is_false()
		seen[art.id] = true

func test_registry_random_returns_valid() -> void:
	var rng := TestFactories.seeded(5351)
	rng.seed = 42
	for i in 100:
		var art = Artifacts.random_of_rarity(Artifact.Rarity.MINOR, rng)
		assert_bool(art != null).is_true()
		assert_that(art.rarity).is_equal(Artifact.Rarity.MINOR)

func test_registry_get_by_id() -> void:
	var arts := Artifacts.get_all()
	if arts.size() > 0:
		var found := Artifacts.get_by_id(arts[0].id)
		assert_bool(found != null).is_true()
		assert_that(found.id).is_equal(arts[0].id)

func test_inventory_init_empty() -> void:
	var inv := HeroInventory.new()
	assert_bool(inv.equipped.size() >= 10).is_true()
	assert_that(inv.backpack.size()).is_equal(0)

func test_inventory_equip_unequip() -> void:
	var inv := HeroInventory.new()
	var art := Artifact.new()
	art.id = &"inv_test"
	art.display_name = "Test"
	art.slot = Artifact.Slot.WEAPON
	art.rarity = Artifact.Rarity.MINOR
	inv.equip(art)
	assert_bool(inv.has_slot(Artifact.Slot.WEAPON)).is_true()
	assert_that(inv.get_equipped(Artifact.Slot.WEAPON).id).is_equal(&"inv_test")
	var returned := inv.unequip(Artifact.Slot.WEAPON)
	assert_that(returned.id).is_equal(&"inv_test")
	assert_bool(inv.has_slot(Artifact.Slot.WEAPON)).is_false()

func test_inventory_backpack_limit() -> void:
	var inv := HeroInventory.new()
	assert_that(inv.MAX_BACKPACK).is_equal(GameNumbers.MAX_BACKPACK_SIZE)

func test_inventory_add_remove_backpack() -> void:
	var inv := HeroInventory.new()
	var art := Artifact.new()
	art.id = &"bp_test"
	art.display_name = "BP Test"
	art.slot = Artifact.Slot.WEAPON
	art.rarity = Artifact.Rarity.MINOR
	assert_bool(inv.add_to_backpack(art)).is_true()
	assert_that(inv.backpack.size()).is_equal(1)
	var removed := inv.remove_from_backpack(0)
	assert_that(removed.id).is_equal(&"bp_test")
	assert_that(inv.backpack.size()).is_equal(0)

func test_inventory_serialization() -> void:
	var inv := HeroInventory.new()
	var art := Artifacts.get_all()[0]
	inv.equip(art)
	var data := inv.serialize()
	assert_bool(data.has("equipped")).is_true()
	assert_bool(data.has("backpack")).is_true()
	var inv2 := HeroInventory.new()
	inv2.deserialize(data)
	var eq := inv2.get_equipped(art.slot)
	assert_bool(eq != null).is_true()
	assert_that(eq.id).is_equal(art.id)

func test_inventory_total_modifiers() -> void:
	var inv := HeroInventory.new()
	var mods := inv.get_total_modifiers()
	assert_bool(mods.has("attack")).is_true()
	assert_bool(mods.has("stack_hp")).is_true()
	assert_that(mods["attack"]).is_equal(0)

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
	assert_bool(inv.has_slot(Artifact.Slot.WEAPON)).is_true()
	assert_bool(inv.has_slot(Artifact.Slot.SHIELD)).is_false()

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
	assert_that(gold).is_equal(100)

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
	assert_bool(inv.add_to_backpack(art1)).is_true()
	assert_bool(inv.add_to_backpack(art2)).is_false()

func test_inventory_special_effects() -> void:
	var inv := HeroInventory.new()
	assert_bool(inv.has_special_effect(&"morale_aura")).is_false()
	var art := Artifact.new()
	art.id = &"aura_test"
	art.display_name = "Aura"
	art.slot = Artifact.Slot.NECK
	art.rarity = Artifact.Rarity.MAJOR
	art.special_effect = &"morale_aura"
	inv.equip(art)
	assert_bool(inv.has_special_effect(&"morale_aura")).is_true()

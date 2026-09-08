extends GdUnitTestSuite

var _mgr: EquipmentManager


func before_test() -> void:
	_mgr = EquipmentManager.new()


func _armor(slot: Artifact.Slot, base_ac: int, max_dex: int = 100) -> Artifact:
	var a := Artifact.new()
	a.slot = slot
	a.armor = {"base_ac": base_ac, "max_dex_bonus": max_dex}
	a.ac_bonus_type = Artifact.AcBonusType.ARMOR
	return a


func test_compute_ac_base_with_dex() -> void:
	var armor := _armor(Artifact.Slot.TORSO, 6, 100)
	var result := _mgr.compute_ac({Artifact.Slot.TORSO: armor}, 2)
	assert_int(result["total"]).is_equal(18)
	assert_int(result["armor"]).is_equal(6)
	assert_int(result["effective_dex"]).is_equal(2)
	assert_bool(result["armored"]).is_true()


func test_compute_ac_empty_equipment() -> void:
	var result := _mgr.compute_ac({}, 0)
	assert_int(result["total"]).is_equal(10)
	assert_bool(result["armored"]).is_false()


func test_compute_ac_heavy_armor_caps_dex() -> void:
	var heavy := _armor(Artifact.Slot.TORSO, 8, 2)
	var result := _mgr.compute_ac({Artifact.Slot.TORSO: heavy}, 5)
	assert_int(result["effective_dex"]).is_equal(2)
	assert_int(result["total"]).is_equal(10 + 2 + 8)


func test_compute_ac_shield_adds_ac() -> void:
	var shield := Artifact.new()
	shield.slot = Artifact.Slot.SHIELD
	shield.armor = {"base_ac": 2}
	shield.ac_bonus_type = Artifact.AcBonusType.SHIELD
	var result := _mgr.compute_ac({Artifact.Slot.SHIELD: shield}, 0)
	assert_int(result["shield"]).is_equal(2)
	assert_int(result["total"]).is_equal(12)


func test_compute_ac_deflection_takes_best_ring() -> void:
	var ring_l := Artifact.new()
	ring_l.slot = Artifact.Slot.RING_L
	ring_l.ac_bonus_type = Artifact.AcBonusType.DEFLECTION
	ring_l.armor = {"base_ac": 1}
	var ring_r := Artifact.new()
	ring_r.slot = Artifact.Slot.RING_R
	ring_r.ac_bonus_type = Artifact.AcBonusType.DEFLECTION
	ring_r.armor = {"base_ac": 3}
	var result := _mgr.compute_ac({Artifact.Slot.RING_L: ring_l, Artifact.Slot.RING_R: ring_r}, 0)
	assert_int(result["deflection"]).is_equal(3)


func test_compute_ac_dodge_is_summed() -> void:
	var dodge_a := Artifact.new()
	dodge_a.slot = Artifact.Slot.RING_L
	dodge_a.ac_bonus_type = Artifact.AcBonusType.DODGE
	dodge_a.armor = {"base_ac": 1}
	var dodge_b := Artifact.new()
	dodge_b.slot = Artifact.Slot.RING_R
	dodge_b.ac_bonus_type = Artifact.AcBonusType.DODGE
	dodge_b.armor = {"base_ac": 2}
	var result := _mgr.compute_ac({Artifact.Slot.RING_L: dodge_a, Artifact.Slot.RING_R: dodge_b}, 0)
	assert_int(result["dodge"]).is_equal(3)


func test_evaluate_attack_no_weapon() -> void:
	var r := _mgr.evaluate_attack({}, [])
	assert_object(r["weapon"]).is_null()
	assert_int(r["attack"]).is_zero()


func test_evaluate_attack_unproficient_penalty() -> void:
	var weapon := Artifact.new()
	weapon.slot = Artifact.Slot.WEAPON
	weapon.modifiers = {"attack": 5}
	weapon.combat = {"proficiency": [&"martial"]}
	var r := _mgr.evaluate_attack({Artifact.Slot.WEAPON: weapon}, [])
	assert_bool(r["proficient"]).is_false()
	assert_int(r["attack"]).is_equal(5 + EquipmentManager.NON_PROFICIENCY_PENALTY + 0)
	var r2 := _mgr.evaluate_attack({Artifact.Slot.WEAPON: weapon}, [&"martial"], 3)
	assert_bool(r2["proficient"]).is_true()
	assert_int(r2["attack"]).is_equal(5 + 3)


func test_apply_damage_immunity() -> void:
	var r := _mgr.apply_damage(10, Artifact.DamageType.SLASHING, {"immunities": ["Рубящий"]})
	assert_int(r["final"]).is_zero()
	assert_str(r["reason"]).is_equal("immunity")


func test_apply_damage_reduction_and_bypass() -> void:
	var r := _mgr.apply_damage(10, Artifact.DamageType.SLASHING, {"reductions": {"Рубящий": 4}})
	assert_int(r["final"]).is_equal(6)
	var bypass := _mgr.apply_damage(10, Artifact.DamageType.SLASHING, {
		"reductions": {"Рубящий": 4},
		"is_magic": true,
	})
	assert_int(bypass["final"]).is_equal(10)
	assert_str(bypass["reason"]).is_equal("bypassed")

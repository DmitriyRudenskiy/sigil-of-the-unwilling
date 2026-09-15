extends BaseTest


## attribute-weight-system: LoadCalculator — вес/переноска/перегруз.


func test_carry_cap_scales_with_defense() -> void:
	var cap_low: float = LoadCalculator.carry_cap(2.0)
	var cap_high: float = LoadCalculator.carry_cap(8.0)
	assert_that(cap_low).is_equal(GameNumbersHero.WEIGHT_BASE_CAP + 2.0 * GameNumbersHero.WEIGHT_PER_DEFENSE)
	assert_that(cap_high).is_equal(GameNumbersHero.WEIGHT_BASE_CAP + 8.0 * GameNumbersHero.WEIGHT_PER_DEFENSE)
	assert_bool(cap_high > cap_low).is_true()


func test_overload_fraction_zero_when_under_cap() -> void:
	var inv := _make_inventory(5.0)
	assert_that(LoadCalculator.overload_fraction(inv, 2)).is_equal(0.0)


func test_overload_fraction_positive_when_over_cap() -> void:
	var inv := _make_inventory(26.0)
	var frac: float = LoadCalculator.overload_fraction(inv, 2)
	assert_bool(frac > 0.0).is_true()
	assert_that(frac).is_equal_approx(8.0 / 18.0, 0.01)


func test_overload_mp_penalty_capped() -> void:
	# fraction > 1 → penalty capped at MAX
	var penalty: float = LoadCalculator.overload_mp_penalty(10.0)
	assert_that(penalty).is_equal_approx(GameNumbersHero.OVERLOAD_MP_PENALTY_MAX, 0.001)
	# fraction = 0 → penalty = 0
	assert_that(LoadCalculator.overload_mp_penalty(0.0)).is_equal(0.0)


func test_overload_rest_penalty_zero_when_under() -> void:
	assert_that(LoadCalculator.overload_rest_penalty(0.0)).is_equal(0.0)


func test_overload_rest_penalty_positive() -> void:
	assert_bool(LoadCalculator.overload_rest_penalty(0.5) > 0.0).is_true()


func test_resources_weight_empty() -> void:
	var reg := _make_registry()
	assert_that(LoadCalculator.resources_weight({}, reg)).is_equal(0.0)


func test_resources_weight_with_items() -> void:
	var reg := _make_registry()
	var res := {&"coal": 5, &"wood": 3}  # coal 1.0, wood 0.0
	assert_that(LoadCalculator.resources_weight(res, reg)).is_equal_approx(5.0, 0.01)


func test_fit_units_limited_by_weight() -> void:
	var reg := _make_registry()
	var def: ResourceDef = reg.get_resource(&"coal")  # 1.0
	assert_that(LoadCalculator.fit_units(def, 8.0, 10.0)).is_equal(2)
	assert_that(LoadCalculator.fit_units(def, 12.0, 10.0)).is_equal(0)


func test_fit_units_zero_weight_resource() -> void:
	var reg := _make_registry()
	var def: ResourceDef = reg.get_resource(&"wood")  # 0.0
	assert_that(LoadCalculator.fit_units(def, 0.0, 10.0)).is_equal(0)


func _make_inventory(weight: float) -> HeroInventory:
	var inv := HeroInventory.new()
	var art := Artifact.new(&"test_armor", "Heavy Plate", Artifact.Slot.TORSO,
		Artifact.Rarity.MAJOR, {}, &"", false, 100, "test", weight)
	inv.backpack.append(art)
	return inv


func _make_registry() -> Node:
	var reg := _MiniRegistry.new()
	reg.add_def(&"coal", "Coal", 1.0)
	reg.add_def(&"wood", "Wood", 0.0)
	return reg


class _MiniRegistry:
	extends Node
	var _defs: Array = []

	func add_def(id: StringName, name: String, weight: float) -> void:
		var d := ResourceDef.new()
		d.id = id
		d.display_name = name
		d.weight_per_unit = weight
		_defs.append(d)

	func get_resource(id: StringName) -> ResourceDef:
		for d in _defs:
			if d.id == id:
				return d
		return null

	func get_all() -> Array:
		return _defs

extends BaseTest

## Сетка снаряжения вместо списка из 16 ячеек (grid-inventory-and-merchant,
## группа 2). Вместимость — клетки: 6×4 = 24. Отказ не меняет ни сетку,
## ни список, ни причину «на словах»: текст обязан содержать числа.

const GRID := GameNumbers.INVENTORY_GRID


func _item(p_id: String, p_slot: Artifact.Slot, p_cells: Vector2i) -> Artifact:
	var art := Artifact.new(StringName(p_id), p_id, p_slot)
	art.cells = p_cells
	return art


func _ring(p_id: String) -> Artifact:
	return _item(p_id, Artifact.Slot.RING_L, Vector2i(1, 1))


func test_spear_needs_rotation_to_lie_down() -> void:
	var inv := HeroInventory.new()
	var spear := _item("spear", Artifact.Slot.WEAPON, Vector2i(1, 6))
	assert_bool(inv.add_to_backpack(spear)).is_true()
	# 1×6 в сетку 6×4 вертикально не встаёт — только поворот.
	assert_bool(inv.rotated[0]).is_true()
	assert_that(inv.occupied_cells().size()).is_equal(6)
	assert_that(inv.free_cell_count()).is_equal(GRID.x * GRID.y - 6)


func test_horizontal_spear_lies_without_rotation() -> void:
	var inv := HeroInventory.new()
	assert_bool(inv.add_to_backpack(_item("spear", Artifact.Slot.WEAPON, Vector2i(6, 1)))).is_true()
	assert_bool(inv.rotated[0]).is_false()
	assert_that(inv.placements[0]).is_equal(Vector2i.ZERO)


func test_overlap_is_refused_and_changes_nothing() -> void:
	var inv := HeroInventory.new()
	inv.add_to_backpack(_item("spear", Artifact.Slot.WEAPON, Vector2i(6, 1)))
	var before := inv.occupied_cells().size()
	var err := inv.can_place(Vector2i(2, 3), Vector2i(1, 0), false)
	assert_str(err).contains("занята")
	assert_that(inv.occupied_cells().size()).is_equal(before)
	assert_that(inv.backpack.size()).is_equal(1)


func test_out_of_grid_is_refused_with_grid_size() -> void:
	var inv := HeroInventory.new()
	# За поле — правый край решётки; номер в тексте тоже из носителя,
	# литерал «6×4» пережил бы смену INVENTORY_GRID молча (D-280).
	var err := inv.can_place(Vector2i(2, 1), Vector2i(GRID.x - 1, 0), false)
	assert_str(err).contains("%d×%d" % [GRID.x, GRID.y])


## «Не хватает одной клетки» — текст с фактическими числами.
func test_one_cell_short_reports_both_numbers() -> void:
	var inv := HeroInventory.new()
	# 19 колец занимают 19 клеток: в ряду остаётся 5 свободных, копью нужно 6.
	for i in 19:
		assert_bool(inv.add_to_backpack(_ring("ring_%d" % i))).is_true()
	assert_that(inv.free_cell_count()).is_equal(5)
	var added := inv.add_to_backpack(_item("spear", Artifact.Slot.WEAPON, Vector2i(1, 6)))
	assert_bool(added).is_false()
	assert_str(inv.last_placement_error).contains("6")
	assert_str(inv.last_placement_error).contains("5")
	assert_that(inv.backpack.size()).is_equal(19)


## Надел копьё — шесть клеток снова свободны.
func test_equipping_frees_the_footprint() -> void:
	var inv := HeroInventory.new()
	var spear := _item("spear", Artifact.Slot.WEAPON, Vector2i(6, 1))
	inv.add_to_backpack(spear)
	assert_that(inv.free_cell_count()).is_equal(18)
	assert_bool(inv.equip(spear)).is_true()
	assert_that(inv.backpack.size()).is_equal(0)
	assert_that(inv.free_cell_count()).is_equal(24)


## Снял вещь — она занимает клетки; если клеток нет, снятие отказывает целиком.
func test_unequip_needs_room() -> void:
	var inv := HeroInventory.new()
	var armor := _item("armor", Artifact.Slot.TORSO, Vector2i(2, 3))
	assert_bool(inv.equip(armor)).is_true()
	for i in 24 - 6 + 1:
		inv.add_to_backpack(_ring("ring_%d" % i))
	assert_that(inv.free_cell_count()).is_less(6)
	assert_object(inv.unequip(Artifact.Slot.TORSO)).is_null()
	assert_that(inv.free_cell_count()).is_less(6)
	assert_object(inv.get_equipped(Artifact.Slot.TORSO)).is_not_null()


## Инвариант после любой операции: ни одной двойной клетки, у каждого предмета
## есть прямоугольник (или сознательный «перевес»).
func test_invariant_holds_after_every_operation() -> void:
	var inv := HeroInventory.new()
	var items := [
		_item("spear", Artifact.Slot.WEAPON, Vector2i(6, 1)),
		_item("bow", Artifact.Slot.WEAPON, Vector2i(2, 3)),
		_item("amulet", Artifact.Slot.NECK, Vector2i(1, 2)),
		_ring("ring"),
	]
	for art in items:
		inv.add_to_backpack(art)
	inv.equip(items[3])
	inv.unequip(Artifact.Slot.RING_L)
	inv.remove_from_backpack(0)
	inv.sell_artifact(0)
	_check_invariant(inv)


## Граница с весами: клетки сетки — не вес. Доступный вес ресурсов от того,
## стоит ли копьё в сетке, не меняется.
func test_footprint_does_not_touch_resource_carry() -> void:
	var inv := HeroInventory.new()
	var defense := 7.0
	var cap := LoadCalculator.carry_cap(defense)
	var def := ResourceDef.new()
	def.id = &"stone"
	def.weight_per_unit = 2.0
	var before := LoadCalculator.fit_units(def, 0.0, cap)
	var spear := _item("spear", Artifact.Slot.WEAPON, Vector2i(6, 1))
	spear.weight = 3.0
	inv.add_to_backpack(spear)
	assert_that(LoadCalculator.carry_cap(defense)).is_equal(cap)
	assert_that(LoadCalculator.fit_units(def, 0.0, LoadCalculator.carry_cap(defense))).is_equal(before)
	# Вес снаряжения — отдельная шкала, она копью действительно растёт.
	assert_that(LoadCalculator.equipment_weight(inv)).is_equal(3.0)


func _check_invariant(inv: HeroInventory) -> void:
	assert_that(inv.placements.size()).is_equal(inv.backpack.size())
	assert_that(inv.rotated.size()).is_equal(inv.backpack.size())
	var seen := {}
	for i in inv.backpack.size():
		var origin: Vector2i = inv.placements[i]
		if origin == HeroInventory.NO_CELL:
			continue
		var rect: Array[Vector2i] = HeroInventory.rect(
			inv.backpack[i].resolved_cells(), origin, inv.rotated[i]
		)
		assert_bool(rect.size() > 0).is_true()
		for cell in rect:
			assert_bool(cell.x >= 0 and cell.y >= 0).is_true()
			assert_bool(cell.x < GRID.x and cell.y < GRID.y).is_true()
			assert_bool(seen.has(cell)).is_false()
			seen[cell] = i

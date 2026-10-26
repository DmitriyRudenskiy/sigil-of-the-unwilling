extends BaseTest

## Габарит предмета в сетке снаряжения (grid-inventory-and-merchant, группа 1).
##
## Габарит — поле данных: у слота есть значение по умолчанию, но одно оно не
## различает копьё 1×6 и лук 2×3, которые живут в одном слоте WEAPON. Поэтому
## предмет, у которого габарит не задан и не выводится из слота, — ошибка
## данных, а не молчаливый ноль (тот же приём, что проверка спрайт-дорожек).

const GRID_W := 6
const GRID_H := 4


func test_explicit_footprint_wins_over_slot_default() -> void:
	var spear := Artifact.new(&"spear_x", "Spear", Artifact.Slot.WEAPON)
	spear.cells = Vector2i(1, 6)
	assert_that(spear.resolved_cells()).is_equal(Vector2i(1, 6))
	assert_that(spear.cell_count()).is_equal(6)
	assert_str(spear.cells_error()).is_equal("")


func test_slot_default_applies_when_data_says_nothing() -> void:
	var bow := Artifact.new(&"bow_x", "Bow", Artifact.Slot.WEAPON)
	assert_that(bow.resolved_cells()).is_equal(Vector2i(2, 3))
	var ring := Artifact.new(&"ring_x", "Ring", Artifact.Slot.RING_R)
	assert_that(ring.resolved_cells()).is_equal(Vector2i(1, 1))
	assert_str(ring.cells_error()).is_equal("")


## Предмет без габарита и с несуществующим слотом → ошибка со списком id.
func test_items_without_footprint_are_listed_by_id() -> void:
	var no_slot_rule := Artifact.new(&"orphan_id", "Orphan", Artifact.Slot.WEAPON)
	no_slot_rule.slot = 99 as Artifact.Slot
	var bad_shape := Artifact.new(&"negative_id", "Negative", Artifact.Slot.WEAPON)
	bad_shape.cells = Vector2i(-1, 2)
	var good := Artifact.new(&"good_id", "Good", Artifact.Slot.NECK)

	var errors := _footprint_errors([no_slot_rule, good, bad_shape])
	assert_that(errors.size()).is_equal(2)
	assert_str(", ".join(errors)).contains("orphan_id")
	assert_str(", ".join(errors)).contains("negative_id")


func test_footprint_survives_serialization() -> void:
	var art := Artifact.new(&"spear_x", "Spear", Artifact.Slot.WEAPON)
	art.cells = Vector2i(1, 6)
	var back := Artifact.from_dict(art.to_dict())
	assert_that(back.cells).is_equal(Vector2i(1, 6))


func test_footprint_text_is_readable() -> void:
	var spear := Artifact.new(&"spear_x", "Spear", Artifact.Slot.WEAPON)
	spear.cells = Vector2i(1, 6)
	assert_str(spear.cells_text()).is_equal("6 клеток")
	spear.cells = Vector2i(1, 2)
	assert_str(spear.cells_text()).is_equal("2 клетки")
	spear.cells = Vector2i(1, 1)
	assert_str(spear.cells_text()).is_equal("1 клетка")


## Гейт реестра: ни один предмет каталога не остался без габарита.
func test_every_registered_artifact_has_a_footprint() -> void:
	var reg: Node = Services.resolve(&"artifacts")
	assert_object(reg).is_not_null()
	var errors := _footprint_errors(reg.get_all())
	assert_str(", ".join(errors)).is_equal("")


func _footprint_errors(arts: Array) -> Array[String]:
	var result: Array[String] = []
	for art: Artifact in arts:
		var err: String = art.cells_error()
		if err != "":
			result.append("%s: %s" % [art.id, err])
	return result

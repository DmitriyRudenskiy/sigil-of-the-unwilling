extends BaseTest

# grid-inventory-and-merchant 4.4 — рюкзак экрана снаряжения как сетка 6×4.
#
# До этого рюкзак был строкой из шести BackpackSlot_* с постраничной прокруткой
# (Prev/Next): у предмета «в сетке» не было места, габарита не было вовсе.
# Носитель теперь 24 клетки GridCell_*, предмет рисуется прямоугольником
# resolved_cells() в повороте rotated[], не влезшее — полосой «Перевес».
#
# Проверка смотрит на цвета конкретных клеток, а не на «что-то нарисовано»:
# ровно шесть клеток должны потемнеть, остальные восемнадцать — остаться
# пустыми. Пиксель кадра этого не отличает.

const _SCENE := preload("res://scenes/ui/artifact_inventory_screen.tscn")

var _screen: ArtifactInventoryScreen = null
var _hero: HeroController = null


func after_test() -> void:
	for node in [_screen, _hero]:
		if node != null and is_instance_valid(node):
			node.free()
	_screen = null
	_hero = null


func _mk_screen(with_hero: bool) -> ArtifactInventoryScreen:
	_screen = _SCENE.instantiate() as ArtifactInventoryScreen
	get_tree().root.add_child(_screen)
	if with_hero:
		_hero = HeroController.new()
		get_tree().root.add_child(_hero)
		_screen.set_hero(_hero)
	return _screen


func _art(id: String, slot: Artifact.Slot, cells: Vector2i) -> Artifact:
	var a := Artifact.new()
	a.id = StringName(id)
	a.display_name = "Предмет " + id
	a.description = "Описание"
	a.slot = slot
	a.cells = cells
	return a


func _cell(screen: Control, col: int, row: int) -> ColorRect:
	return screen.get_node_or_null(
		"Center/Window/Right/Grid/GridCell_%d_%d" % [col, row]) as ColorRect


# --- структура сцены -------------------------------------------------------

func test_scene_has_24_grid_cells() -> void:
	var screen := _mk_screen(false)
	var pitch := ArtifactInventoryScreen.CELL_PITCH
	var size := float(ArtifactInventoryScreen.CELL_SIZE)
	for row in ArtifactInventoryScreen.GRID_ROWS:
		for col in ArtifactInventoryScreen.GRID_COLS:
			var cell := _cell(screen, col, row)
			assert_that(cell).is_not_null()
			# Клетка меньше шага на зазор: соседние не сливаются в полосу.
			assert_that(cell.size).is_equal(Vector2(size, size))
			assert_that(cell.position).is_equal(Vector2(col * pitch, row * pitch))


func test_old_paged_strip_is_gone() -> void:
	var screen := _mk_screen(false)
	# Прокрутка больше не нужна: весь рюкзак виден целиком.
	assert_that(screen.get_node_or_null("Center/Window/Right/Inventory")).is_null()
	assert_that(screen.get_node_or_null("Center/Window/Right/Overflow")).is_not_null()


# --- габарит предмета ------------------------------------------------------

func test_footprint_is_exactly_six_cells() -> void:
	var cells := Vector2i(1, 6)
	var straight := HeroInventory.rect(cells, Vector2i.ZERO, false)
	var turned := HeroInventory.rect(cells, Vector2i.ZERO, true)
	assert_that(straight.size()).is_equal(6)
	assert_that(turned.size()).is_equal(6)
	# Прямой — колонка, повёрнутый — строка: поворот меняет стороны, а не клетки.
	for cell in straight:
		assert_that(int(cell.x)).is_equal(0)
	for cell in turned:
		assert_that(int(cell.y)).is_equal(0)


func test_item_rect_spans_its_cells() -> void:
	var rect := ArtifactInventoryScreen.item_rect(Vector2i.ZERO, Vector2i(1, 6), false)
	assert_that(rect.size).is_equal(Vector2(56, 356))
	# Конец прямоугольника — конец шестой клетки, а не её начало (зазор 4 px).
	var last := ArtifactInventoryScreen.item_rect(Vector2i(2, 1), Vector2i(1, 6), false)
	assert_that(last.end.y).is_equal(float(1 * 60 + 6 * 60 - 4))
	assert_that(ArtifactInventoryScreen.item_rect(Vector2i.ZERO, Vector2i(1, 6), true).size) \
		.is_equal(Vector2(356, 56))


# --- отрисовка ------------------------------------------------------------

func test_item_covers_exactly_its_cells() -> void:
	var screen := _mk_screen(true)
	var inv: HeroInventory = _hero.inventory
	# 2×3 — шесть клеток и влезает в сетку 6×4 без поворота: ровно шесть клеток
	# должны потемнеть, восемнадцать остаться пустыми.
	var art := _art("grid_banner", Artifact.Slot.TORSO, Vector2i(2, 3))
	assert_that(inv.add_to_backpack(art)).is_true()
	screen._refresh_grid()
	var origin: Vector2i = inv.placements[0]
	var rot: bool = inv.rotated[0]
	var want := {}
	for c in HeroInventory.rect(art.resolved_cells(), origin, rot):
		want[c] = true
	assert_that(want.size()).is_equal(6)
	var filled := 0
	for row in ArtifactInventoryScreen.GRID_ROWS:
		for col in ArtifactInventoryScreen.GRID_COLS:
			var cell := Vector2i(col, row)
			var color := _cell(screen, col, row).color
			if want.has(cell):
				filled += 1
				assert_that(color).is_equal(ArtifactInventoryScreen.CELL_FILLED)
			else:
				assert_that(color).is_equal(ArtifactInventoryScreen.CELL_EMPTY)
	assert_that(filled).is_equal(6)
	# Иконка стоит ровно на этих клетках.
	var items := screen.get_node_or_null("Center/Window/Right/Grid/Items")
	assert_that(items.get_child_count()).is_equal(1)
	var icon := items.get_child(0) as Control
	assert_that(icon.position).is_equal(Vector2(origin) * ArtifactInventoryScreen.CELL_PITCH)
	assert_that(icon.size).is_equal(
		ArtifactInventoryScreen.item_rect(origin, art.resolved_cells(), rot).size)


func test_tall_item_is_rotated_to_fit() -> void:
	var screen := _mk_screen(true)
	var inv: HeroInventory = _hero.inventory
	# Копьё 1×6 в сетку 6×4 вертикально не влезает — first_fit обязан взять
	# поворот, а не выбросить предмет в «Перевес».
	assert_that(inv.add_to_backpack(_art("grid_spear", Artifact.Slot.WEAPON, Vector2i(1, 6)))) \
		.is_true()
	assert_that(bool(inv.rotated[0])).is_true()
	assert_that(inv.is_overflow(0)).is_false()
	screen._refresh_grid()
	var items := screen.get_node_or_null("Center/Window/Right/Grid/Items")
	assert_that((items.get_child(0) as Control).size) \
		.is_equal(Vector2(356, 56))


func test_hover_highlights_and_shows_footprint() -> void:
	var screen := _mk_screen(true)
	_hero.inventory.add_to_backpack(_art("grid_banner", Artifact.Slot.TORSO, Vector2i(2, 3)))
	screen._refresh_grid()
	var desc := screen.get_node_or_null("Center/Window/Right/Desc") as Label
	assert_that(desc.text).is_equal("")
	screen._on_item_hover(0)
	# 4.3: габарит обязан быть в описании — до поворота игрок видит цену места.
	assert_that(desc.text).contains("2×3")
	assert_that(desc.text).contains("6 кл.")
	var origin: Vector2i = _hero.inventory.placements[0]
	assert_that(_cell(screen, origin.x, origin.y).color) \
		.is_equal(ArtifactInventoryScreen.CELL_HOVER)
	screen._on_item_hover(-1)
	assert_that(desc.text).is_equal("")
	assert_that(_cell(screen, origin.x, origin.y).color) \
		.is_equal(ArtifactInventoryScreen.CELL_FILLED)


func test_overflow_item_goes_to_the_strip() -> void:
	var screen := _mk_screen(true)
	var inv: HeroInventory = _hero.inventory
	# Полоса «Перевес» — про предметы без клетки: add_to_backpack переполнение
	# не пропустит (вместимость = 24 клетки), поэтому переполнение собирается
	# напрямую — так же его получит сундук, где сетка меньше содержимого.
	for i in 24:
		inv.backpack.append(_art("grid_ring_%d" % i, Artifact.Slot.RING_R, Vector2i(1, 1)))
	inv.backpack.append(_art("grid_boulder", Artifact.Slot.WEAPON, Vector2i(1, 6)))
	inv.repack()
	assert_that(inv.is_overflow(24)).is_true()
	assert_that(inv.is_overflow(0)).is_false()
	screen._refresh_grid()
	assert_that(screen.get_node_or_null("Center/Window/Right/Overflow").get_child_count()) \
		.is_equal(1)
	var lbl := screen.get_node_or_null("Center/Window/Right/Overflow_lbl") as Label
	assert_that(lbl.visible).is_true()
	assert_that(lbl.text).is_equal(GameText.artifact_overflow())

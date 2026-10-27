extends BaseTest

# Рюкзак экрана «Герой» — сетка 10×5 = 50 клеток макета 12 (D-280).
#
# Носитель состава — reference/12_inventory_parchment_sheet.jpeg (сумка в камне
# центра), геометрия — scripts/ui/hero_layout.gd, вместимость —
# GameNumbers.INVENTORY_GRID / MAX_BACKPACK_SIZE. Клетки лежат в сцене (их пишет
# gen_inventory_scene.gd) и растянуты долями, поэтому проверка смотрит на
# фактические прямоугольники после layout, а не на пиксельные константы:
# пиксельный шаг в тесте означал бы второй носитель геометрии.
#
# Предмет рисуется прямоугольником resolved_cells() в повороте rotated[], не
# влезшее в 50 клеток — полосой «Перевес».

const _SCENE := preload("res://scenes/ui/artifact_inventory_screen.tscn")
const _BAG := "Center/Window/Sheet/Stone/Bag"
const _ITEMS := "Center/Window/Sheet/Stone/Bag/Items"
const _OVERFLOW := "Center/Window/Sheet/Stone/Overflow"
const _OVERFLOW_LBL := "Center/Window/Sheet/Stone/Overflow_lbl"
const _DESC := "Center/Window/Sheet/ItemTip/TipBox/Desc"
const _TIP := "Center/Window/Sheet/ItemTip"
# Явный шаг для чистой функции раскладки: тест не зависит от размера окна.
const _PITCH := Vector2(60, 60)

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
	# Доли якорей сходятся только на следующем кадре — до него размеры узлов нули.
	await await_idle_frame()
	return _screen


func _art(id: String, slot: Artifact.Slot, cells: Vector2i) -> Artifact:
	var a := Artifact.new()
	a.id = StringName(id)
	a.display_name = "Предмет " + id
	a.description = "Описание"
	a.slot = slot
	a.cells = cells
	return a


func _cell(screen: Control, col: int, row: int) -> TextureRect:
	return screen.get_node_or_null("%s/GridCell_%d_%d" % [_BAG, col, row]) as TextureRect


# --- структура сцены -------------------------------------------------------

func test_scene_has_fifty_grid_cells() -> void:
	var screen := await _mk_screen(false)
	assert_that(ArtifactInventoryScreen.GRID_COLS).is_equal(10)
	assert_that(ArtifactInventoryScreen.GRID_ROWS).is_equal(5)
	# Клеток ровно по вместимости: «клетка без предмета» и «предмет без клетки»
	# — одна и та же ошибка, ловится одним равенством.
	assert_that(GameNumbers.MAX_BACKPACK_SIZE) \
		.is_equal(ArtifactInventoryScreen.GRID_COLS * ArtifactInventoryScreen.GRID_ROWS)
	var bag := screen.get_node_or_null(_BAG) as Control
	assert_that(bag).is_not_null()
	var seen := {}
	for row in ArtifactInventoryScreen.GRID_ROWS:
		for col in ArtifactInventoryScreen.GRID_COLS:
			var cell := _cell(screen, col, row)
			assert_that(cell).is_not_null()
			assert_that(cell.size.x > 0.0 and cell.size.y > 0.0).is_true()
			# Клетка обязана лежать внутри камня сумки, а не вылезать за неё.
			assert_that(bag.get_global_rect().encloses(cell.get_global_rect())).is_true()
			var key := cell.get_global_rect().position
			assert_that(seen.has(key)).is_false()  # клетки не наслаиваются
			seen[key] = true


func test_old_paged_strip_is_gone() -> void:
	var screen := await _mk_screen(false)
	# Прокрутка не нужна: весь рюкзак виден целиком, старого состава нет.
	assert_that(screen.get_node_or_null("Center/Window/Right")).is_null()
	assert_that(screen.get_node_or_null(_OVERFLOW)).is_not_null()
	# Подсказка предмета живёт отдельным блоком и скрыта, пока предмета нет.
	var tip := screen.get_node_or_null(_TIP) as Control
	assert_that(tip).is_not_null()
	assert_that(tip.visible).is_false()


# --- габарит предмета ------------------------------------------------------

func test_item_rect_spans_its_cells() -> void:
	var rect := ArtifactInventoryScreen.item_rect(Vector2i.ZERO, Vector2i(1, 6), false, _PITCH)
	assert_that(rect.size).is_equal(Vector2(56, 356))
	# Конец прямоугольника — конец шестой клетки, а не её начало (зазор 4 px).
	var last := ArtifactInventoryScreen.item_rect(Vector2i(2, 1), Vector2i(1, 6), false, _PITCH)
	assert_that(last.end.y).is_equal(float(1 * 60 + 6 * 60 - 4))
	assert_that(ArtifactInventoryScreen.item_rect(Vector2i.ZERO, Vector2i(1, 6), true, _PITCH).size) \
		.is_equal(Vector2(356, 56))


# --- отрисовка ------------------------------------------------------------

func test_item_covers_exactly_its_cells() -> void:
	var screen := await _mk_screen(true)
	var inv: HeroInventory = _hero.inventory
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
			var color := _cell(screen, col, row).modulate
			if want.has(cell):
				filled += 1
				assert_that(color).is_equal(ArtifactInventoryScreen.CELL_FILLED)
			else:
				assert_that(color).is_equal(ArtifactInventoryScreen.CELL_EMPTY)
	assert_that(filled).is_equal(6)
	# Иконка стоит ровно на этих клетках — шаг берётся из фактического Bag.
	var pitch: Vector2 = screen._bag_pitch()
	var items := screen.get_node_or_null(_ITEMS)
	assert_that(items.get_child_count()).is_equal(1)
	var icon := items.get_child(0) as Control
	assert_that(icon.position).is_equal(Vector2(origin) * pitch)
	assert_that(icon.size).is_equal(
			ArtifactInventoryScreen.item_rect(origin, art.resolved_cells(), rot, pitch).size)


func test_tall_item_is_rotated_to_fit() -> void:
	var screen := await _mk_screen(true)
	var inv: HeroInventory = _hero.inventory
	# Копьё 1×6 в 5 строк не влезает по высоте — first_fit обязан взять поворот.
	assert_that(inv.add_to_backpack(_art("grid_spear", Artifact.Slot.WEAPON, Vector2i(1, 6)))) \
		.is_true()
	assert_that(bool(inv.rotated[0])).is_true()
	assert_that(inv.is_overflow(0)).is_false()
	screen._refresh_grid()
	var pitch: Vector2 = screen._bag_pitch()
	var items := screen.get_node_or_null(_ITEMS)
	assert_that((items.get_child(0) as Control).size) \
		.is_equal(ArtifactInventoryScreen.item_rect(inv.placements[0], Vector2i(1, 6), true, pitch).size)


func test_hover_highlights_and_shows_footprint() -> void:
	var screen := await _mk_screen(true)
	_hero.inventory.add_to_backpack(_art("grid_banner", Artifact.Slot.TORSO, Vector2i(2, 3)))
	screen._refresh_grid()
	var desc := screen.get_node_or_null(_DESC) as Label
	assert_that(desc.text).is_equal("")
	var tip := screen.get_node_or_null(_TIP) as Control
	assert_that(tip.visible).is_false()
	screen._on_item_hover(0)
	# Габарит обязан быть в описании — до поворота игрок видит цену места.
	assert_that(desc.text).contains("2×3")
	assert_that(desc.text).contains("6 кл.")
	assert_that(tip.visible).is_true()
	var origin: Vector2i = _hero.inventory.placements[0]
	assert_that(_cell(screen, origin.x, origin.y).modulate) \
		.is_equal(ArtifactInventoryScreen.CELL_HOVER)
	screen._on_item_hover(-1)
	assert_that(desc.text).is_equal("")
	assert_that(tip.visible).is_false()
	assert_that(_cell(screen, origin.x, origin.y).modulate) \
		.is_equal(ArtifactInventoryScreen.CELL_FILLED)


func test_overflow_item_goes_to_the_strip() -> void:
	var screen := await _mk_screen(true)
	var inv: HeroInventory = _hero.inventory
	# Полоса «Перевес» — про предметы без клетки: add_to_backpack переполнение не
	# пропустит (вместимость = 50 клеток), поэтому переполнение собирается
	# напрямую — так же его получит сундук, где сетка меньше содержимого.
	for i in GameNumbers.MAX_BACKPACK_SIZE:
		inv.backpack.append(_art("grid_ring_%d" % i, Artifact.Slot.RING_R, Vector2i(1, 1)))
	inv.backpack.append(_art("grid_boulder", Artifact.Slot.WEAPON, Vector2i(1, 6)))
	inv.repack()
	var last := inv.backpack.size() - 1
	assert_that(inv.is_overflow(last)).is_true()
	assert_that(inv.is_overflow(0)).is_false()
	screen._refresh_grid()
	assert_that(screen.get_node_or_null(_OVERFLOW).get_child_count()).is_equal(1)
	var lbl := screen.get_node_or_null(_OVERFLOW_LBL) as Label
	assert_that(lbl.visible).is_true()
	assert_that(lbl.text).is_equal(GameText.artifact_overflow())

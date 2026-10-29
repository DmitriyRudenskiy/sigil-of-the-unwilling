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
const _DESC := "Center/Window/Sheet/ItemTip/TipBox/TipDesc"
const _TIP := "Center/Window/Sheet/ItemTip"
const _DOLL := "Center/Window/Sheet/Stone/Doll"
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


## Клетки и предметы обязаны делить один шаг решётки (T-255).
## На кадре рамка предмета была шире своих клеток: клетки расставлялись
## пиксельными офсетами от размера макета (и не сжимались ниже текстуры),
## а оверлеи считались долями от фактического `Bag`.
func test_cells_and_items_share_one_pitch() -> void:
	var screen := await _mk_screen(true)
	var pitch: Vector2 = screen._bag_pitch()
	for row in ArtifactInventoryScreen.GRID_ROWS:
		for col in ArtifactInventoryScreen.GRID_COLS:
			var cell := _cell(screen, col, row)
			# Клетка = ровно своя ячейка решётки, без пиксельных желобов:
			# их рисует плитка, иначе долевой и пиксельный отступы разойдутся.
			var origin := Vector2(col, row) * pitch
			assert_float(cell.position.x).is_equal_approx(origin.x, 0.5)
			assert_float(cell.position.y).is_equal_approx(origin.y, 0.5)
			assert_float(cell.size.x).is_equal_approx(pitch.x, 0.5)
			assert_float(cell.size.y).is_equal_approx(pitch.y, 0.5)


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


## T-271: панель предмета — плита в поле сумки, а не над куклой. Дом обязан
## лежать в поле и вне кадра фигуры: прежний rect ставил плиту над полем
## куклы, и три её рамки оказывались под открытой подсказкой (слот под ней
## нельзя было выбрать). Таблица геометрии — носитель дома, поэтому сверяется
## напрямую, без окна.
func test_tip_home_lives_in_the_bag_field_not_over_the_doll() -> void:
	var home: Rect2 = HeroLayout.BLOCKS["ItemTip"]
	var field := HeroLayout.bag_canvas()
	var stone: Rect2 = HeroLayout.BLOCKS["Stone"]
	var figure: Rect2 = HeroLayout.BLOCKS["Figure"]
	var doll := Rect2(stone.position + figure.position, figure.size)
	assert_that(home.size).is_equal(Vector2(460, 240))
	assert_that(home).is_equal(Rect2(field.end - home.size, home.size))
	assert_bool(field.encloses(home)).is_true() \
		.override_failure_message("дом панели предмета вне поля сумки: %s в %s" % [home, field])
	assert_bool(not doll.intersects(home)).is_true() \
		.override_failure_message(
				"дом панели предмета (%s) накладывается на кадр куклы (%s)" % [home, doll])


## Живой экран: при выборе любого предмета плита остаётся в поле сумки и не
## задевает ни одну из 16 рамок куклы. Проверка идёт от выбора предмета, а не
## от вызова раскладки: путь `select_backpack → _repaint → _update_desc` и есть
## тот, по которому плита едет в игре.
func test_tip_never_covers_a_doll_frame() -> void:
	var screen := await _mk_screen(true)
	var inv: HeroInventory = _hero.inventory
	assert_that(inv.add_to_backpack(_art("tip_sword", Artifact.Slot.WEAPON, Vector2i(2, 2)))) \
		.is_true()
	assert_that(inv.add_to_backpack(_art("tip_torso", Artifact.Slot.TORSO, Vector2i(3, 2)))) \
		.is_true()
	screen._refresh_grid()
	var tip := screen.get_node_or_null(_TIP) as Control
	var bag := screen.get_node_or_null(_BAG) as Control
	for i in inv.backpack.size():
		screen.select_backpack(i)
		# Якоря и автоперенос сходятся только к следующему кадру: до него размер плиты
		# — переходный (подпись ещё не разложена по ширине), и замер врал бы.
		await await_idle_frame()
		var r := tip.get_global_rect()
		assert_bool(tip.visible).is_true() \
			.override_failure_message("предмет %d выбран, а панели предмета нет" % i)
		assert_bool(bag.get_global_rect().encloses(r.grow(-0.5))).is_true() \
			.override_failure_message(
					"панель предмета вышла из поля сумки: %s против %s" % [r, bag.get_global_rect()])
		for f in ArtifactInventoryScreen.DOLL_SLOTS_N:
			var frame := screen.get_node_or_null(_DOLL + "/DollSlot_%d" % f) as Control
			assert_that(frame).is_not_null()
			assert_bool(not frame.get_global_rect().intersects(r)).is_true() \
				.override_failure_message(
						"панель предмета (%s) легла на рамку куклы №%d (%s) — слот не выбрать"
						% [r, f, frame.get_global_rect()])


## Угловой предмет плита закрывать не вправе: от него она отжимается к
## противоположному углу поля. Клетки в середине поля отжиманием не спасаются —
## плита 460×240 при поле 720×354 перекрывает шесть клеток из десяти при любом
## положении, и это осознанная цена (T-271: «правится местом, не размером»).
func test_tip_steps_away_from_a_corner_item() -> void:
	var screen := await _mk_screen(true)
	var inv: HeroInventory = _hero.inventory
	for corner in [Vector2i.ZERO, Vector2i(9, 0), Vector2i(0, 4), Vector2i(9, 4)]:
		inv.backpack.clear()
		inv.placements.clear()
		inv.rotated.clear()
		assert_that(inv.add_to_backpack(_art("tip_corner", Artifact.Slot.WEAPON, Vector2i(1, 1)))) \
			.is_true()
		inv.placements[0] = corner
		screen._refresh_grid()
		screen.select_backpack(0)
		await await_idle_frame()
		var tip := screen.get_node_or_null(_TIP) as Control
		var icon := screen.get_node_or_null(_ITEMS + "/Item_0") as Control
		assert_that(icon).is_not_null()
		var r := tip.get_global_rect()
		assert_bool(not r.has_point(icon.get_global_rect().get_center())).is_true() \
			.override_failure_message(
					"плита %s закрыла угловой предмет (%s)" % [r, icon.get_global_rect()])

## Прямоугольник обязан лежать внутри поля сумки с допуском в полпикселя:
## долевой шаг даёт дробные координаты, а верхняя кромка предмета верхнего ряда
## совпадает с границей поля, а не отстоит от неё.
func _inside(field: Rect2, r: Rect2) -> bool:
	var TOL := 0.5
	return r.position.x >= field.position.x - TOL \
			and r.position.y >= field.position.y - TOL \
			and r.end.x <= field.end.x + TOL \
			and r.end.y <= field.end.y + TOL


## Предмет и его рамки обязаны оставаться внутри поля сумки (T-255).
##
## Симптом тикета — «иконки верхнего ряда вылезают за верхнюю границу сетки» —
## держался не на двух шагах решётки, а на `expand_mode = KEEP_SIZE` у
## клетки-текстуры: минимум такого узла равен размеру плитки, поэтому клетка из
## плитки 96 px не сжималась до своих 76 и торчала за `Bag` (снято в 16224d78).
## Равенство шага клеток и оверлеев сторожит `test_cells_and_items_share_one_pitch`;
## этот кейс сторожит следствие на опасном крае — у предмета в нулевой строке
## верхняя кромка и есть граница поля, а рамка выделения («шире своих клеток и
## смещена вправо-вверх» по тикету) обязана совпадать с прямоугольником предмета.
func test_item_and_its_frames_stay_inside_the_field() -> void:
	var screen := await _mk_screen(true)
	var inv: HeroInventory = _hero.inventory
	assert_that(inv.add_to_backpack(_art("t255_shield", Artifact.Slot.SHIELD, Vector2i(3, 2)))) \
		.is_true()
	assert_that(inv.add_to_backpack(_art("t255_banner", Artifact.Slot.TORSO, Vector2i(2, 3)))) \
		.is_true()
	# Опасные края сетки: верхняя строка (кромка предмета = граница поля) и
	# левый нижний угол (предмет 2×3 у нижней границы).
	inv.placements[0] = Vector2i(6, 0)
	inv.placements[1] = Vector2i(0, 2)
	screen._refresh_grid()
	screen.select_backpack(0)
	await await_idle_frame()
	var field := (screen.get_node_or_null(_BAG) as Control).get_global_rect()
	var items := screen.get_node_or_null(_ITEMS) as Node
	assert_that(items.get_child_count()).is_equal(2)
	var first := Rect2()
	for idx in 2:
		var icon := items.get_node_or_null("Item_%d" % idx) as Control
		assert_that(icon).is_not_null()
		var r := icon.get_global_rect()
		assert_bool(_inside(field, r)).is_true() \
			.override_failure_message("иконка %d (%s) вышла за поле %s" % [idx, r, field])
		if idx == 0:
			first = r
	# Рамка выделения = сам предмет: ни шире, ни смещённее (иначе подсветка врёт
	# о том, какие клетки заняты, — ровно формулировка тикета).
	var mark := screen.get_node_or_null(
			"%s/Item_0/%s" % [_ITEMS, ArtifactInventoryScreen._MARK_SELECTED]) as Control
	assert_that(mark).is_not_null()
	assert_bool(mark.get_global_rect() == first).is_true() \
		.override_failure_message(
				"рамка %s не совпала с предметом %s" % [mark.get_global_rect(), first])
	for strip in mark.get_children():
		assert_bool(_inside(field, (strip as Control).get_global_rect())).is_true() \
			.override_failure_message("полоска рамки выделения вышла за поле сумки")

## У прямоугольника предмета не может быть «своего» шага решётки (T-255): шаг —
## обязательный параметр, а не значение по умолчанию. Скан исходника, а не
## поведение: вызывающий, которому вернётся канва-шаг по умолчанию, красит
## поведенческие тесты только на растянутом окне (T-248), а здесь проверяется
## сам носитель — подпись функции.
func test_item_rect_has_no_default_pitch() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ui/artifact_inventory_screen.gd")
	var at := src.find("static func item_rect(")
	assert_bool(at >= 0).is_true().override_failure_message("предметный rect не найден в носителе")
	var block := src.substr(at, src.find("\n\n", at) - at)
	assert_bool(block.contains("= Vector2.ZERO")).is_false() \
		.override_failure_message("у item_rect снова есть шаг по умолчанию — второй носитель решётки")
	assert_bool(block.contains("grid_pitch")).is_false() \
		.override_failure_message("item_rect сам читает канва-шаг: вызывающий теряет пространство координат")

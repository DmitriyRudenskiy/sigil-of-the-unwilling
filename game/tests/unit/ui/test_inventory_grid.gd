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
const _FIGURE := "Center/Window/Sheet/Stone/Figure"
const _STONE := "Center/Window/Sheet/Stone"
# Карточки отряда (I1–J9) и строка уровня (A5–D6) — T-306.
const _CARDS := "Center/Window/Sheet/Units/Bottom/Cards/Card_%d"
const _LEVEL_ROW := "Center/Window/Sheet/Left/LevelRow"
const _CARD_N := 4
# Настоящие стеки из реестра `units`: тест не изобретает имена и числа, а читает
# те же объекты, что читает экран (второй носитель факта — урок D-132).
const _ROSTER := [["swordsmen", 103], ["archers", 36], ["cavalry", 34], ["mages", 10]]
#Зоны переноса A и C (мана + школа, навыки + построения).
const _BANDS := ["Center/Window/Sheet/BandMana", "Center/Window/Sheet/BandSkills"]
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

## Марджин 9-slice рамки камня — из реестра кита, а не из копии в тесте:
## генератор берёт то же число (`_kit_margin("panel_stone")`), и тест обязан
## краснеть, если реестр изменится, а сцена — нет.
func _kit_margin(name: String) -> int:
	var raw: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://assets/ui/hero/MANIFEST.json"))
	assert_that(raw).is_not_null()
	var files: Variant = (raw as Dictionary).get("files", {})
	var entry: Variant = (files as Dictionary).get("hero/" + name + ".png", {})
	assert_that(entry).is_not_null()
	var margin: int = int((entry as Dictionary).get("margin", 0))
	assert_bool(margin > 0).is_true() \
		.override_failure_message("у %s нет margin в MANIFEST — рамку нечем мерить" % name)
	return margin


func _controls_under(node: Node, out: Array) -> Array:
	for child in node.get_children():
		if child is Control:
			out.append(child)
			_controls_under(child, out)
	return out


## Зоны переноса обязаны стоять внутри камня, за полосой его рамки (T-257).
##
## Симптом тикета — полоса маны на пергаментном листе, строки навыков за правым
## краем камня. Диагноз тикета («доли зон считаются от канвы, а не от `Stone»`)
## не подтвердился: доли правильные, и в таблице зоны стоят внешним краем ровно
## на крае камня (504 и 1307). Настоящая причина — попытка 16224d78: отступ был
## вычтен со знаком наружу (offset_left = −14), и обе зоны встали на 14 px НАРУЖУ
## самого камня, то есть на пергаменте за его рамкой.
##
## Норму отступа задаёт не толщина видимой линии (у рамки panel_stone она
## тонкая: яркость текстуры падает со 160 до 26 за 6 px), а марджин 9-slice —
## 40 px из `assets/ui/hero/MANIFEST.json`: в этой полосе лежат и линия, и
## угловой орнамент. Число читается из MANIFEST, второй его копии в коде нет.
##
## Отступ — пикселями, а не долей камня: полоса рамки стоит постоянными
## `patch_margin` в логических px, тогда как прямоугольник камня меняет
## логический размер вместе с окном (canvas_items + expand, project.godot
## [display]). Живой замер окна 1440×1080: внутренняя граница камня выросла по
## высоте с 982 до 1336 логических px, offset зоны остался 40 px.
func test_transfer_bands_stay_inside_the_stone_face() -> void:
	var screen := await _mk_screen(true)
	var stone := (screen.get_node_or_null(_STONE) as Control).get_global_rect()
	var border := float(_kit_margin("panel_stone"))
	var face := stone.grow(-border)
	assert_bool(face.size.x > 0.0 and face.size.y > 0.0).is_true() \
		.override_failure_message("камень уже своей рамки — премиса теста сломана")
	for path in _BANDS:
		var band := screen.get_node_or_null(path) as Control
		assert_that(band).is_not_null()
		var r := band.get_global_rect()
		assert_bool(_inside(face, r)).is_true() \
			.override_failure_message(
					"зона %s (%s) вышла за полосу рамки камня %s" % [path, r, face])
		# Внешний край зоны обязан отстоять от прямоугольника камня не меньше
		# марджина рамки: именно это и значит «границы совпадают» для тикета.
		var edge := r.position.x if path.ends_with("Mana") else stone.end.x - r.end.x
		assert_bool(edge >= border - 1.0).is_true() \
			.override_failure_message(
					"внешний край %s стоит в %.2f px от края камня при рамке %.0f px" % [
						path, edge, border])
		# Пиксельная природа отступа, независимая от размера окна: зону
		# отодвинул от якоря ровно марджин рамки камня, а не произвольное число
		# и не доля камня (она бы поехала при другом аспекте окна).
		var outer := "offset_left" if path.ends_with("Mana") else "offset_right"
		var want := border if outer == "offset_left" else -border
		assert_bool(is_equal_approx(band.get(outer), want)).is_true() \
				.override_failure_message(
						"%s: %s = %.2f px при рамке %.0f px" % [path, outer, float(band.get(outer)), border])
		assert_bool(is_equal_approx(band.offset_top, border)).is_true() \
				.override_failure_message(
						"%s: верх зоны не убран за рамку камня (offset_top = %.2f)" % [path, band.offset_top])
		for node in _controls_under(band, []):
			assert_bool(_inside(face, (node as Control).get_global_rect())).is_true() \
				.override_failure_message(
						"%s.%s легло на рамку камня (%s при внутренней границе %s)" % [
							path, (node as Node).get_name(),
							(node as Control).get_global_rect(), face])


## T-258: кукла обязана занимать свой адресный блок (E1–G6) целиком.
##
## Тикет утверждал два: «светлой каменной врезки под куклой нет» и «фигура
## стоит вверху блока и по высоте вдвое меньше макета». Второе было верно про
## заглушку и снято T-249: `hero/figure.png` — арт ComfyUI 428×478 с вырезанным
## фоном, т.е. 1:1 к блоку 427×477. Первое перенесено в T-316: у врезки нет
## носителя — ни строки в карте элементов (docs/20-ux-hero-screen.md §3), ни
## записи в BLOCKS, ни ассета в ките, а пикселей макета 12 на диске нет (T-298),
## поэтому её геометрию нечем измерить.
##
## Здесь — замер, а не постройка. Проверяются: прямоугольник узла после layout,
## свойства `TextureRect`, которыми текстура рисуется именно в этом
## прямоугольнике, и доля чернил в самой текстуре. Чернила — потому что
## «мельче блока» рождается не только якорями: арт с прозраческими полями даёт
## маленькую куклу в правильном прямоугольнике, и прямоугольник узла этого не
## видит (урок T-255: смотреть на следствие, а не на конструкцию).
func test_doll_figure_fills_its_address_block() -> void:
	var screen := await _mk_screen(true)
	var fig := screen.get_node_or_null(_FIGURE) as TextureRect
	assert_that(fig).is_not_null()
	var stone := (screen.get_node_or_null(_STONE) as Control).get_global_rect()
	var s: Rect2 = HeroLayout.BLOCKS["Stone"]
	var b: Rect2 = HeroLayout.BLOCKS["Figure"]
	var r := fig.get_global_rect()
	var TOL := 1.0
	var want := Rect2(
			stone.position + b.position / s.size * stone.size, b.size / s.size * stone.size)
	# `.is_true()` обязателен: без check-метода GdUnit проверку не выполняет
	# вообще, и первый прогон этой батареи оставался зелёным на M1 и M2.
	assert_bool(abs(r.position.x - want.position.x) <= TOL
			and abs(r.position.y - want.position.y) <= TOL
			and abs(r.size.x - want.size.x) <= TOL
			and abs(r.size.y - want.size.y) <= TOL) \
		.is_true() \
		.override_failure_message(
				"фигура %s не совпала со своим адресным блоком %s (камень %s)" % [r, want, stone])
	# KEEP_SIZE вместо IGNORE_SIZE делает минимумом узла размер текстуры, и якоря
	# перестают слушаться — тот же класс, что клетки с `custom_minimum_size`.
	assert_that(fig.expand_mode).is_equal(TextureRect.EXPAND_IGNORE_SIZE)
	# Куклу нельзя растягивать в окне другого аспекта — рисунок сохраняется
	# пропорциональным и центрированным, поэтому высота чернил проверяется ниже.
	assert_that(fig.stretch_mode).is_equal(TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	var img := fig.texture.get_image()
	assert_that(img).is_not_null()
	var fill := float(img.get_used_rect().size.y) / float(img.get_height())
	assert_bool(fill >= 0.85).is_true() \
		.override_failure_message(
				"кукла занимает %.2f высоты своей текстуры — в кадре она меньше блока" % fill)
	# Пропорции сохраняются, поэтому при другом аспекте окна кукла обязана
	# упираться в блок хотя бы одной своей стороной (letterbox допустим по
	# одной оси, но не полями с обеих сторон). Для канонического 16:9 из этих
	# же чисел следует 0.9996 высоты блока (кадр 1920×1080: блок 512.3×572.4 px,
	# аспект текстуры 0.8954 → рисунок 572.2 px), из них чернил — 0.993.
	var aspect := float(img.get_width()) / float(img.get_height())
	var drawn_w := minf(r.size.x, r.size.y * aspect) / r.size.x
	var drawn_h := minf(r.size.y, r.size.x / aspect) / r.size.y
	assert_bool(maxf(drawn_w, drawn_h) >= 0.98).is_true() \
		.override_failure_message(
				"рисунок куклы %.2f×%.2f блока %s при аспекте текстуры %.4f" % [
					drawn_w, drawn_h, r, aspect])


## T-306: экран «Герой» показывает только то, у чего есть носитель.
##
## Тикет утверждал, что «уровня и опыта героя нет ни в одной модели». Замер это
## опровергает и уточняет: носитель есть, но не у той модели, которую экран
## видит. Уровень и опыт есть у членов кампанийного отряда (`state.party`,
## `PartySystem`, `data/config/balance/xp.json`) и уже показываются на экране
## «Отряд» («ур. 2», «XP 1200», `party_screen.gd:112-116`, гард
## `tests/campaign/test_party_screen.gd:90`); уровень есть у D&D-профиля
## (`DnDCombatantProfile.level`), но тот слой из продукции не вызывается (T-311).
## У модели же, которую экран видит в единственном своём живом носителе (окно
## «Модель героя» из настроек, `main_menu.gd:222-228`, D-255), уровня нет:
## `HeroController` хранит только опыт (`get_xp`), да и того его писатель
## (`world_battle_coordinator.gd:370`) живёт в архивной мирной линии.
##
## У карточки отряда носителя нет по-настоящему: `UnitStack` — это `count` плюс
## `UnitStats`, ни уровня, ни текущего HP, ни второй шкалы у стека нет
## (`current_hp` живёт у персон отряда, D-220). Поэтому имя, иконка и число
## показываются, а `CardLv_*`/`CardHp_*`/`CardMp_*` и `LevelRow` скрыты, а не
## обнулены (D-280, T-251).
##
## Гард держит обе половины: вернут скрытые метки — покраснеет; экран перестанет
## показывать то, что показать должен, — покраснеет тоже. Батарея —
## `game/tools/mut_hero_unit_cards.sh` (M1 вернуть метки, M2 перестать писать
## имя, M3 показывать численность пустого слота).
func test_unit_cards_and_level_row_show_only_what_has_a_carrier() -> void:
	var screen := await _mk_screen(true)
	assert_that(_hero.army).is_not_null()
	# A) Пустой ростер — живое состояние окна модели: у нового героя армии нет,
	# поэтому иконку и численность показывать нечем, а имя не должно печатать.
	for i in _CARD_N:
		var ic0 := _card_child(screen, i, "ArmyIcon_%d" % i) as TextureRect
		var ct0 := _card_child(screen, i, "ArmyCount_%d" % i) as Label
		var nm0 := _card_child(screen, i, "CardName_%d" % i) as Label
		assert_that(ic0).is_not_null()
		assert_bool(not ic0.visible).is_true() \
				.override_failure_message("иконка карточки %d видима при пустом ростере" % i)
		assert_bool(not ct0.visible).is_true() \
				.override_failure_message("численность карточки %d видима при пустом ростере" % i)
		assert_str(nm0.text).is_equal("")
	# B) Непустой ростер из настоящих стеков: имя, иконка и численность — показаны.
	var units: Node = Services.resolve(&"units")
	var stacks: Array[UnitStack] = []
	for pair in _ROSTER:
		stacks.append(units.make_fixed_stack(String(pair[0]), int(pair[1])))
	_hero.army.army = stacks
	screen.set_hero(_hero)
	await await_idle_frame()
	for i in stacks.size():
		var st: UnitStack = stacks[i]
		# Носитель проверяется до экрана: пустое имя сделало бы сравнение ниже
		# молчаливым — оно было бы зелёным при любом тексте метки.
		assert_bool(st.get_display_name() != "").is_true() \
				.override_failure_message("у стека %s пустое отображаемое имя" % st.get_key())
		var ic := _card_child(screen, i, "ArmyIcon_%d" % i) as TextureRect
		var ct := _card_child(screen, i, "ArmyCount_%d" % i) as Label
		var nm := _card_child(screen, i, "CardName_%d" % i) as Label
		assert_bool(ic.visible).is_true() \
				.override_failure_message("иконка стека %s не показана" % st.get_key())
		assert_bool(ct.visible).is_true() \
				.override_failure_message("численность стека %s не показана" % st.get_key())
		assert_str(nm.text).is_equal(st.get_display_name())
		assert_str(ct.text).is_equal(str(st.count))
	# C) Три значения карточки и строка уровня скрыты при любом ростере: у стека
	# нет ни уровня, ни текущего HP, ни второй шкалы, у модели героя нет уровня.
	for i in _CARD_N:
		for key in ["CardLv_", "CardHp_", "CardMp_"]:
			var ph := _card_child(screen, i, "%s%d" % [key, i]) as Control
			assert_that(ph).is_not_null()
			assert_bool(not ph.visible).is_true() \
					.override_failure_message(
							"%s%d видима при носителе, которого нет (T-306, D-280)" % [key, i])
	var lv := screen.get_node_or_null(_LEVEL_ROW) as Control
	assert_that(lv).is_not_null()
	assert_bool(not lv.visible).is_true() \
			.override_failure_message(
					"строка уровня видима, хотя у модели героя уровня нет (T-306, T-251)")


func _card_child(screen: Control, idx: int, what: String) -> Control:
	return screen.get_node_or_null("%s/%s" % [_CARDS % idx, what]) as Control

## --- опись строк экрана (T-247) -------------------------------------------
##
## Экран «Герой» собран по макету 12, и до сих пор ответ на вопрос «что на этом
## экране есть и чем оно заполняется» жил только в прозе карты элементов
## docs/20-ux-hero-screen.md. Опись переносит ответ в машиночитаемый носитель —
## game/scenes/ui/artifact_inventory_screen.carriers.csv, где каждая строка
## карты §3 стоит рядом со своим узлом, ассетом и писателем данных.
##
## Гард сторожит сам носитель: CSV, который никто не проверяет, врёт тише
## прозы. Красным становится на: рассогласовании шапки COVERAGE со строками
## `# TYPE` и со статусами строк; на пути узла, которого нет в сцене (узел
## переименовали — опись обязана покраснеть, а не молчать); на ассете кита,
## которого нет на диске; на строки без носителя или вне макета без ссылки на
## билет; на текстуре кита в сцене, которую опись не назвала.
const _CARRIERS := "res://scenes/ui/artifact_inventory_screen.carriers.csv"
const _KIT_DIR := "res://assets/ui/hero/"
const _CARRIER_COLS := 8
const _CARRIER_STATUSES := ["covered", "no-carrier", "outside-mockup"]
const _CARRIER_TYPES := 14

## Разбор описи: {header, rows, types, coverage}. Коментарии — строки с `#`.
func _carriers() -> Dictionary:
	var txt := FileAccess.get_file_as_string(_CARRIERS)
	assert_bool(txt != "").is_true() \
			.override_failure_message("опись строк экрана не найдена: " + _CARRIERS)
	var rows: Array = []
	var types := {}
	var coverage := {}
	var header := PackedStringArray()
	for line in txt.split("\n"):
		var l := line.strip_edges()
		if l == "":
			continue
		if l.begins_with("# COVERAGE"):
			# `# COVERAGE artifact_inventory_screen: covered 13 / outside-mockup 7 / missing 1`
			for part in l.substr(l.find(":") + 1).split("/"):
				var words := part.strip_edges().split(" ")
				assert_that(words.size()).is_equal(2)
				coverage[words[0]] = int(words[1])
		elif l.begins_with("# TYPE"):
			# `# TYPE 04 строка уровня = missing` — номер держит порядок типов
			# карты §4, имя связывает строку `# TYPE` со столбцом mockup_type.
			var rhs := l.trim_prefix("# TYPE").strip_edges()
			assert_bool(rhs.contains("=")).is_true() \
					.override_failure_message("строка типа макета без статуса: " + l)
			var lhs: String = rhs.split("=")[0].strip_edges()
			var num := lhs.split(" ")[0]
			assert_that(num).is_equal("%02d" % (types.size() + 1))
			types[lhs.trim_prefix(num + " ")] = rhs.split("=")[1].strip_edges()
		elif l.begins_with("#"):
			continue
		elif header.is_empty():
			header = PackedStringArray(l.split(","))
		else:
			rows.append(l.split(","))
	return {"header": header, "rows": rows, "types": types, "coverage": coverage}


## 14 типов строк макета закрыты или честно не закрыты; опись им не противоречит.
func test_carrier_inventory_accounts_for_every_mockup_row_type() -> void:
	var inv := _carriers()
	assert_that(Array(inv.header)).is_equal(
			["row", "mockup_type", "mockup", "node", "asset", "data", "status", "note"])
	assert_that(inv.types.size()).is_equal(_CARRIER_TYPES)
	var covered := 0
	var missing := 0
	for kind in inv.types.values():
		assert_bool(kind in ["covered", "missing"]).is_true() \
				.override_failure_message("тип макета с неизвестным статусом: " + str(kind))
		covered += 1 if kind == "covered" else 0
		missing += 1 if kind == "missing" else 0
	assert_that(covered + missing).is_equal(_CARRIER_TYPES)
	assert_that(inv.coverage.get("covered", -1)).is_equal(covered)
	assert_that(inv.coverage.get("missing", -1)).is_equal(missing)
	# outside-mockup считается по номерам строк карты (инстансы одного типа свёрнуты
	# в семейства), поэтому — множеством, а не суммой строк CSV.
	var outside := {}
	for f in inv.rows:
		assert_that(f.size()).is_equal(_CARRIER_COLS)
		var status: String = f[6]
		assert_bool(status in _CARRIER_STATUSES).is_true() \
				.override_failure_message("неизвестный статус строки %s: %s" % [f[0], status])
		if status != "covered":
			assert_bool(f[0] != "" and (f[7].contains("T-") or f[7].contains("Q-")
					or f[7].contains("D-") or f[7].contains("UI-") or f[7].contains("§"))) \
				.is_true() \
				.override_failure_message(
						"строка %s со статусом «%s» без ссылки на билет или раздел карты" % [f[0], status])
		if status == "outside-mockup" and not f[0].begins_with("+"):
			outside[f[0]] = true
	assert_that(inv.coverage.get("outside-mockup", -1)).is_equal(outside.size())
	# Тип макета обязан встречаться в строках: `# TYPE` без строк — это декларация,
	# а не опись.
	for t in inv.types.keys():
		var named := 0
		for f in inv.rows:
			if f[1] == t:
				named += 1
		assert_bool(named > 0).is_true() \
				.override_failure_message("тип макета «%s» не встречается ни в одной строке описи" % t)


## Каждый путь описи живёт в сцене, каждый ассет кита — на диске.
func test_carrier_inventory_paths_resolve_in_the_scene_and_on_disk() -> void:
	var screen := await _mk_screen(false)
	var inv := _carriers()
	assert_bool(inv.rows.size() >= 33).is_true() \
			.override_failure_message("опись обмелела: строк %d, карты §3 — 33" % inv.rows.size())
	for f in inv.rows:
		var status: String = f[6]
		if f[3] == "-":
			# «узла нет» имеет право стоять только там, где носителя действительно нет.
			assert_that(status).is_equal("no-carrier")
			continue
		for pat in f[3].split("|"):
			var p: String = pat.strip_edges()
			assert_bool(p.begins_with("Center/")).is_true() \
					.override_failure_message("путь в описи обязан быть полным, от корня сцены: " + p)
			assert_bool(_resolve_node(screen, p)).is_true() \
					.override_failure_message(
							"строка %s: узла %s в сцене нет (опись разошлась со сценой)" % [f[0], p])
		for tok in f[4].split("|"):
			var a: String = tok.strip_edges()
			if a.begins_with("hero/"):
				assert_bool(FileAccess.file_exists(_KIT_DIR + a.trim_prefix("hero/"))).is_true() \
						.override_failure_message("строка %s: пикселя %s нет в ките" % [f[0], a])
			elif a.begins_with("icons/") and a.ends_with(".png") and not a.contains("*"):
				assert_bool(FileAccess.file_exists("res://assets/ui/icons/" + a.trim_prefix("icons/"))) \
					.is_true() \
					.override_failure_message("строка %s: иконки %s нет" % [f[0], a])


## Всякая текстура кита экрана обязана стоять в описи: узел с пикселем кита,
## которого в описи нет, — это новый элемент, заведённый мимо карты макета.
func test_carrier_inventory_names_every_hero_kit_texture() -> void:
	var screen := await _mk_screen(false)
	var inv := _carriers()
	var pats := []
	for f in inv.rows:
		if f[3] != "-":
			pats.append_array(f[3].split("|"))
	var prefix := String(screen.get_path()) + "/"
	var seen := 0
	for node in _controls_under(screen, []):
		if not (node is TextureRect):
			continue
		var tex: Texture2D = (node as TextureRect).texture
		if tex == null or not String(tex.resource_path).begins_with(_KIT_DIR):
			continue
		seen += 1
		var p := String(node.get_path()).trim_prefix(prefix)
		var named := false
		for pat in pats:
			if _pattern_matches(p, pat.strip_edges()):
				named = true
				break
		assert_bool(named).is_true() \
				.override_failure_message(
						"узел %s рисуется пикселем кита %s, но в описи его нет" % [
							p, tex.resource_path.get_file()])
	assert_bool(seen > 0).is_true() \
			.override_failure_message("в сцене не нашлось ни одной текстуры кита — предпосылка теста сломана")


## Узел или семейство (`*` — префикс имени на этом уровне) обязано найтись в сцене.
func _resolve_node(screen: Node, path: String) -> bool:
	var node: Node = screen
	for seg in path.split("/"):
		if node == null:
			return false
		if seg.ends_with("*"):
			var pre := seg.trim_suffix("*")
			var found: Node = null
			for child in node.get_children():
				if String(child.name).begins_with(pre):
					found = child
					break
			node = found
		else:
			node = node.get_node_or_null(seg)
	return node != null


func _pattern_matches(node_path: String, pat: String) -> bool:
	var n := node_path.split("/")
	var p := pat.split("/")
	if n.size() != p.size():
		return false
	for i in p.size():
		if p[i].ends_with("*"):
			if not n[i].begins_with(p[i].trim_suffix("*")):
				return false
		elif n[i] != p[i]:
			return false
	return true

extends BaseTest

## ui-mockup-parity 6.4/6.6/6.7 — экран инвентаря отвечает на действие игрока.
## а T-254/T-294/T-295 — что блоки экрана показывают то, что лежит в модели.
##
## До среза экран выбирал сам: «Equip» надевал **первый** предмет сумки (и молча ничего
## не делал, если у первого не находилось слота — `break` стоял вне `if`), «Remove»
## снимал слот, который никто не выбирал (дефолтный WEAPON), «Dispose» съедал **нулевую**
## ячейку. Плюс левая панель собиралась один раз в `_build()` и после экипировки
## продолжала показывать базу: пересчёт характеристик был невидим, хотя носитель
## (`get_battle_bonus`) читал модификаторы живьём.
##
## Тест идёт от действия интерфейса (6.7): нажатие кнопки и клик по ячейке, а не вызов
## внутренних методов — иначе проверка расползается в «тест на метод», каковые и
## держали экран в зелёном состоянии при мёртвых кнопках.

const _SCENE := preload("res://scenes/ui/artifact_inventory_screen.tscn")

const _EQUIP := "Center/Window/Sheet/ItemTip/TipBox/TipButtons/Equip"
const _REMOVE := "Center/Window/Sheet/ItemTip/TipBox/TipButtons/Remove"
const _DISPOSE := "Center/Window/Sheet/ItemTip/TipBox/TipButtons/Dispose"

var _screen: Control = null
var _hero: HeroController = null


func after_test() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.free()
	_screen = null
	if _hero != null and is_instance_valid(_hero):
		_hero.free()
	_hero = null


func _artifact(id: StringName, slot: Artifact.Slot, mods: Dictionary = {}) -> Artifact:
	var art := Artifact.new()
	art.id = id
	art.display_name = String(id)
	art.slot = slot
	art.modifiers = mods
	return art


## Герой с сумкой, собранной тестом: герой живёт в дереве (экран читает `get_tree()`),
## экран инстансится сценой-носителем, как его инстансит `world_ui.tscn`.
func _open(backpack: Array) -> Control:
	_hero = HeroController.new()
	add_child(_hero)
	var inv: HeroInventory = _hero.inventory
	inv.backpack.clear()
	for art in backpack:
		inv.backpack.append(art)
	_screen = _SCENE.instantiate() as Control
	add_child(_screen)
	_screen.set_hero(_hero)
	return _screen


func _press(path: String) -> void:
	var b := _screen.get_node_or_null(path) as Button
	assert_that(b).is_not_null()
	b.pressed.emit()


## Узел предмета в сетке (носитель выбора и маркеров — иконка, а не клетка:
## предмет занимает несколько клеток, а «выбран» относится к предмету).
func _item(i: int) -> Control:
	return _screen.get_node_or_null(
		"Center/Window/Sheet/Stone/Bag/Items/Item_%d" % i) as Control


func _stat(i: int) -> Label:
	return _screen.get_node_or_null("Center/Window/Sheet/Left/StatValue_%d" % i) as Label


## Видимость маркера предмета — это то, что нарисовано: рамка лежит поверх иконки,
## поэтому «узел есть, видим и состоит из четырёх непрозрачных полос» и есть ответ на
## «игрок это видит?», а не на «поле заполнено». Прозрачная полоса не считается: именно
## прозрачность и убила первую версию маркера (замер кадра 2026-10-26).
func _mark_shown(item_index: int, mark: String) -> bool:
	var frame := _item(item_index).get_node_or_null(mark) as Control
	if frame == null or not frame.visible or frame.get_child_count() != 4:
		return false
	for strip in frame.get_children():
		var r := strip as ColorRect
		if r == null or r.color.a < 1.0:
			return false
	return true


func _mark_color(item_index: int, mark: String) -> Color:
	var frame := _item(item_index).get_node_or_null(mark) as Control
	var r := frame.get_child(0) as ColorRect
	return r.color


func _click(item_index: int) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	_item(item_index).gui_input.emit(ev)


## 6.4: надевается выбранный предмет, а не первый в сумке.
func test_equip_uses_the_selected_item_not_the_first_one() -> void:
	var helm := _artifact(&"test_helm", Artifact.Slot.HEAD, {"defense": 2})
	var sword := _artifact(&"test_sword", Artifact.Slot.WEAPON, {"attack": 5})
	_open([helm, sword])

	_screen.select_backpack(1)
	_press(_EQUIP)

	var inv: HeroInventory = _hero.inventory
	var equipped_weapon: Artifact = inv.equipped[Artifact.Slot.WEAPON]
	assert_that(equipped_weapon).is_not_null()
	assert_that(equipped_weapon.id).is_equal(&"test_sword")
	assert_bool(inv.equipped[Artifact.Slot.HEAD] == null).is_true() \
		.override_failure_message("«Equip» надел первый предмет сумки вместо выбранного")
	assert_that(inv.backpack.size()).is_equal(1)


## 6.4: пересчёт характеристик виден на панели — «всего (+модификатор)».
func test_equip_recomputes_the_stat_readout() -> void:
	var armor := _artifact(&"test_armor", Artifact.Slot.TORSO, {"defense": 3})
	_open([armor])
	var before: String = _stat(1).text

	_screen.select_backpack(0)
	_press(_EQUIP)

	var total: int = int(_hero.get_battle_bonus().get("defense", 0))
	var after: String = _stat(1).text
	assert_bool(after != before).is_true() \
		.override_failure_message("панель показывает базу после экипировки: %s → %s" % [before, after])
	assert_bool(after.begins_with(str(total))).is_true() \
		.override_failure_message("ожидается база+бонус вида «%d (+3)», получено «%s»" % [total, after])
	assert_str(after).contains("(+3)")


## 6.4: «Remove» снимает выбранный слот, а не слот по умолчанию.
func test_remove_unequips_the_selected_slot() -> void:
	var sword := _artifact(&"test_sword2", Artifact.Slot.WEAPON, {"attack": 4})
	var helm := _artifact(&"test_helm2", Artifact.Slot.HEAD, {"defense": 1})
	_open([sword, helm])
	_screen.select_backpack(0)
	_press(_EQUIP)
	_screen.select_backpack(0)
	_press(_EQUIP)

	_screen.select_slot(Artifact.Slot.HEAD)
	_press(_REMOVE)

	var inv: HeroInventory = _hero.inventory
	assert_bool(inv.equipped[Artifact.Slot.HEAD] == null).is_true() \
		.override_failure_message("снят не тот слот: Remove игнорирует выбор")
	assert_bool(inv.equipped[Artifact.Slot.WEAPON] != null).is_true() \
		.override_failure_message("Remove с выбранного HEAD уехал в WEAPON")
	assert_that(_screen.selected_backpack_index()).is_equal(inv.backpack.find(helm)) \
		.override_failure_message("снятый предмет должен стать выбранным, а не потеряться")


## 6.4: «Dispose» убирает выбранный предмет, а не нулевую ячейку.
func test_dispose_removes_the_selected_item() -> void:
	var a := _artifact(&"test_a", Artifact.Slot.MISC_A)
	var b := _artifact(&"test_b", Artifact.Slot.MISC_B)
	_open([a, b])

	_screen.select_backpack(1)
	_press(_DISPOSE)

	var inv: HeroInventory = _hero.inventory
	assert_that(inv.backpack.size()).is_equal(1)
	assert_that(inv.backpack[0].id).is_equal(&"test_a") \
		.override_failure_message("Dispose съел нулевую ячейку вместо выбранной")


## 6.6 + 6.4: предмету некуда — он погашен, а нажатие не меняет ничего.
func test_item_without_a_place_is_marked_and_changes_nothing() -> void:
	# Тот же id уже надет — второй экземпляр надеть нельзя (дубликаты, не кольца).
	var first := _artifact(&"test_dup", Artifact.Slot.TORSO, {"defense": 1})
	var second := _artifact(&"test_dup", Artifact.Slot.TORSO, {"defense": 1})
	_open([second])
	_screen.select_backpack(0)
	_press(_EQUIP)
	assert_that(_hero.inventory.backpack.size()).is_equal(0)
	# Второй дубликат кладём в сумку уже после того, как первый надет — сигналом, а не
	# голым `append`: в сетке узел предмета появляется вместе с предметом, а не ждёт
	# своей страницы в постоянной ленте.
	_hero.inventory.backpack.append(second)
	_hero.inventory.backpack_changed.emit()
	# Невыбранный неприменимый предмет — затемнён: признак работает до выбора и до нажатия.
	_screen.select_backpack(-1)
	assert_bool(_mark_shown(0, "BpBlockedMark")).is_true() \
		.override_failure_message("неприменимый предмет ничем не отличается от применимого")
	assert_bool(_mark_shown(0, "BpSelectedMark")).is_false()
	_screen.select_backpack(0)
	var equipped_before: Artifact = _hero.inventory.equipped[Artifact.Slot.TORSO]

	# Оба знака складываются: выбран — и всё ещё некуда.
	assert_bool(_mark_shown(0, "BpSelectedMark")).is_true() \
		.override_failure_message("неприменимый выбранный предмет перестал выглядеть выбранным")
	assert_bool(_mark_shown(0, "BpBlockedMark")).is_true()

	_press(_EQUIP)

	assert_that(_hero.inventory.equipped[Artifact.Slot.TORSO]).is_equal(equipped_before)
	assert_that(_hero.inventory.backpack.size()).is_equal(1) \
		.override_failure_message("неподходящий слот изменил сумку")


## Ячейка сумки принимает клик и становится выбранной — без этого «действие игрока»
## Подобранный вне экрана предмет виден в сумке сразу: экран живёт на сигналах
## инвентаря, а не только на собственном обновлении после своих же кнопок.
func test_backpack_reflects_items_added_outside_the_screen() -> void:
	var a := _artifact(&"test_keep", Artifact.Slot.MISC_A)
	_open([a])
	# В сетке узел предмета появляется вместе с предметом (в отличие от ленты из шести
	# постоянных ячеек), поэтому «до» — это отсутствие узла, а не невидимая иконка.
	assert_that(_item(1)).is_null()

	# Мир поднимает предмет сам — экран ничего не вызывает.
	_hero.inventory.add_to_backpack(_artifact(&"amulet_mourning", Artifact.Slot.NECK))

	var icon := _item(1) as TextureRect
	assert_that(icon).is_not_null()
	assert_bool(icon.visible).is_true() \
		.override_failure_message("сумка не обновилась: экран не слушает backpack_changed")


## Предмет в сетке принимает клик и становится выбранным — без этого «действие игрока»
## существует только в тестах, вызывающих методы напрямую.
func test_click_on_a_backpack_cell_selects_its_item() -> void:
	var a := _artifact(&"test_click_a", Artifact.Slot.MISC_A)
	var b := _artifact(&"test_click_b", Artifact.Slot.MISC_B)
	_open([a, b])

	# Структурная проверка, а не поведение: `gui_input` ниже эмулируется на узле, и мышь
	# через неё не проходит, поэтому `mouse_filter` в этом пути не участвует. Проверяется
	# отдельно и именно так, потому что дефолт `TextureRect` — `MOUSE_FILTER_IGNORE`, и
	# без явной проводки клик по предмету в живой игре молча проваливался бы сквозь клетку
	# (мутант M9 батареи `mut_inventory_marks.sh` был зелёным, пока этой строки не было).
	for i in 2:
		assert_that(_item(i).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP) \
			.override_failure_message(
				"предмет %d не принимает мышь — выбор по клику недоступен" % i)

	# Размер узла — его собственный, а не размер текстуры: иконка обязана закрывать
	# свои клетки (иначе рамка выбора, идущая по краю узла, режется до габарита
	# картинки — T-218 мерил то же на ленте: 342 → 574 пикселя реестрового золота).
	for i in 2:
		assert_that(_item(i).size.x).is_greater_equal(56.0) \
			.override_failure_message("предмет %d не имеет своей ширины" % i)

	_click(1)

	assert_that(_screen.selected_backpack_index()).is_equal(1)
	assert_bool(_mark_shown(1, "BpSelectedMark")).is_true() \
		.override_failure_message("выбранная ячейка не выделена — игрок не видит, к чему «Equip»")
	assert_bool(_mark_shown(0, "BpSelectedMark")).is_false()
	# Цвет маркера — из реестра, а не литерал в экране: иначе палитра расходится с каноном.
	assert_that(_mark_color(1, "BpSelectedMark")).is_equal(ThemeConfig.C_UI_CELL_SELECTED)


## 6.6, вторая половина — «предметы без носителя эффекта». Ключ модификатора,
## которого нет у читателя (`HeroInventory.get_total_modifiers`), — это молча
## несуществующий эффект: игрок читает в описании «+2 к удаче», игра не применяет
## ничего. Тот же класс брака, что немые ключи каталога событий (Q-M79/Q-M81), и
## лечится он так же — замкнутым набором, а не записью в реестре: запись не краснеет,
## тест краснеет. Первый прогон 2026-10-26: набор замкнут, 12 ключей реестра читаются.
func test_artifact_modifier_keys_are_all_read() -> void:
	_open([])
	var total: Dictionary = _hero.inventory.get_total_modifiers()
	var all: Array[Artifact] = Artifacts.get_all()
	# Пустой реестр дал бы зелёный на пустом множестве — проверка обязана быть содержательной.
	assert_that(all.size()).is_greater_equal(1)
	var orphaned: PackedStringArray = PackedStringArray()
	for art in all:
		for key in (art.modifiers as Dictionary).keys():
			if not total.has(String(key)):
				orphaned.append("%s.%s" % [art.id, String(key)])
	assert_that(orphaned.size()).is_equal(0) \
		.override_failure_message(
			"модификаторы без читателя (носитель эффекта не написан): %s"
			% ", ".join(orphaned))


#region содержание экрана: список надетого, кукла, центральная полоса (T-254, T-294, T-295)

const _ROW := "Center/Window/Sheet/Left/EquipRow_%d"
const _ROW_NAME := "Center/Window/Sheet/Left/EquipRow_%d/EquipName_%d"
const _ROW_ICON := "Center/Window/Sheet/Left/EquipRow_%d/EquipIcon_%d"
const _DOLL_ICON := "Center/Window/Sheet/Stone/Doll/DollIcon_%d"


## Предмет списка надетого: габарит 1×1 вместо дефолтных 2×2. Сетка
## снаряжения 4×4, поэтому с дефолтом нельзя надеть больше четырёх вещей,
## а списку размер не важен — проверяются строки, а не упаковка.
func _flat(id: StringName, slot: Artifact.Slot, name_: String = "") -> Artifact:
	var art := Artifact.new()
	art.id = id
	art.display_name = name_ if name_ != "" else String(id)
	art.slot = slot
	art.cells = Vector2i(1, 1)
	return art


func _row(i: int) -> Control:
	return _screen.get_node_or_null(_ROW % i)


func _row_name(i: int) -> Label:
	return _screen.get_node_or_null(_ROW_NAME % [i, i]) as Label


func _row_icon(i: int) -> TextureRect:
	return _screen.get_node_or_null(_ROW_ICON % [i, i]) as TextureRect


func _row_visible(i: int) -> bool:
	var row := _row(i)
	assert_that(row).is_not_null()
	return row.visible


## Надеть первую вещь из сумки — тот же путь, что клик по кнопке «Надеть»:
## `equipped_changed` → `_refresh()` → писатель строк.
func _equip_from_bag() -> void:
	_screen.select_backpack(0)
	(_screen.get_node_or_null(_EQUIP) as Button).pressed.emit()


func _doll_icon(slot: Artifact.Slot) -> TextureRect:
	return _screen.get_node_or_null(_DOLL_ICON % HeroLayout.frame_for_slot(slot)) as TextureRect


## Пустая сумка и пустые слоты: ни одной видимой строки. Пустая строка — это
## нарисованная пустая рамка с пустой подписью, то есть «дырка» в камне.
func test_empty_inventory_hides_every_equip_row() -> void:
	_open([])
	var rows := 0
	while _screen.get_node_or_null(_ROW % rows) != null:
		rows += 1
	assert_that(rows).is_greater(0) \
		.override_failure_message("на сцене нет ни одной EquipRow — генератор и писатель разошлись")
	for i in rows:
		assert_bool(_row_visible(i)).is_false() \
			.override_failure_message("строка %d видима при пустом герое" % i)


## Надетая вещь даёт строку: рамка видима, подпись — имя предмета.
func test_equipped_artifact_shows_a_row_with_its_name() -> void:
	_open([_flat(&"t254_helm", Artifact.Slot.HEAD, "Шлем")])
	_equip_from_bag()
	assert_bool(_row_visible(0)).is_true()
	assert_str(_row_name(0).text).is_equal("Шлем") \
		.override_failure_message("строка есть, но имя предмета не показано")


## Снятие вещи убирает строку — строки не должны оставаться «призраками».
func test_removing_the_artifact_hides_the_row_again() -> void:
	_open([_flat(&"t254_helm", Artifact.Slot.HEAD, "Шлем")])
	_equip_from_bag()
	assert_bool(_row_visible(0)).is_true()
	(_screen.get_node_or_null(
		"Center/Window/Sheet/ItemTip/TipBox/TipButtons/Remove") as Button).pressed.emit()
	assert_bool(_row_visible(0)).is_false() \
		.override_failure_message("вещь снята, а строка осталась")


## Порядок строк совпадает с порядком рамок куклы. Ожидание — обход публичной
## таблицы `HeroLayout.slot_at_frame`, а не приватного метода писателя: иначе
## тест подтверждал бы реализацию самой реализацией. Проверяется здесь не
## «правильный слот», а «строки идут по таблице макета», а не по порядку
## надевания и не по порядку ключей словаря `equipped`.
func test_row_order_follows_the_doll_slots() -> void:
	var helm := _flat(&"t254_helm2", Artifact.Slot.HEAD, "Шлем")
	var sword := _flat(&"t254_sword2", Artifact.Slot.WEAPON, "Меч")
	var ring := _flat(&"t254_ring2", Artifact.Slot.RING_L, "Кольцо")
	# Надеваем в порядке, отличном от порядка макета (кольцо раньше шлема).
	_open([ring, sword, helm])
	_equip_from_bag()
	_equip_from_bag()
	_equip_from_bag()

	var want: Array[String] = []
	for f in HeroLayout.DOLL_SLOTS_N:
		var slot: int = HeroLayout.slot_at_frame(f)
		if slot < 0:
			continue
		var art: Artifact = _hero.inventory.equipped.get(slot, null)
		if art != null:
			want.append(art.display_name)
	assert_that(want.size()).is_equal(3) \
		.override_failure_message("надели не всё: проверка порядка бессмысленна")
	for i in want.size():
		assert_bool(_row_visible(i)).is_true()
		assert_str(_row_name(i).text).is_equal(want[i]) \
			.override_failure_message("строка %d: ждали «%s»" % [i, want[i]])
	assert_bool(_row_visible(want.size())).is_false()


## Переполнение. Слотов в модели 12, а строк в блоке семь (макет A7–D10):
## писатель показывает первые семь по порядку макета, остальные не показываются.
## Число строк тест считывает со сцены, а не хранит константой, — иначе тест
## пережил бы сокращение блока до нуля строк.
func test_more_equipment_than_rows_shows_the_first_seven() -> void:
	var slots: Array = []
	for k in Artifact.Slot.keys():
		if k == "SPELLBOOK":
			continue  # в книгу ничего другого не надевается
		slots.append(Artifact.Slot[k])
	var items: Array = []
	for s in slots.size():
		items.append(_flat(&"t254_slot%d" % s, slots[s], "%d-%s" % [s, slots[s]]))
	_open(items)
	for _i in slots.size():
		_equip_from_bag()

	var worn: int = 0
	for s in slots:
		if _hero.inventory.equipped.get(s, null) != null:
			worn += 1
	assert_that(worn).is_greater(7) \
		.override_failure_message("переполнения не случилось: надето %d" % worn)

	var rows := 0
	while _screen.get_node_or_null(_ROW % rows) != null:
		rows += 1
	assert_that(rows).is_equal(7) \
		.override_failure_message("строк в блоке %d — тест переполнения надо пересчитать" % rows)
	for i in 7:
		assert_bool(_row_visible(i)).is_true()
		assert_str(_row_name(i).text).is_not_empty()


## Иконка строки = иконка предмета; если файла иконки нет, строка остаётся
## подписанной (вещь без иконки — не причина прятать строку целиком).
func test_row_icon_is_the_artifact_file() -> void:
	var real := _flat(&"armor_wonder", Artifact.Slot.TORSO, "Чудо-доспех")
	_open([real])
	_equip_from_bag()
	assert_that(_row_icon(0).texture).is_not_null() \
		.override_failure_message("для id с файлом иконки в строке не показана")


## Ровно та же пара, что и в сетке сумки (T-229): имя обязано влезать в свою
## колонку, 16px — кочующий размер подписей левой панели.
func test_row_label_uses_theme_size_and_clips() -> void:
	_open([_flat(&"t254_helm", Artifact.Slot.HEAD, "Шлем")])
	_equip_from_bag()
	var nm := _row_name(0)
	assert_that(nm).is_not_null()
	assert_int(nm.get_theme_font_size("font_size")).is_equal(16)
	assert_bool(nm.clip_text).is_true() \
		.override_failure_message("подпись не обрезается: длинное имя залезет на соседнюю строку")
	assert_int(nm.text_overrun_behavior).is_equal(TextServer.OVERRUN_TRIM_ELLIPSIS)


## Рамки куклы (T-294). Писатель рамок искал узел `DollSlot_%d/EquipIcon`,
## которого в сцене нет (иконка — **сосед** рамки, `Doll/DollIcon_%d`), и сверял
## `StringName`-метку рамки с enum-целым слота (`v is int` не истина никогда).
## Обе ошибки молчали: сторож `get_node_or_null(...) is TextureRect` и `-1` из
## поиска рамки.
func test_doll_frame_shows_the_equipped_artifact() -> void:
	var real := _flat(&"armor_wonder", Artifact.Slot.TORSO, "Чудо-доспех")
	_open([real])
	_equip_from_bag()
	var icon := _doll_icon(Artifact.Slot.TORSO)
	assert_that(icon).is_not_null() \
		.override_failure_message("у слота TORSO нет рамки куклы — генератор и писатель разошлись")
	assert_bool(icon.visible).is_true() \
		.override_failure_message("надеть надели, а на кукле не видно")
	assert_that(icon.texture).is_not_null()


## Строка списка и рамка куклы обязаны показывать одну и ту же вещь: порядок для
## обоих берётся из `HeroLayout`, а не из двух соседних списков.
func test_row_and_frame_agree_on_the_item() -> void:
	var helm := _flat(&"helm_bulwark", Artifact.Slot.HEAD, "Шлем")
	var boots := _flat(&"boots_levitation", Artifact.Slot.BOOTS, "Сапоги-скороходы")
	_open([helm, boots])
	_equip_from_bag()
	_equip_from_bag()

	assert_str(_row_name(0).text).is_equal("Шлем")
	assert_str(_row_name(1).text).is_equal("Сапоги-скороходы")
	var head_frame := HeroLayout.frame_for_slot(Artifact.Slot.HEAD)
	var boots_frame := HeroLayout.frame_for_slot(Artifact.Slot.BOOTS)
	assert_that(boots_frame).is_greater(head_frame) \
		.override_failure_message("порядок рамок не совпадает с порядком списка")
	for frame in [head_frame, boots_frame]:
		var icon := _screen.get_node_or_null(_DOLL_ICON % frame)
		assert_that(icon).is_not_null()
		assert_bool((icon as TextureRect).visible).is_true() \
			.override_failure_message("рамка %d пуста при надетой вещи" % frame)


#region центральная полоса: мана, школа, навыки, построения (T-295)


## Герой с ненулевым запасом маны: полная шкала совпадает с дефолтом сцены
## (`anchor_right = 1.0`) и для замера не годится.
func _open_hero(mana: int = 5) -> void:
	_hero = HeroController.new()
	add_child(_hero)
	_hero.magic.mana_max = 20
	_hero.magic.mana_current = mana
	_screen = _SCENE.instantiate() as Control
	add_child(_screen)
	_screen.set_hero(_hero)


func _label(path: String) -> Label:
	var n := _screen.get_node_or_null(path)
	assert_that(n).is_not_null() \
		.override_failure_message("узла %s нет на сцене — путь писателя устарел" % path)
	assert_that(n is Label).is_true()
	return n as Label


## Подпись и значение маны пишутся: пустая строка — это то, что оставалось
## до среза (писатель не доходил до узла).
func test_mana_labels_are_written() -> void:
	_open_hero(5)
	assert_str(_label("Center/Window/Sheet/BandMana/Mana_lbl").text).is_not_empty() \
		.override_failure_message("подпись маны пуста: BandMana вне пути писателя")
	var val: String = _label("Center/Window/Sheet/BandMana/Mana_val").text
	assert_str(val).is_equal("5/20") \
		.override_failure_message("запас маны не показан: получено «%s»" % val)


## Школа магии: узел живой, значение — носитель («—» тоже значение, пустой
## строки на кадре быть не может).
func test_mana_school_is_written() -> void:
	_open_hero(20)
	assert_str(_label("Center/Window/Sheet/BandMana/School_lbl").text).is_not_empty()
	assert_str(_label("Center/Window/Sheet/BandMana/School_val").text).is_not_empty()


## Полоса маны = доля от дорожки. Дефолт сцены — 1.0; если писатель не дошёл,
## 5/20 нарисуются как полная шкала (вдвое больше правды).
func test_mana_bar_shows_the_actual_fraction() -> void:
	_open_hero(5)
	var bar := _screen.get_node_or_null("Center/Window/Sheet/BandMana/ManaBar")
	assert_that(bar).is_not_null()
	var ratio: float = (bar as Control).anchor_right
	assert_that(int(round(ratio * 100.0))).is_equal(25) \
		.override_failure_message("полоса маны %.2f вместо 5/20 = 0.25" % ratio)


## Навыки: подпись раздела и иконки ячеек. Иконка ставляется независимо от уровня
## (уровень — отдельная метка), поэтому проверка не зависит от стартового прокаста.
func test_skill_band_is_written() -> void:
	_open_hero(20)
	assert_str(_label("Center/Window/Sheet/BandSkills/Skills_lbl").text).is_not_empty() \
		.override_failure_message("заголовок навыков пуст: BandSkills вне пути писателя")
	var ic := _screen.get_node_or_null("Center/Window/Sheet/BandSkills/Skill_0/SkillIcon")
	assert_that(ic).is_not_null()
	assert_that((ic as TextureRect).texture).is_not_null() \
		.override_failure_message("иконка первого навыка не проставлена")


## Построений в модели нет (T-250) — кнопки стоят заглушками, но заглушка обязана
## объяснять себя игроку: `disabled` + подсказка. Молчачащая кнопка — тот же
## дефект, что и незаполненный узел.
func test_formation_stubs_explain_themselves() -> void:
	_open_hero(20)
	for i in 4:
		var b := _screen.get_node_or_null(
			"Center/Window/Sheet/BandSkills/Formations/Form_%d" % i)
		assert_that(b).is_not_null()
		var btn := b as Button
		assert_that(btn).is_not_null()
		assert_bool(btn.disabled).is_true()
		assert_str(btn.tooltip_text).is_not_empty() \
			.override_failure_message("кнопка построения %d отключена без объяснения" % i)

#endregion

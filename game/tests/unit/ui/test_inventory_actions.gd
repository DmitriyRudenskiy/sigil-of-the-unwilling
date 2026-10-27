extends BaseTest

## ui-mockup-parity 6.4/6.6/6.7 — экран инвентаря отвечает на действие игрока.
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

const _EQUIP := "Center/Window/Right/Equip"
const _REMOVE := "Center/Window/Right/Remove"
const _DISPOSE := "Center/Window/Right/Dispose"

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
		"Center/Window/Right/Grid/Items/Item_%d" % i) as Control


func _stat(i: int) -> Label:
	return _screen.get_node_or_null("Center/Window/Left/StatValue_%d" % i) as Label


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

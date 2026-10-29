# CAPTURE_SETUP для кадра «клетки, предмет и его рамки живут одной решёткой»
# (T-255).
#
# Зачем отдельная фикстура: у тикета два симптома, и оба видны только на опасном
# крае сетки. «Иконки верхнего ряда вылезают за верхнюю границу» — нужен предмет
# в нулевой строке; «рамка шире своих клеток и смещена вправо-вверх» — нужен
# **выбранный** предмет, потому что рамку рисует выбор, а не наведение. Кадр
# T-271/T-256 для этого не годится: там предмет стоит в середине поля.
#
# Экран поднимается не своей сценой, а как `HeroModelWindow` из `main_menu.tscn`
# (единственный носитель экрана героя, D-255). Предмет ставится в нужную клетку
# **после** `set_hero`: `_sync_placements` при первом прогоне расставляет состав
# сама, и ручная клетка, поставленная до неё, была бы перезаписана.
#
# Числа этого возврата — снимок до успокоения layout (песочница `execute_code` не
# умеет `await`), поэтому settled-замер живёт в тесте
# `tests/unit/ui/test_inventory_grid.gd::test_item_and_its_frames_stay_inside_the_field`,
# а сюда смотрим пиксели: клетка под предметом, рамка по краю предмета, ни одного
# вылезшего за поле кадра.
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var screen: Node = scene.get_node_or_null("HeroModelWindow") as Node
if screen == null:
	return {"ok": false, "reason": "окна модели нет в текущей сцене; нужен main_menu.tscn"}

var hero: HeroController = HeroController.new()
screen.add_child(hero)
hero.hero_name = "Герой решётки"
var inv: HeroInventory = hero.inventory
inv.backpack.clear()

var shield := Artifact.new()
shield.id = &"t255_shield"
shield.display_name = "Щит гарнизона"
shield.slot = Artifact.Slot.SHIELD
shield.modifiers = {"defense": 2}
shield.cells = Vector2i(3, 2)
shield.value_gold = 40
shield.description = "Крашеный клён, окованный железом: три клетки вширь, две вниз."
var banner := Artifact.new()
banner.id = &"t255_banner"
banner.display_name = "Штандарт стены"
banner.slot = Artifact.Slot.TORSO
banner.modifiers = {"morale": 2}
banner.cells = Vector2i(2, 3)
banner.value_gold = 90
banner.description = "Полотнище на древке: занимает два столбца вниз до самой границы поля."
inv.backpack.append(shield)
inv.backpack.append(banner)

screen.set_hero(hero)
screen.show()
# Верхняя строка (правый край) и левый нижний угол: у первого предмета верхняя
# кромка совпадает с границей поля, у второго — нижняя.
inv.placements[0] = Vector2i(6, 0)
inv.placements[1] = Vector2i(0, 2)
screen._refresh_grid()
screen.select_backpack(0)

var field: Control = screen.get_node_or_null("Center/Window/Sheet/Stone/Bag") as Control
var items: Node = screen.get_node_or_null("Center/Window/Sheet/Stone/Bag/Items") as Node
var icon: Control = items.get_child(0) as Control if items != null and items.get_child_count() > 0 else null
var mark: Control = icon.get_node_or_null("BpSelectedMark") as Control if icon != null else null
var cell: Control = screen.get_node_or_null(
		"Center/Window/Sheet/Stone/Bag/GridCell_6_0") as Control
var fr: Rect2 = field.get_global_rect() if field != null else Rect2()
var ir: Rect2 = icon.get_global_rect() if icon != null else Rect2()
var cr: Rect2 = cell.get_global_rect() if cell != null else Rect2()
var mr: Rect2 = mark.get_global_rect() if mark != null else Rect2()
return {
	"ok": true,
	"selected": 0,
	"field": str(fr),
	"cell_6_0": str(cr),
	"item": str(ir),
	"mark": str(mr),
	# Рамка обязана совпасть с предметом (не «шире и смещена»), а левый верх
	# предмета — с левым верхом его первой клетки.
	"mark_equals_item": mr == ir,
	"item_on_its_cell": abs(ir.position.x - cr.position.x) < 1.0 \
			and abs(ir.position.y - cr.position.y) < 1.0,
	"item_inside_field": ir.position.x >= fr.position.x - 0.5 \
			and ir.position.y >= fr.position.y - 0.5 \
			and ir.end.x <= fr.end.x + 0.5 and ir.end.y <= fr.end.y + 0.5,
}

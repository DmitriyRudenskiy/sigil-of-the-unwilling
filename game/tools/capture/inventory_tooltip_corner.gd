# CAPTURE_SETUP для кадра «панель предмета отжалась от предмета в углу поля»
# (T-271).
#
# Зачем отдельная фикстура: кадр с предметом в клетке (0,0) доказывает только
# то, что плита уехала из-под куклы. Правило отжимания («предмет, над которым
# открыта подсказка, остаётся видимым») видно только на встречном случае —
# предмет в правом нижнем углу поля, плита обязана уйти в левый верхний.
#
# Фикстура — тело метода (песочница `execute_code`), поэтому без `extends`/`func`
# и без `await`. Предмет ставится в угол **после** `set_hero`: `_sync_placements`
# при первом прогоне расставляет предметы сама, и ручная клетка, поставленная
# до неё, была бы перезаписана.
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var screen: Node = scene.get_node_or_null("HeroModelWindow") as Node
if screen == null:
	return {"ok": false, "reason": "окна модели нет в текущей сцене; нужен main_menu.tscn"}

var hero: HeroController = HeroController.new()
screen.add_child(hero)
hero.hero_name = "Герой подписи"
var inv: HeroInventory = hero.inventory
inv.backpack.clear()

var plate := Artifact.new()
plate.id = &"plate_dawn"
plate.display_name = "Панцирь Рассвета"
plate.slot = Artifact.Slot.TORSO
plate.rarity = Artifact.Rarity.MAJOR
plate.modifiers = {"defense": 3, "morale": 1}
plate.cells = Vector2i(2, 3)
plate.value_gold = 120
plate.description = "Латунь, что помнит рассвет над стеной: тяжёлая, тёплая, верная."
inv.backpack.append(plate)

screen.set_hero(hero)
screen.show()
# Угол поля: сетка 10×5, предмет 2×3 → верхний левый предметной клетки (8,2).
inv.placements[0] = Vector2i(8, 2)
screen._refresh_grid()
screen.select_backpack(0)

var tip: Control = screen.get_node_or_null("Center/Window/Sheet/ItemTip") as Control
var items: Node = screen.get_node_or_null("Center/Window/Sheet/Stone/Bag/Items") as Node
var icon: Control = items.get_child(0) as Control if items != null and items.get_child_count() > 0 else null
var field: Control = screen.get_node_or_null("Center/Window/Sheet/Stone/Bag") as Control
var r: Rect2 = tip.get_global_rect() if tip != null else Rect2()
var icon_r: Rect2 = icon.get_global_rect() if icon != null else Rect2()
return {
	"ok": true,
	"tip_visible": tip != null and tip.visible,
	"rect": str(r),
	"item": str(icon_r),
	"bag": str(field.get_global_rect()) if field != null else "?",
	# Предмет под курсором обязан оставаться видимым: его центр не в плите.
	"item_covered": r.has_point(icon_r.get_center()) if tip != null and icon != null else true,
}

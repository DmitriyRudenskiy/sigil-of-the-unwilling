# CAPTURE_SETUP для кадра «экран героя: карточка предмета на подложке» (T-256).
#
# Отличие от `inventory_selection.gd`: предмет собран **с описанием** и габаритом 2×3.
# Прежняя фикстура клала предметы без описания, и кадр не отвечал на вопрос «виден ли
# текст на подложке»: подложки не было (у варианта ArtifactOutline прозрачное поле),
# а тело описания писалось в скрытый узел `Desc` — тест читал тот же узел и зелёнел.
#
# Экран поднимается не своей сценой, а как `HeroModelWindow` из `main_menu.tscn`
# (единственный носитель экрана героя, D-255); герой создаётся фикстурой, предмет
# кладётся в рюкзак и выбирается — карточка показывается только на выбранном предмете.
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

var helm := Artifact.new()
helm.id = &"helm_of_garrison"
helm.display_name = "Шлем гарнизона"
helm.slot = Artifact.Slot.HEAD
helm.modifiers = {"defense": 2}
inv.equip(helm)

var plate := Artifact.new()
plate.id = &"plate_dawn"
plate.display_name = "Панцирь Рассвета"
plate.slot = Artifact.Slot.TORSO
plate.rarity = Artifact.Rarity.MAJOR
plate.modifiers = {"defense": 3, "morale": 1}
plate.cells = Vector2i(2, 3)
plate.value_gold = 120
plate.description = "Латунь, что помнит рассвет над стеной: тяжёлая, тёплая, верная."

var ring := Artifact.new()
ring.id = &"ring_marsh"
ring.display_name = "Кольцо болота"
ring.slot = Artifact.Slot.RING_L
ring.modifiers = {"knowledge": 1}
ring.value_gold = 20
ring.description = "Пахнет тиной и чужими обещаниями."

inv.backpack.append(plate)
inv.backpack.append(ring)

screen.set_hero(hero)
screen.show()
screen.select_backpack(0)

var tip: Control = screen.get_node_or_null("Center/Window/Sheet/ItemTip") as Control
var body: Label = screen.get_node_or_null("Center/Window/Sheet/ItemTip/TipBox/TipDesc") as Label
var cap: Label = screen.get_node_or_null("Center/Window/Sheet/ItemTip/TipBox/Desc_lbl") as Label
return {
	"ok": true,
	"tip_visible": tip != null and tip.visible,
	"body_visible": body != null and body.visible,
	"body_text": body.text if body != null else "?",
	"caption": cap.text if cap != null else "?",
	"rect": str(tip.get_global_rect()) if tip != null else "?",
}

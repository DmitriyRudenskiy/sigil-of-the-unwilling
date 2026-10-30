# CAPTURE_SETUP для кадра «кукла занимает свой блок» (T-258).
#
# Зачем отдельная фикстура: у T-257 кадр про внешние края зон переноса, кадр
# T-255/T-271 — про поле сумки. Здесь объект другой — TextureRect `Figure` с
# артом `hero/figure.png`, и мерить надо его: совпал ли узел со своим адресным
# блоком E1–G6 и закрывает ли рисунок этот узел.
#
# Экран поднимается не своей сценой, а как `HeroModelWindow` из `main_menu.tscn`
# (единственный носитель экрана героя, D-255). Герой нужен, чтобы кадр был
# рабочим, а не пустым окном.
#
# Про «вдвое меньше»: тикет мерил заглушку. У арта две независимые величины —
# прямоугольник узла (якоря от блока) и доля чернил в самой текстуре. Узел
# может быть верным, а кукла — маленькой, если арт пришёл с прозраческими
# полями, поэтому в кадр кладутся обе.
#
# Числа этого возврата — снимок до успокоения layout (песочница `execute_code`
# не умеет `await`); settled-замер живёт в тесте
# `tests/unit/ui/test_inventory_grid.gd::test_doll_figure_fills_its_address_block`.
#
# Аспект: `stretch_mode = 5` (KEEP_ASPECT_CENTERED) сохраняет пропорции, поэтому
# при аспекте, отличном от 16:9, кукла добирает не всю высоту блока, а всю
# ширину (или наоборот). В кадре — обе доли.
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var screen: Node = scene.get_node_or_null("HeroModelWindow") as Node
if screen == null:
	return {"ok": false, "reason": "окна модели нет в текущей сцене; нужен main_menu.tscn"}

var hero: HeroController = HeroController.new()
screen.add_child(hero)
hero.hero_name = "Герой куклы"
hero.inventory.backpack.clear()
hero.magic.mana_max = 20
hero.magic.mana_current = 12
screen.set_hero(hero)
screen.show()

var blocks: Dictionary = HeroLayout.BLOCKS
var sb: Rect2 = blocks["Stone"]
var fb: Rect2 = blocks["Figure"]
var stone: Control = screen.get_node_or_null("Center/Window/Sheet/Stone") as Control
var fig: TextureRect = screen.get_node_or_null("Center/Window/Sheet/Stone/Figure") as TextureRect
var sr: Rect2 = stone.get_global_rect() if stone != null else Rect2()
var r: Rect2 = fig.get_global_rect() if fig != null else Rect2()
var want := Rect2(
		sr.position + fb.position / sb.size * sr.size, fb.size / sb.size * sr.size)

var img: Image = fig.texture.get_image() if fig != null and fig.texture != null else null
var fill: float = float(img.get_used_rect().size.y) / float(img.get_height()) if img != null else 0.0
var aspect: float = float(img.get_width()) / float(img.get_height()) if img != null else 0.0
var fit_w: float = minf(r.size.x, r.size.y * aspect) / r.size.x if r.size.x > 0.0 else 0.0
var fit_h: float = minf(r.size.y, r.size.x / aspect) / r.size.y if r.size.y > 0.0 else 0.0

# Рамки куклы лежат по анатомии макета (E1–H6), а не по кадру фигуры (E1–G6):
# чернила figure.png занимают 61 % ширины блока, поэтому часть рамок стоит на
# камне левее и правее рисунка. Это наблюдение, а не нарушение: оно и есть
# измеримая часть жалобы тикета «рамки читаются как отдельная решётка».
var outside: Array = []
var bbox := Rect2()
var doll: Node = screen.get_node_or_null("Center/Window/Sheet/Stone/Doll") as Node
if doll != null:
	for c in doll.get_children():
		if not (c is Control) or not (c as Control).visible:
			continue
		var cr: Rect2 = (c as Control).get_global_rect()
		bbox = cr if bbox.size == Vector2.ZERO else bbox.merge(cr)
		if cr.position.x < r.position.x - 0.5 or cr.position.y < r.position.y - 0.5 \
				or cr.end.x > r.end.x + 0.5 or cr.end.y > r.end.y + 0.5:
			outside.append("%s %s" % [str((c as Node).get_name()), str(cr)])

return {
	"ok": true,
	"stone": str(sr),
	"figure": str(r),
	"figure_address_block": str(want),
	# Совпадение узла со своим адресом — по всем четырём сторонам.
	"figure_matches_address": abs(r.position.x - want.position.x) <= 1.0 \
			and abs(r.position.y - want.position.y) <= 1.0 \
			and abs(r.size.x - want.size.x) <= 1.0 \
			and abs(r.size.y - want.size.y) <= 1.0,
	"figure_share_of_stone_height": r.size.y / sr.size.y,
	"texture": "%dx%d" % [img.get_width(), img.get_height()] if img != null else "нет",
	"ink_fill_of_texture": fill,
	"texture_aspect": aspect,
	# Сколько стороны блока закрыто рисунком при сохранённых пропорциях.
	"drawn_share_of_block_width": fit_w,
	"drawn_share_of_block_height": fit_h,
	"expand_mode": fig.expand_mode if fig != null else -1,
	"stretch_mode": fig.stretch_mode if fig != null else -1,
	"doll_frames_bbox": str(bbox),
	"frames_outside_figure_rect": outside,
	"mana": "%d/%d" % [hero.magic.mana_current, hero.magic.mana_max],
}

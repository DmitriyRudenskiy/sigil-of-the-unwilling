# CAPTURE_SETUP для кадра «зоны переноса внутри рамки камня» (T-257).
#
# Зачем отдельная фикстура: у тикета два симптома в разных зонах — полоса маны
# со школой на пергаментном стыке слева и строки навыков за правым краем. Кадр
# T-255/T-271 для сверки не годится: он про поле сумки, а здесь нужны внешние
# края Bands и их детей.
#
# Экран поднимается не своей сценой, а как `HeroModelWindow` из `main_menu.tscn`
# (единственный носитель экрана героя, D-255). Герой нужен, чтобы подписи маны,
# школы и навыков были заполнены: пустые подписи на кадре неотличимы от
# отсутствующих.
#
# Грань камня считается не глазами, а из реестра кита: `hero/panel_stone.png`
# несёт margin 9-slice рамки, и ровно это число читает генератор сцены
# (`_kit_margin("panel_stone")`). На кадре видно, что зона стоит за полосой рамки,
# а не внутри прямоугольника `Stone`.
#
# Числа этого возврата — снимок до успокоения layout (песочница `execute_code`
# не умеет `await`); settled-замер живёт в тесте
# `tests/unit/ui/test_inventory_grid.gd::test_transfer_bands_stay_inside_the_stone_face`.
#
# Про размеры: project.godot даёт растяжку canvas_items + expand, поэтому кадры
# 1920×1080 и 1600×900 — одна и та же раскладка в разных логических px (растр
# разный, прямоугольники совпадают). Отличается аспект: на 1440×1080 камень
# растёт по высоте, а отступ зоны остаётся 40 px — это и проверяют три кадра.
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var screen: Node = scene.get_node_or_null("HeroModelWindow") as Node
if screen == null:
	return {"ok": false, "reason": "окна модели нет в текущей сцене; нужен main_menu.tscn"}

var hero: HeroController = HeroController.new()
screen.add_child(hero)
hero.hero_name = "Герой зон"
hero.inventory.backpack.clear()
# Полоса маны рисуется шириной (anchor_right = запас/максимум, см. _refresh_mana):
# у голого героя максимум 0, полоса пуста и на кадре не отличить «полосы нет» от
# «полоса пуста». Числа 12/20 — те же, что у фикстуры battle_hud_full.
hero.magic.mana_max = 20
hero.magic.mana_current = 12
screen.set_hero(hero)
screen.show()

var raw: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/ui/hero/MANIFEST.json"))
var files: Variant = (raw as Dictionary).get("files", {})
var margin: int = int(((files as Dictionary).get("hero/panel_stone.png", {}) as Dictionary)
		.get("margin", 0))

var stone: Control = screen.get_node_or_null("Center/Window/Sheet/Stone") as Control
var mana: Control = screen.get_node_or_null("Center/Window/Sheet/BandMana") as Control
var skills: Control = screen.get_node_or_null("Center/Window/Sheet/BandSkills") as Control
var sr: Rect2 = stone.get_global_rect() if stone != null else Rect2()
var face: Rect2 = sr.grow(-float(margin))

# Обход детей без рекурсии: тело фикстуры не объявляет функций.
var offenders: Array = []
var stack: Array = []
if mana != null:
	stack.append(mana)
if skills != null:
	stack.append(skills)
while stack.size() > 0:
	var n: Node = stack.pop_back()
	for c in n.get_children():
		if not (c is Control):
			continue
		stack.append(c)
		var r: Rect2 = (c as Control).get_global_rect()
		if r.position.x < face.position.x - 0.5 or r.position.y < face.position.y - 0.5 \
				or r.end.x > face.end.x + 0.5 or r.end.y > face.end.y + 0.5:
			offenders.append("%s %s" % [str((c as Node).get_name()), str(r)])

var mr: Rect2 = mana.get_global_rect() if mana != null else Rect2()
var kr: Rect2 = skills.get_global_rect() if skills != null else Rect2()
return {
	"ok": true,
	"stone": str(sr),
	"stone_border_px": margin,
	"stone_face": str(face),
	"band_mana": str(mr),
	"band_skills": str(kr),
	# Внешний край каждой зоны обязан отстоять от прямоугольника камня не меньше
	# рамки: «границы совпадают» из тикета — это про место за рамкой, а не про rect.
	"gap_left_px": mr.position.x - sr.position.x,
	"gap_right_px": sr.end.x - kr.end.x,
	"gap_top_px": mr.position.y - sr.position.y,
	"mana_inside_face": mr.position.x >= face.position.x - 0.5 \
			and mr.end.x <= face.end.x + 0.5,
	"skills_inside_face": kr.position.x >= face.position.x - 0.5 \
			and kr.end.x <= face.end.x + 0.5,
	"mana": "%d/%d" % [hero.magic.mana_current, hero.magic.mana_max],
	"offenders": offenders,
}

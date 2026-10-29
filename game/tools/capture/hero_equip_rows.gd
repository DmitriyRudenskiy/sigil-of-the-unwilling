# CAPTURE_SETUP для кадра «экран героя: список надетого, рамки куклы, полоса
# маны и навыков» (T-254, T-294, T-295).
#
# Кадр нужен ux-review: до среза нижняя половина левой колонки была пуста
# (писателя строк не было), кукла не показывала надетое (писатель искал узел
# `DollSlot_%d/EquipIcon`, которого в сцене нет, и сверял `StringName`-метку
# рамки с enum-целым слота), а полоса маны и навыки не заполнялись со времён
# переезда блоков под `Sheet` (D-280) — пути писателя остались до-переездными.
# Все три дефекта молчали: сторож `get_node_or_null(...) is Label` не отличает
# отсутствующий узел от незаполненного.
#
# Фикстура поднимает тот же экран, что и `inventory_grid.gd` (standalone-сцена),
# но состоянием проверяет связку «модель надетого → семь строк + рамки куклы».
# Порядок надевания намеренно не совпадает с порядком макета: на кадре видно,
# откуда список берёт порядок, а не просто «все имена на месте».
var screen: Control = get_tree().current_scene as Control
if screen == null or not screen.has_method("set_hero"):
	return {"ok": false, "reason": "текущая сцена — не экран снаряжения"}
var hero: HeroController = HeroController.new()
hero.hero_name = "Тестовый герой"
screen.add_child(hero)
# Запас маны — не полный: полная шкала совпадает с дефолтом сцены
# (`anchor_right = 1.0`) и на кадре не отличима от незаполненной.
hero.magic.mana_max = 20
hero.magic.mana_current = 7
var inv: HeroInventory = hero.inventory
inv.backpack.clear()
# Имена — настоящие строки каталога (иконки у этих id есть, поэтому рамки куклы
# обязаны показаться). Надеваем в порядке, обратном порядку макета.
for pair in [
	["boots_levitation", Artifact.Slot.BOOTS, "Сапоги-скороходы"],
	["ring_vitality", Artifact.Slot.RING_L, "Кольцо живучести"],
	["buckler", Artifact.Slot.SHIELD, "Круглый щит"],
	["armor_wonder", Artifact.Slot.TORSO, "Чудо-доспех"],
	["amulet_mourning", Artifact.Slot.NECK, "Поминательный амулет"],
	["helm_bulwark", Artifact.Slot.HEAD, "Шлем стража"],
]:
	var art := Artifact.from_dict({
		"id": StringName(String(pair[0])),
		"display_name": String(pair[2]),
		"cells": Vector2i(1, 1),
	})
	art.slot = int(pair[1]) as Artifact.Slot
	inv.backpack.append(art)
# Root растянут на весь viewport: standalone-сцена не знает, что хост
# (WorldUILayer) ставит ей полные якоря (тот же приём, что в inventory_grid).
screen.set_anchors_preset(Control.PRESET_FULL_RECT)
screen.set_hero(hero)
# Копия, а не сам рюкзак: `equip` снимает предмет с места, и обход живого
# массива пропускает каждый второй предмет (замер первой версии фикстуры —
# надето 3 из 6, при этом rows и кукла честно показывали три).
for art in inv.backpack.duplicate():
	inv.equip(art)

# Отчёт — то, что видно на кадре, а не то, что лежит в модели.
var rows: Array = []
var i := 0
while true:
	var row: Node = screen.get_node_or_null("Center/Window/Sheet/Left/EquipRow_%d" % i)
	if row == null:
		break
	var nm: Label = screen.get_node_or_null(
		"Center/Window/Sheet/Left/EquipRow_%d/EquipName_%d" % [i, i]) as Label
	var ic: TextureRect = screen.get_node_or_null(
		"Center/Window/Sheet/Left/EquipRow_%d/EquipIcon_%d" % [i, i]) as TextureRect
	rows.append("%d:%s%s%s" % [i,
		"V" if (row as Control).visible else "-",
		"I" if ic != null and ic.texture != null else "-",
		(nm.text if nm != null else "?")])
	i += 1
var frames: Array = []
for f in HeroLayout.DOLL_SLOTS_N:
	var dic: TextureRect = screen.get_node_or_null(
		"Center/Window/Sheet/Stone/Doll/DollIcon_%d" % f) as TextureRect
	if dic != null and dic.visible:
		frames.append(f)
var mana_lbl: Label = screen.get_node_or_null(
	"Center/Window/Sheet/BandMana/Mana_val") as Label
var mana_bar: Control = screen.get_node_or_null(
	"Center/Window/Sheet/BandMana/ManaBar") as Control
var school_lbl: Label = screen.get_node_or_null(
	"Center/Window/Sheet/BandMana/School_val") as Label
var skills_lbl: Label = screen.get_node_or_null(
	"Center/Window/Sheet/BandSkills/Skills_lbl") as Label
var skill_icons := 0
for s in 5:
	var sic: TextureRect = screen.get_node_or_null(
		"Center/Window/Sheet/BandSkills/Skill_%d/SkillIcon" % s) as TextureRect
	if sic != null and sic.texture != null:
		skill_icons += 1
return {
	"ok": true,
	"equipped": rows.size(),
	"rows": " | ".join(PackedStringArray(rows)),
	"doll_frames": str(frames),
	"mana": (mana_lbl.text if mana_lbl != null else "?"),
	"mana_bar": "%.2f" % (mana_bar.anchor_right if mana_bar != null else -1.0),
	"school": (school_lbl.text if school_lbl != null else "?"),
	"skills": (skills_lbl.text if skills_lbl != null else "?"),
	"skill_icons": skill_icons,
}

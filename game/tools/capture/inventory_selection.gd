# CAPTURE_SETUP для кадра «экран артефактов: выбор, маркер неприменимости,
# пересчёт характеристик» (ui-mockup-parity 6.4/6.6/6.7).
#
# Экран живёт в двух носителях: в мире (`world_ui.tscn` → `$WorldUILayer/…`) и в меню
# (`main_menu.tscn` → `$HeroModelWindow`, куда `main_menu.gd:241` подставляет героя
# предпросмотра). Меню выбрано фикстурой потому, что поднимает ровно этот экран без
# бутстрапа мира: память на машине занята чужими сессиями, лишний Godot с миром — это
# ещё порядка двух гигабайт.
#
# Состояние наводится, а не имитируется: один артефакт надет (левая панель обязана
# показать «всего (+бонус)»), в сумке — дубликат надетого (ему некуда: серый) и
# применимый предмет (он выбран: золото). Песочница `execute_code` компилирует этот
# текст как тело метода, поэтому объявлений `func` здесь быть не может; имён операций
# записи файлов тоже нет — ошибки рвут соединение с игрой.
# Пути узлов — после переезда блоков под Sheet (D-280): фикстура читала
# до-переездные `Center/Window/Left/…` и `Center/Window/Right/Grid/Items/…`,
# `get_node_or_null` на несуществующем пути возвращает null, а отчёт фикстуры
# печатал «?» — то есть молчал вместо замера (тот же класс, что и писатели
# экрана, T-295).
var scene: Node = get_tree().current_scene
if scene == null:
	return {"ok": false, "reason": "нет текущей сцены"}
var screen: Node = scene.get_node_or_null("HeroModelWindow") as Node
if screen == null:
	return {"ok": false, "reason": "окна модели нет в текущей сцене"}

var hero: HeroController = HeroController.new()
screen.add_child(hero)
hero.hero_name = "Тестовый герой"
var inv: HeroInventory = hero.inventory
inv.backpack.clear()

var made: Array = []
for spec in [
	["amulet_mourning", Artifact.Slot.NECK, {"spell_power": 4}],
	["amulet_mourning", Artifact.Slot.NECK, {"spell_power": 4}],
	["armor_wonder", Artifact.Slot.TORSO, {"defense": 5}],
]:
	var art := Artifact.new()
	art.id = StringName(String(spec[0]))
	art.display_name = String(spec[0])
	art.slot = int(spec[1]) as Artifact.Slot
	art.modifiers = spec[2] as Dictionary
	made.append(art)

inv.equip(made[0])
inv.backpack.append(made[1])
inv.backpack.append(made[2])

screen.set_hero(hero)
screen.show()
screen.select_backpack(1)

var texts: Array = []
for i in 4:
	var lab: Node = screen.get_node_or_null("Center/Window/Sheet/Left/StatValue_%d" % i) as Node
	texts.append(lab.text if lab != null else "?")
var marks: Array = []
for i in made.size():
	# Узел предмета, а не ячейки ленты: предмет в сетке занимает несколько клеток,
	# и рамка «выбран»/«некуда» относится к предмету.
	var cell: Node = screen.get_node_or_null(
		"Center/Window/Sheet/Stone/Bag/Items/Item_%d" % i) as Node
	if cell == null:
		marks.append("?")
		continue
	var sel: Node = cell.get_node_or_null("BpSelectedMark") as CanvasItem
	var blk: Node = cell.get_node_or_null("BpBlockedMark") as CanvasItem
	marks.append("%d:%s%s %s" % [i,
		"S" if sel != null and sel.visible else "-",
		"B" if blk != null and blk.visible else "-",
		str((cell as Control).get_global_rect())])
# `Exp_val` из фикстуры убран: узла нет ни в одной версии сцены после D-280, и
# сам экран его не пишет — опыта как носителя на экране нет (T-241). Фикстура,
# которая читает несуществующий узел и печатает «?», выглядит как работающая
# проверка, поэтому поле снято, а не «починено» выдуманным путём.
return {
	"ok": true,
	"visible": bool(screen.visible),
	"backpack": inv.backpack.size(),
	"selected": int(screen.selected_backpack_index()),
	"stats": ", ".join(PackedStringArray(texts)),
	"marks": " | ".join(PackedStringArray(marks)),
	"rect": str((screen as Control).get_global_rect()),
}

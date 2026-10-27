# CAPTURE_SETUP для кадра «экран снаряжения героя» (grid-inventory-and-merchant 4.5).
#
# Кадр нужен про ux-review сетки снаряжения: 24 клетки, предмет 1×6 через всю
# сетку, полоса «перевеса». Снимать выдуманной сценой нельзя — раскладку строит
# генератор `scripts/build/gen_inventory_scene.gd`, и спор «сетка влезла в окно»
# решается только живым кадром.
#
# Фикстура — сам экран (`res://scenes/ui/artifact_inventory_screen.tscn`), а не
# кампейн: экран поднимается из `WorldUILayer` и в кампейне, но герой там
# стартовый, а его рюкзак зависит от прогресса. Герой здесь — ручной, с набором
# габаритов, покрывающим все случаи раскладки: 1×6, 2×3, 2×2, 1×2, 1×1 и то, что
# не влезает.
var screen: Control = get_tree().current_scene as Control
if screen == null or not screen.has_method("set_hero"):
	return {"ok": false, "reason": "текущая сцена — не экран снаряжения"}
var hero: HeroController = HeroController.new()
hero.hero_name = "Тестовый герой"
screen.add_child(hero)
var inv: HeroInventory = hero.inventory
for pair in [
	["club", Vector2i(2, 3)],
	["leather_vest", Vector2i(2, 3)],
	["buckler", Vector2i(2, 2)],
	["sandals", Vector2i(1, 2)],
	["amulet_mourning", Vector2i(1, 2)],
	["ring_vitality", Vector2i(1, 1)],
	["helm_sentinel", Vector2i(2, 2)],
	["cloth_pants", Vector2i(2, 3)],
]:
	var art := Artifact.from_dict({"id": StringName(pair[0]), "cells": pair[1]})
	if not inv.add_to_backpack(art):
		# В рюкзак предмет попадает и так: отказ размещения рантайм не прячет,
		# его создаёт только миграция сейва v10 (`_sync_placements` помечает
		# не влезший предмет NO_CELL). Полоса «перевес» поднимается тем же
		# путём, каким её создаёт носитель, а не выдуманным состоянием.
		inv.backpack.append(art)
# Root растянут на весь viewport: standalone-сцена не знает, что хост
# (WorldUILayer) ставит ей полные якоря, и без этого окно прижимается к левому
# верху — кадр показывал бы не экран, а артефакт съёмки.
screen.set_anchors_preset(Control.PRESET_FULL_RECT)
screen.set_hero(hero)
screen.show()
return {
	"ok": true,
	"backpack": inv.backpack.size(),
	"placed": inv.placements.size() if "placements" in inv else -1,
	"grid": str(inv.GRID) if "GRID" in inv else "?",
}

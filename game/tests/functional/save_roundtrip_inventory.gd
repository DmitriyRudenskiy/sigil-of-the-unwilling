extends BaseTest
## grid-inventory-and-merchant 3.3/3.4: позиция предметов переживает save/load,
## а сейв v9 (плоский список) мигрирует в сетку без потери предметов.
##
## «Перевес» — предмет вне сетки (позиция (-1, -1)) — остаётся в backpack,
## продаётся и надевается: миграция не имеет права выбрасывать вещи.

## Первые id реестра: смесь слотов, суммарный габарит заведомо больше 24 клеток.
const V9_IDS: Array = [
	"helm_sentinel", "amulet_mourning", "leather_vest", "club", "stone_axe",
	"iron_sword", "steel_longsword", "runic_blade", "rune_sword",
	"wooden_sword", "buckler", "cloth_pants", "sandals", "ring_vitality",
	"ring_cunning", "lucky_clover",
]

var _mock_nodes: Array[Node] = []


func after_test() -> void:
	for n in _mock_nodes:
		if is_instance_valid(n):
			n.free()
	_mock_nodes.clear()


func _make_hero() -> HeroController:
	var host := Node.new()
	add_child(host)
	_mock_nodes.append(host)
	var hero := HeroController.new()
	host.add_child(hero)
	hero.get_component("Inventory").initialize()
	return hero


func _check_invariant(inv: HeroInventory) -> void:
	var used := {}
	for idx in inv.backpack.size():
		var origin: Vector2i = inv.placements[idx]
		if origin == HeroInventory.NO_CELL:
			continue
		var cells: Vector2i = inv.backpack[idx].resolved_cells()
		for cell in HeroInventory.rect(cells, origin, inv.rotated[idx]):
			assert_bool(used.has(cell)).is_false()
			used[cell] = true


func test_placements_survive_save_load() -> void:
	var hero := _make_hero()
	var inv: HeroInventory = hero.inventory_comp.inventory
	assert_bool(inv.add_to_backpack(Artifact.from_dict({
		"id": &"spear_copper", "slot": Artifact.Slot.WEAPON, "cells": Vector2i(1, 6),
	}))).is_true()
	assert_bool(inv.add_to_backpack(Artifact.from_dict({
		"id": &"amulet_of_the_unwilling", "slot": Artifact.Slot.NECK,
		"cells": Vector2i(1, 2),
	}))).is_true()
	assert_bool(inv.add_to_backpack(Artifact.new(&"ring_of_the_unwilling"))).is_true()
	var before: Array[Vector2i] = inv.placements.duplicate()

	var saved: Dictionary = hero.serialize()
	var hero2 := _make_hero()
	hero2.deserialize(saved)
	var after: HeroInventory = hero2.inventory_comp.inventory

	assert_that(after.backpack.size()).is_equal(3)
	for idx in before.size():
		assert_that(after.placements[idx]).is_equal(before[idx])
	assert_that(after.overflow_count()).is_equal(0)


func test_rotated_placement_survives_save_load() -> void:
	var inv := HeroInventory.new()
	assert_str(inv.place(Artifact.from_dict({
		"id": &"spear_copper", "slot": Artifact.Slot.WEAPON, "cells": Vector2i(1, 6),
	}), Vector2i(0, 0), true)).is_equal("")
	var saved := inv.serialize()

	var after := HeroInventory.new()
	after.deserialize(saved)
	assert_that(after.rotated.size()).is_equal(1)
	assert_bool(after.rotated[0]).is_true()
	assert_that(after.placements[0]).is_equal(Vector2i(0, 0))


func test_v9_flat_list_migrates_without_loss() -> void:
	var sd := SaveData.new()
	var data := _v9_save()
	sd.from_dict(data)

	var hero: HeroController = _make_hero()
	hero.deserialize(sd.hero)
	var inv: HeroInventory = hero.inventory_comp.inventory

	assert_that(inv.backpack.size()).is_equal(V9_IDS.size())
	assert_bool(inv.overflow_count() > 0).is_true()
	assert_that(inv.placements.size()).is_equal(inv.backpack.size())
	_check_invariant(inv)
	# Часть вещей не влезла — но они в рюкзаке, а не в корзине.
	assert_that(inv.backpack.size() - inv.overflow_count()).is_greater(0)


func test_v9_migration_is_idempotent() -> void:
	var sd := SaveData.new()
	var data := _v9_save()
	sd.from_dict(data)
	var first: Array = (sd.hero["inventory"] as Dictionary)["cells"]
	sd.from_dict(sd.to_dict())
	var second: Array = (sd.hero["inventory"] as Dictionary)["cells"]
	assert_that(second).is_equal(first)


func test_overflow_item_is_wearable_and_sellable() -> void:
	var hero := _make_hero()
	var inv: HeroInventory = hero.inventory_comp.inventory
	var data := _v9_save()
	var sd := SaveData.new()
	sd.from_dict(data)
	inv.deserialize(sd.hero["inventory"])

	var idx := -1
	for i in inv.backpack.size():
		if inv.is_overflow(i):
			idx = i
			break
	assert_that(idx).is_not_equal(-1)
	var art: Artifact = inv.backpack[idx]

	# Продаётся: remove_from_backpack — путь лавки, выручка — sell_value.
	var sold: Artifact = inv.remove_from_backpack(idx)
	assert_object(sold).is_equal(art)
	assert_that(HeroInventory.sell_value(art)).is_greater(0)
	assert_that(inv.backpack.size()).is_equal(V9_IDS.size() - 1)
	_check_invariant(inv)

	# И надевается прямо из «перевеса»: слот пуст, клетка не нужна.
	var next_idx := -1
	for i in inv.backpack.size():
		if inv.is_overflow(i):
			next_idx = i
			break
	assert_that(next_idx).is_not_equal(-1)
	var wearable: Artifact = inv.backpack[next_idx]
	assert_bool(inv.equip(wearable)).is_true()
	assert_object(inv.get_equipped(wearable.slot)).is_equal(wearable)
	_check_invariant(inv)


## Сейв формы v9: inventory героя — плоский список id без позиций.
func _v9_save() -> Dictionary:
	return {
		"version": 9,
		"hero": {
			"name": "V9Hero",
			"race": "human",
			"character_class": "warrior",
			"culture": "northern",
			"background": "soldier",
			"inventory": {"equipped": {}, "backpack": V9_IDS.duplicate()},
		},
	}

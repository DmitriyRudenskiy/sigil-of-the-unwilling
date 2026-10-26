class_name HeroInventory
extends RefCounted

signal equipped_changed
signal backpack_changed
signal modifiers_changed

const MAX_BACKPACK := GameNumbers.MAX_BACKPACK_SIZE

## Сетка снаряжения (grid-inventory-and-merchant): вместимость — клетки, а не
## число предметов. Наследственный MAX_BACKPACK остаётся как размер списка в
## тестах/зондах крафта, но вместимость он больше не ограничивает.
const GRID: Vector2i = GameNumbers.INVENTORY_GRID

## «Перевес»: у предмета нет клетки (не влез при миграции v9→v10 или забитой
## сетке). Такой предмет виден, продаётся и надевается — просто не на сетке.
const NO_CELL := Vector2i(-1, -1)

var equipped: Dictionary = {}
var backpack: Array[Artifact] = []

## Размещение i-го предмета backpack: левый верхний угол + поворот на 90°.
## Индекс совпадает с индексом предмета, поэтому backpack остаётся списком
## предметов, а сериализация — двумя параллельными массивами.
var placements: Array[Vector2i] = []
var rotated: Array[bool] = []

## Причина последнего отказа (экран показывает её вместо «не получилось»).
var last_placement_error := ""

## Инвариант: у каждого предмета рюкзака есть запись размещения. Предметы,
## попавшие в backpack в обход place()/add_to_backpack() (миграция сейва,
## тесты крафта), получают клетку здесь; не влезшие — NO_CELL («перевес»).
func _sync_placements() -> void:
	while placements.size() > backpack.size():
		placements.pop_back()
		rotated.pop_back()
	while placements.size() < backpack.size():
		var i := placements.size()
		var fit := first_fit(backpack[i].resolved_cells(), _used_upto(i))
		placements.append(fit["origin"])
		rotated.append(fit["rotated"])


func _init() -> void:
	for slot in Artifact.Slot.values():
		if slot == Artifact.Slot.SPELLBOOK:
			continue
		equipped[slot] = null


# --- Сетка снаряжения (grid-inventory-and-merchant) ---

## Клетки прямоугольника: габарит (при повороте — меняя стороны) со сдвигом.
static func rect(p_cells: Vector2i, origin: Vector2i, rot: bool) -> Array[Vector2i]:
	var c: Vector2i = Vector2i(p_cells.y, p_cells.x) if rot else p_cells
	var out: Array[Vector2i] = []
	for dy in c.y:
		for dx in c.x:
			out.append(origin + Vector2i(dx, dy))
	return out


## Первый свободный прямоугольник: сначала прямой габарит, затем поворот.
## {"origin": Vector2i, "rotated": bool, "reason": String}; NO_CELL — места нет.
static func first_fit(p_cells: Vector2i, used: Dictionary, grid: Vector2i = GRID) -> Dictionary:
	var shapes: Array = [p_cells]
	if p_cells.x != p_cells.y:
		shapes.append(Vector2i(p_cells.y, p_cells.x))
	for index in shapes.size():
		var c: Vector2i = shapes[index]
		if not Artifact.is_valid_cells(c):
			continue
		for oy in range(grid.y - c.y + 1):
			for ox in range(grid.x - c.x + 1):
				var origin := Vector2i(ox, oy)
				var free := true
				for cell in rect(c, origin, false):
					if used.has(cell):
						free = false
						break
				if free:
					return {"origin": origin, "rotated": index == 1, "reason": ""}
	return {
		"origin": NO_CELL,
		"rotated": false,
		"reason": "не хватает места: нужно %d клеток, свободно %d" % [
			p_cells.x * p_cells.y, grid.x * grid.y - used.size()
		],
	}


## Клетки, занятые первыми n предметами (раскладка идёт по порядку).
func _used_upto(n: int) -> Dictionary:
	var used := {}
	for i in mini(n, placements.size()):
		if placements[i] == NO_CELL:
			continue
		for cell in rect(backpack[i].resolved_cells(), placements[i], rotated[i]):
			used[cell] = i
	return used


## Карта занятости: клетка → индекс предмета в backpack.
func occupied_cells() -> Dictionary:
	_sync_placements()
	return _used_upto(backpack.size())


func free_cell_count() -> int:
	return GRID.x * GRID.y - occupied_cells().size()


## Проверка конкретной позиции: "" — ставить можно, иначе — причина.
func can_place(p_cells: Vector2i, origin: Vector2i, rot: bool) -> String:
	var c: Vector2i = Vector2i(p_cells.y, p_cells.x) if rot else p_cells
	if not Artifact.is_valid_cells(c):
		return "габарит должен быть не меньше одной клетки"
	if origin.x < 0 or origin.y < 0 or origin.x + c.x > GRID.x or origin.y + c.y > GRID.y:
		return "предмет не влезает в сетку %d×%d" % [GRID.x, GRID.y]
	var used := occupied_cells()
	for cell in rect(c, origin, false):
		if used.has(cell):
			return "клетка (%d, %d) уже занята" % [cell.x, cell.y]
	return ""


## Подбор места: позиция или причина отказа с числами.
func find_placement(p_cells: Vector2i) -> Dictionary:
	return first_fit(p_cells, occupied_cells())


## Явная постановка (перетаскивание мышью). "" — поставлен.
func place(art: Artifact, origin: Vector2i, rot: bool) -> String:
	if art == null:
		return "предмет не передан"
	var err := can_place(art.resolved_cells(), origin, rot)
	if err != "":
		last_placement_error = err
		return err
	_sync_placements()
	_place_at(art, origin, rot)
	last_placement_error = ""
	backpack_changed.emit()
	return ""


## Снять все предметы с сетки (перезагрузка, сброс героя).
func clear_cells() -> void:
	placements.clear()
	rotated.clear()


## Раскладывает заново всё, что осталось без клетки («перевес»), не трогая
## уже разложенное. Вызывается после загрузки сейва.
func repack() -> void:
	_sync_placements()
	for i in backpack.size():
		if placements[i] != NO_CELL:
			continue
		var fit := first_fit(backpack[i].resolved_cells(), _used_upto(backpack.size()))
		placements[i] = fit["origin"]
		rotated[i] = fit["rotated"]


func is_overflow(idx: int) -> bool:
	_sync_placements()
	return idx >= 0 and idx < placements.size() and placements[idx] == NO_CELL


func overflow_count() -> int:
	_sync_placements()
	var n := 0
	for origin in placements:
		if origin == NO_CELL:
			n += 1
	return n


func has_slot(slot: Artifact.Slot) -> bool:
	return equipped.has(slot) and equipped[slot] != null

func get_equipped(slot: Artifact.Slot) -> Artifact:
	return equipped.get(slot, null)

func can_equip(artifact: Artifact) -> bool:
	if artifact == null:
		return false
	var slot := artifact.slot
	if not equipped.has(slot):
		return false
	if artifact.is_two_handed and equipped.has(Artifact.Slot.SHIELD) and equipped[Artifact.Slot.SHIELD] != null:
		return false
	if artifact.slot == Artifact.Slot.WEAPON and artifact.is_two_handed:
		if equipped[Artifact.Slot.SHIELD] != null:
			return false
	if artifact.slot == Artifact.Slot.SHIELD:
		var weapon: Artifact = equipped.get(Artifact.Slot.WEAPON, null)
		if weapon != null and weapon.is_two_handed:
			return false
	if not artifact.is_ring():
		for other_slot in equipped:
			var other: Artifact = equipped[other_slot]
			if other != null and other.id == artifact.id:
				return false
	return true

func equip(artifact: Artifact, target_slot: Artifact.Slot = Artifact.Slot.RING_L) -> bool:
	if artifact == null:
		return false
	var slot: Artifact.Slot = (
		_pick_ring_slot(target_slot) if artifact.is_ring() else artifact.slot
	)
	if not can_equip_to_slot(artifact, slot):
		return false
	var snap := _snapshot()
	var idx := backpack.find(artifact)
	# Клетки надеваемого предмета освобождаются до того, как под старую вещь
	# ищется место: иначе обмен сам себя вытесняет.
	if idx >= 0:
		_remove_at(idx)
	var old: Artifact = equipped[slot]
	equipped[slot] = artifact
	var ok := old == null or _auto_place(old)
	if ok and artifact.is_two_handed and slot == Artifact.Slot.WEAPON:
		var shield: Artifact = equipped[Artifact.Slot.SHIELD]
		if shield != null:
			if _auto_place(shield):
				equipped[Artifact.Slot.SHIELD] = null
			else:
				ok = false
	if not ok:
		_restore(snap)
		if last_placement_error == "":
			last_placement_error = "снятой вещи нет места в сетке"
		return false
	last_placement_error = ""
	equipped_changed.emit()
	backpack_changed.emit()
	modifiers_changed.emit()
	return true

## Снимает вещь в слот, а прежнего обитателя — в сетку. Отказ не меняет ни
## слоты, ни сетку: состояние собирается на снапшоте и откатывается целиком.
func _snapshot() -> Array:
	_sync_placements()
	return [
		backpack.duplicate(), placements.duplicate(), rotated.duplicate(),
		equipped.duplicate(),
	]


func _restore(snap: Array) -> void:
	backpack.assign(snap[0])
	placements.assign(snap[1])
	rotated.assign(snap[2])
	equipped.clear()
	equipped.merge(snap[3])


func _place_at(art: Artifact, origin: Vector2i, rot: bool) -> void:
	backpack.append(art)
	placements.append(origin)
	rotated.append(rot)


func _remove_at(idx: int) -> Artifact:
	var art := backpack[idx]
	backpack.remove_at(idx)
	placements.remove_at(idx)
	rotated.remove_at(idx)
	return art


## Ставит предмет в первое свободное место; false — предмету не хватило клеток.
func _auto_place(art: Artifact) -> bool:
	var fit := find_placement(art.resolved_cells())
	if str(fit["reason"]) != "":
		last_placement_error = str(fit["reason"])
		return false
	_place_at(art, fit["origin"], fit["rotated"])
	return true


func _pick_ring_slot(slot: Artifact.Slot) -> Artifact.Slot:
	if slot == Artifact.Slot.RING_L or slot == Artifact.Slot.RING_R:
		return slot
	if equipped[Artifact.Slot.RING_L] == null:
		return Artifact.Slot.RING_L
	if equipped[Artifact.Slot.RING_R] == null:
		return Artifact.Slot.RING_R
	return Artifact.Slot.RING_L

func can_equip_to_slot(artifact: Artifact, slot: Artifact.Slot) -> bool:
	if artifact == null:
		return false
	if not equipped.has(slot):
		return false
	if artifact.is_ring() and (slot == Artifact.Slot.RING_L or slot == Artifact.Slot.RING_R):
		return true
	if artifact.slot != slot:
		return false
	if slot == Artifact.Slot.SHIELD:
		var weapon: Artifact = equipped[Artifact.Slot.WEAPON]
		if weapon != null and weapon.is_two_handed:
			return false
	if not artifact.is_ring():
		for other_slot in equipped:
			var other: Artifact = equipped[other_slot]
			if other != null and other.id == artifact.id:
				return false
	return true

func unequip(slot: Artifact.Slot) -> Artifact:
	if not equipped.has(slot):
		return null
	var art: Artifact = equipped[slot]
	if art == null:
		return null
	# Место под снимаемую вещь ищется до того, как слот освобождён: отказ не
	# должен оставлять слот пустым.
	var fit := find_placement(art.resolved_cells())
	if str(fit["reason"]) != "":
		last_placement_error = str(fit["reason"])
		return null
	equipped[slot] = null
	_sync_placements()
	_place_at(art, fit["origin"], fit["rotated"])
	last_placement_error = ""
	equipped_changed.emit()
	backpack_changed.emit()
	modifiers_changed.emit()
	return art

## Цена продажи предмета: половина его стоимости (древний канон 50%).
static func sell_value(art: Artifact) -> int:
	return int(float(art.value_gold) * 0.5)


func add_to_backpack(artifact: Artifact) -> bool:
	if artifact == null:
		return false
	_sync_placements()
	if not artifact.is_ring():
		for art in backpack:
			if art.id == artifact.id:
				return false
		for slot in equipped:
			var eq: Artifact = equipped[slot]
			if eq != null and eq.id == artifact.id:
				return false
	if not _auto_place(artifact):
		return false
	last_placement_error = ""
	backpack_changed.emit()
	return true

func remove_from_backpack(idx: int) -> Artifact:
	if idx < 0 or idx >= backpack.size():
		return null
	var art := _remove_at(idx)
	backpack_changed.emit()
	return art

func sell_artifact(idx: int) -> int:
	var art := remove_from_backpack(idx)
	if art == null:
		return 0
	return int(float(art.value_gold) * 0.5)

func get_total_modifiers() -> Dictionary:
	var total := {
		"attack": 0, "defense": 0, "spell_power": 0, "knowledge": 0,
		"luck": 0, "morale": 0, "movement": 0,
		"stack_hp": 0, "stack_hp_percent": 0.0, "stack_speed": 0,
		"daily_gems": 0, "castle_growth_percent": 0,
	}
	for slot in equipped:
		var art: Artifact = equipped[slot]
		if art == null:
			continue
		total["attack"] += art.get_attack()
		total["defense"] += art.get_defense()
		total["spell_power"] += art.get_spell_power()
		total["knowledge"] += art.get_knowledge()
		total["luck"] += art.get_luck()
		total["morale"] += art.get_morale()
		total["movement"] += art.get_movement()
		total["stack_hp"] += art.get_stack_hp_bonus()
		total["stack_hp_percent"] += art.get_stack_hp_percent()
		total["stack_speed"] += art.get_stack_speed_bonus()
		total["daily_gems"] += art.get_daily_gems()
		total["castle_growth_percent"] += art.get_castle_growth_percent()
	return total

func has_special_effect(effect: StringName) -> bool:
	for slot in equipped:
		var art: Artifact = equipped[slot]
		if art != null and art.special_effect == effect:
			return true
	return false

func serialize() -> Dictionary:
	var equipped_ids := {}
	for slot in equipped:
		var art: Artifact = equipped[slot]
		if art == null:
			equipped_ids[slot] = &""
		elif Artifact.is_registry_artifact(art):
			equipped_ids[slot] = art.id
		else:
			equipped_ids[slot] = art.to_dict()  # крафт: полный словарь
	var backpack_ids: Array = []
	for art in backpack:
		if Artifact.is_registry_artifact(art):
			backpack_ids.append(str(art.id))
		else:
			backpack_ids.append(art.to_dict())  # крафт: полный словарь
	# Позиции идут параллельно списку: [x, y, поворот]; -1 — «перевес».
	_sync_placements()
	var positions: Array = []
	for i in backpack.size():
		positions.append([placements[i].x, placements[i].y, 1 if rotated[i] else 0])
	return {"equipped": equipped_ids, "backpack": backpack_ids, "cells": positions}

func deserialize(data: Dictionary) -> void:
	for slot in equipped:
		equipped[slot] = null
	backpack.clear()
	clear_cells()
	var art_reg: Node = Services.resolve(&"artifacts")
	if data.has("equipped"):
		for slot_key in data["equipped"]:
			var slot: int = int(slot_key)
			if not equipped.has(slot):
				push_warning("HeroInventory: unknown slot %s" % slot_key)
				continue
			var entry = data["equipped"][slot_key]
			if entry is Dictionary:
				# Крафтовый предмет: полный словарь (scarce-crafting-system).
				equipped[slot] = Artifact.from_dict(entry)
			elif entry != "" and entry != null:
				var art: Artifact = art_reg.get_by_id(StringName(entry))
				if art != null:
					equipped[slot] = art
	if data.has("backpack"):
		for entry in data["backpack"]:
			if entry is Dictionary:
				# Крафтовый предмет: полный словарь (scarce-crafting-system).
				backpack.append(Artifact.from_dict(entry))
			elif entry != "" and entry != null:
				var art: Artifact = art_reg.get_by_id(StringName(entry))
				if art != null:
					backpack.append(art)
	# Позиции из сейва v10; где записи нет или она вне сетки — предмет уходит
	# в «перевес» и получает клетку только если она реально свободна.
	var positions = data.get("cells", [])
	if positions is Array:
		for i in mini(positions.size(), backpack.size()):
			var raw = positions[i]
			var origin := NO_CELL
			var rot := false
			if raw is Array and raw.size() >= 2 and int(raw[0]) >= 0 and int(raw[1]) >= 0:
				origin = Vector2i(int(raw[0]), int(raw[1]))
				if raw.size() > 2:
					rot = int(raw[2]) != 0
			placements.append(origin)
			rotated.append(rot)
	repack()
	equipped_changed.emit()
	backpack_changed.emit()
	modifiers_changed.emit()

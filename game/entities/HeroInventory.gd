class_name HeroInventory
extends RefCounted
## Inventory of a hero: 11 equipped slots + backpack of 16.

const ServiceLocator = preload("res://core/ServiceLocator.gd")

signal equipped_changed
signal backpack_changed
signal modifiers_changed

const MAX_BACKPACK := GameSettings.MAX_BACKPACK_SIZE

var equipped: Dictionary = {}  # Artifact.Slot -> Artifact
var backpack: Array[Artifact] = []


func _init() -> void:
	for slot in Artifact.Slot.values():
		if slot == Artifact.Slot.SPELLBOOK:
			continue
		equipped[slot] = null


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

	var idx := backpack.find(artifact)

	if artifact.is_ring():
		var slot := _pick_ring_slot(target_slot)
		var old: Artifact = equipped[slot]

		if not _can_put_back(old, idx):
			return false

		if idx >= 0:
			backpack.remove_at(idx)

		equipped[slot] = artifact

		if old != null:
			backpack.append(old)

		equipped_changed.emit()
		backpack_changed.emit()
		modifiers_changed.emit()
		return true

	var slot: Artifact.Slot = artifact.slot
	if not can_equip_to_slot(artifact, slot):
		return false

	if idx >= 0:
		backpack.remove_at(idx)
	var old: Artifact = equipped[slot]
	equipped[slot] = artifact
	if old != null:
		backpack.append(old)
	if artifact.is_two_handed and slot == Artifact.Slot.WEAPON:
		var shield: Artifact = equipped.get(Artifact.Slot.SHIELD, null)
		if shield != null:
			equipped[Artifact.Slot.SHIELD] = null
			backpack.append(shield)
	equipped_changed.emit()
	backpack_changed.emit()
	modifiers_changed.emit()
	return true


func _pick_ring_slot(slot: Artifact.Slot) -> Artifact.Slot:
	if slot == Artifact.Slot.RING_L or slot == Artifact.Slot.RING_R:
		return slot
	if equipped[Artifact.Slot.RING_L] == null:
		return Artifact.Slot.RING_L
	if equipped[Artifact.Slot.RING_R] == null:
		return Artifact.Slot.RING_R
	return Artifact.Slot.RING_L


func _can_put_back(old: Artifact, remove_idx: int) -> bool:
	if old == null:
		return true
	# If the item already lies in the backpack, removing it frees a slot.
	if remove_idx >= 0:
		return true
	return backpack.size() < MAX_BACKPACK


func can_equip_to_slot(artifact: Artifact, slot: Artifact.Slot) -> bool:
	if artifact == null:
		return false
	if not equipped.has(slot):
		return false
	if artifact.is_ring() and (slot == Artifact.Slot.RING_L or slot == Artifact.Slot.RING_R):
		return true
	if artifact.slot != slot:
		return false
	# Двуручное оружие разрешено, даже если надет щит — equip() снимет щит сам.
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
	if backpack.size() >= MAX_BACKPACK:
		return null
	equipped[slot] = null
	backpack.append(art)
	equipped_changed.emit()
	backpack_changed.emit()
	modifiers_changed.emit()
	return art


func add_to_backpack(artifact: Artifact) -> bool:
	if artifact == null:
		return false
	if backpack.size() >= MAX_BACKPACK:
		return false
	if not artifact.is_ring():
		for art in backpack:
			if art.id == artifact.id:
				return false
		for slot in equipped:
			var eq: Artifact = equipped[slot]
			if eq != null and eq.id == artifact.id:
				return false
	backpack.append(artifact)
	backpack_changed.emit()
	return true


func remove_from_backpack(idx: int) -> Artifact:
	if idx < 0 or idx >= backpack.size():
		return null
	var art := backpack[idx]
	backpack.remove_at(idx)
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
		equipped_ids[slot] = art.id if art != null else ""
	var backpack_ids: Array = []
	for art in backpack:
		backpack_ids.append(str(art.id))
	return {"equipped": equipped_ids, "backpack": backpack_ids}


func deserialize(data: Dictionary) -> void:
	for slot in equipped:
		equipped[slot] = null
	backpack.clear()
	var art_reg: Node = ServiceLocator.resolve(null, &"artifacts")
	if data.has("equipped"):
		# Ключи могут быть String (внешний save) или int (наш serialize) — без типизации
		for slot_key in data["equipped"]:
			var slot: int = int(slot_key)
			if not equipped.has(slot):
				push_warning("HeroInventory: unknown slot %s" % slot_key)
				continue
			var id = data["equipped"][slot_key]
			if id != "" and id != null:
				var art: Artifact = art_reg.get_by_id(StringName(id))
				if art != null:
					equipped[slot] = art
	if data.has("backpack"):
		for id in data["backpack"]:
			if id != "" and id != null:
				var art: Artifact = art_reg.get_by_id(StringName(id))
				if art != null:
					backpack.append(art)
	equipped_changed.emit()
	backpack_changed.emit()
	modifiers_changed.emit()


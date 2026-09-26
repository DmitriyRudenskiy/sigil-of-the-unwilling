class_name HeroInventoryComponent
extends HeroComponent

var inventory: HeroInventory = HeroInventory.new()

signal equipped_changed()
signal backpack_changed()
signal modifiers_changed()

func setup_hero(hero: HeroController) -> void:
	super(hero)
	inventory.equipped_changed.connect(equipped_changed.emit)
	inventory.backpack_changed.connect(backpack_changed.emit)
	inventory.modifiers_changed.connect(modifiers_changed.emit)

func get_total_modifiers() -> Dictionary:
	return inventory.get_total_modifiers()

func has_special_effect(effect: StringName) -> bool:
	return inventory.has_special_effect(effect)

func has_slot(slot: Artifact.Slot) -> bool:
	return inventory.has_slot(slot)

func get_equipped(slot: Artifact.Slot) -> Artifact:
	return inventory.get_equipped(slot)

func equip(artifact: Artifact, target_slot: Artifact.Slot = Artifact.Slot.RING_L) -> bool:
	return inventory.equip(artifact, target_slot)

func unequip(slot: Artifact.Slot) -> Artifact:
	return inventory.unequip(slot)

func add_to_backpack(artifact: Artifact) -> bool:
	return inventory.add_to_backpack(artifact)

func remove_from_backpack(idx: int) -> Artifact:
	return inventory.remove_from_backpack(idx)

func sell_artifact(idx: int) -> int:
	return inventory.sell_artifact(idx)

func get_equipped_dict() -> Dictionary:
	return inventory.equipped

func get_backpack() -> Array[Artifact]:
	return inventory.backpack

func serialize() -> Dictionary:
	return {"inventory": inventory.serialize()}

func deserialize(data: Dictionary) -> void:
	inventory.deserialize(data.get("inventory", {}))

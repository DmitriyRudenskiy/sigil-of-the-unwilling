extends Node
class_name WorldInteractionController
## Handles chest contact, resource collection, and chest dialog.

var hero: HeroController
var spawner: WorldSpawner
var chest_dialog: ArtifactChestDialog
var world_delta: WorldStateDelta = null


func setup(h: HeroController, s: WorldSpawner, d: ArtifactChestDialog) -> void:
	hero = h
	spawner = s
	chest_dialog = d


func connect_chest_signals() -> void:
	if chest_dialog:
		chest_dialog.choice_made.connect(_on_chest_choice)


func check_chest_contact(cell: Vector2i) -> void:
	if spawner == null or chest_dialog == null:
		return

	var chest := spawner.get_chest_at(cell)
	if chest != null and not chest.is_opened:
		chest_dialog.open(chest)
		return

	for nb in HexUtils.get_all_neighbors(cell):
		chest = spawner.get_chest_at(nb)
		if chest != null and not chest.is_opened:
			chest_dialog.open(chest)
			return


func _on_chest_choice(choice: String, chest: ArtifactChest) -> void:
	if chest == null:
		return

	match choice:
		"take":
			if chest.artifact != null:
				if hero.inventory.add_to_backpack(chest.artifact):
					GameLogger.inventory("Picked up artifact: %s" % chest.artifact.display_name)
				else:
					GameLogger.inventory("Backpack full!")
		"gold":
			var res_dict: Dictionary = hero.resources.resources
			res_dict["gold"] = int(res_dict.get("gold", 0)) + chest.gold_reward
			hero.resources.resources_changed.emit(res_dict)
			GameLogger.world("Took %d gold from chest" % chest.gold_reward)

	chest.open()
	if spawner:
		spawner.remove_chest_at(chest.cell)

	if world_delta:
		world_delta.add_opened_chest(chest.cell)


func collect_resource_at(cell: Vector2i) -> bool:
	if spawner:
		var removed := spawner.remove_resource_at(cell)
		if removed and world_delta:
			world_delta.add_removed_resource(cell)
		return removed
	return false


func capture_village_at(cell: Vector2i) -> void:
	if spawner and spawner.capture_village(cell):
		if world_delta:
			world_delta.add_village(cell)


func pickup_scroll_at(cell: Vector2i) -> void:
	if spawner == null or hero == null:
		return
	var spell_id: StringName = spawner.get_scroll_at(cell)
	if spell_id == &"":
		return
	ScrollRules.apply_pickup(hero.magic, spell_id)
	spawner.remove_scroll_at(cell)

	if world_delta:
		world_delta.add_removed_scroll(cell)

	GameLogger.world("Picked up scroll: %s" % spell_id)

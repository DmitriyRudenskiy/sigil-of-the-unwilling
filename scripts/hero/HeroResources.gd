extends Node
class_name HeroResources
## Hero resources: pickup, daily effects, end-of-turn logic.

signal resources_changed(resources: Dictionary)

var inventory: HeroInventory:
	set(v): inventory = v

var resources := {
	"wood": 10, "mercury": 2, "ore": 10, "sulfur": 2,
	"crystal": 2, "gems": 2, "gold": 500,
}


func _ready() -> void:
	inventory.modifiers_changed.connect(_on_inventory_changed)


func pickup_resource(res_type: int) -> void:
	var names := ["wood", "mercury", "ore", "sulfur", "crystal", "gems", "gold"]
	if res_type < names.size():
		var amount := 5 if res_type < 6 else 50
		resources[names[res_type]] += amount
		print("[Hero] Picked up +%d %s" % [amount, names[res_type]])
		resources_changed.emit(resources)


func apply_daily_effects() -> void:
	var mods := inventory.get_total_modifiers()
	var daily_gems: int = int(mods.get("daily_gems", 0))
	if daily_gems > 0:
		resources["gems"] = resources.get("gems", 0) + daily_gems
		resources_changed.emit(resources)


func get_dict() -> Dictionary:
	return resources


func set_from_dict(data: Dictionary) -> void:
	resources = data


func serialize() -> Dictionary:
	return resources.duplicate()


func deserialize(data: Dictionary) -> void:
	resources.clear()
	for key: String in data:
		resources[key] = int(data[key])


func _on_inventory_changed() -> void:
	resources_changed.emit(resources)

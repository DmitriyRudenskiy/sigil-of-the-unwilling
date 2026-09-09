
extends Node
class_name HeroResources

const ResourceType = preload("res://scripts/data/ResourceType.gd")

signal resources_changed(resources: Dictionary)

var inventory: HeroInventory:
	set(v): inventory = v

var resources: Dictionary = {}

func _init() -> void:
	for id in ResourceType.classic_ids():
		resources[id] = ResourceType.start_amount(id)

func _ready() -> void:
	inventory.modifiers_changed.connect(_on_inventory_changed)

func pickup_resource(res_type: int) -> void:
	if not ResourceType.is_valid(res_type):
		return
	var amount := ResourceType.pickup_amount(res_type)
	resources[res_type] = int(resources.get(res_type, 0)) + amount
	GameLogger.hero("Picked up +%d %s" % [amount, ResourceType.to_name(res_type)])
	resources_changed.emit(resources)

func apply_daily_effects() -> void:
	var mods := inventory.get_total_modifiers()
	var daily_gems: int = int(mods.get("daily_gems", 0))
	if daily_gems > 0:
		resources[ResourceType.ID.GEMS] = int(resources.get(ResourceType.ID.GEMS, 0)) + daily_gems
		resources_changed.emit(resources)

func get_dict() -> Dictionary:
	return resources

func set_from_dict(data: Dictionary) -> void:
	resources = data

func serialize() -> Dictionary:
	var out: Dictionary = {}
	for id in resources:
		out[ResourceType.to_key(int(id))] = int(resources[id])
	return out

func deserialize(data: Dictionary) -> void:
	resources.clear()
	for key in data:
		var id: int = int(key) if key is int else ResourceType.from_name(key)
		if ResourceType.is_valid(id):
			resources[id] = int(data[key])

func to_string_dict() -> Dictionary:
	return serialize()

func _on_inventory_changed() -> void:
	resources_changed.emit(resources)

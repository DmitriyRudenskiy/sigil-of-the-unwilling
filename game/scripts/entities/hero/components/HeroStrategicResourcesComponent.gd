class_name HeroStrategicResourcesComponent
extends HeroComponent

var strategic: HeroStrategicResources = HeroStrategicResources.new()

signal strategic_resources_changed(resources: Dictionary)

func setup_hero(hero: HeroController) -> void:
	super(hero)
	strategic.strategic_resources_changed.connect(strategic_resources_changed.emit)

func initialize() -> void:
	strategic.init_from_registry(Services.resolve(&"resources"))

func set_strategic(v: HeroStrategicResources) -> void:
	strategic = v

func get_all() -> Dictionary:
	return strategic.get_all()

func set_all(data: Dictionary) -> void:
	strategic.set_all(data)

func add(id: StringName, amount: int) -> int:
	return strategic.add(id, amount)

func remove(id: StringName, amount: int) -> int:
	return strategic.remove(id, amount)

func end_turn() -> void:
	strategic._add_internal(
		ResourceType.to_name(ResourceType.ID.WOOD), GameNumbers.RESOURCE_AUTO_WOOD)
	strategic._add_internal(
		ResourceType.to_name(ResourceType.ID.STONE), GameNumbers.RESOURCE_AUTO_STONE)
	strategic.emit_changed()

func serialize() -> Dictionary:
	return {"strategic_resources": strategic.get_all()}

func deserialize(data: Dictionary) -> void:
	strategic.set_all(data.get("strategic_resources", strategic.get_all()))

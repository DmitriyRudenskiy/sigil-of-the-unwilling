class_name HeroResourcesComponent
extends HeroComponent

var _controller: HeroResources = null

signal resources_changed(resources: Dictionary)

func setup_hero(hero: HeroController) -> void:
	super(hero)
	_controller = HeroResources.new()
	_controller.name = "Resources"
	add_child(_controller)

func initialize() -> void:
	var inv_comp := _hero.get_component("Inventory") as HeroInventoryComponent
	if inv_comp != null:
		_controller.inventory = inv_comp.inventory
	if not _controller.resources_changed.is_connected(resources_changed.emit):
		_controller.resources_changed.connect(resources_changed.emit)

func set_controller(v: HeroResources) -> void:
	_controller = v

func pickup_resource(res_type: int) -> void:
	_controller.pickup_resource(res_type)

func apply_daily_effects() -> void:
	_controller.apply_daily_effects()

func get_dict() -> Dictionary:
	return _controller.resources

func get_resources() -> Dictionary:
	return _controller.resources

func set_from_dict(data: Dictionary) -> void:
	_controller.resources = data

func end_turn() -> void:
	apply_daily_effects()

func serialize() -> Dictionary:
	return {"resources": _controller.serialize()}

func deserialize(data: Dictionary) -> void:
	_controller.deserialize(data.get("resources", {}))

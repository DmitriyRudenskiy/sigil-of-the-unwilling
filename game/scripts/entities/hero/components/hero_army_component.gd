class_name HeroArmyComponent
extends HeroComponent

var _controller: HeroArmyController = null

func setup_hero(hero: HeroController) -> void:
	super(hero)
	_controller = HeroArmyController.new()
	_controller.name = "Army"
	add_child(_controller)

func initialize() -> void:
	_controller.setup(Services.resolve(&"units"), _hero.solo_start)

func set_controller(v: HeroArmyController) -> void:
	_controller = v

func get_army() -> Array[UnitStack]:
	return _controller.army

func get_army_for_battle() -> Array[UnitStack]:
	return _controller.get_army_for_battle()

func apply_battle_results(surviving_army: Array[UnitStack]) -> void:
	_controller.apply_battle_results(surviving_army)

func serialize() -> Dictionary:
	return {"army": _controller.serialize()}

func deserialize(data: Dictionary) -> void:
	_controller.deserialize(data.get("army", []))

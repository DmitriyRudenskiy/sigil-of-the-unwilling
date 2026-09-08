class_name WorldHeroManager
extends RefCounted

# R1: инициализация героя и делегирование смерти/преемственности
# вынесены из WorldController (SRP).

var _hero: Node = null
var _hero_lifecycle = null


func setup(hero: Node) -> void:
	_hero = hero


func setup_lifecycle(lifecycle) -> void:
	_hero_lifecycle = lifecycle


func get_lifecycle():
	return _hero_lifecycle


func finit_hero(loaded_save: SaveData, map_gen: Node) -> void:
	_hero.setup(map_gen)
	if loaded_save != null:
		_hero.deserialize(loaded_save.hero)
		if map_gen.has_valid_tilemap():
			_hero.position = map_gen.map_to_local(_hero.current_cell)


func get_hero() -> HeroController:
	return _hero


func set_hero(hero: HeroController) -> void:
	_hero = hero


func on_hero_died(cause: StringName) -> void:
	if _hero_lifecycle != null:
		_hero_lifecycle.on_hero_died(cause)


func is_death_sequence_open() -> bool:
	return _hero_lifecycle != null and _hero_lifecycle.is_death_sequence_open()


func plan_succession(deceased: HeroController) -> HeroController:
	if _hero_lifecycle == null:
		return null
	return _hero_lifecycle._plan_succession(deceased)


func find_resurrection_city(deceased: HeroController) -> City:
	if _hero_lifecycle == null:
		return null
	return _hero_lifecycle._find_resurrection_city(deceased)


func on_resurrection_chosen() -> void:
	if _hero_lifecycle != null:
		_hero_lifecycle._on_resurrection_chosen()


func execute_succession() -> void:
	if _hero_lifecycle != null:
		_hero_lifecycle._execute_succession()

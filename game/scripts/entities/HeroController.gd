class_name HeroController
extends Node2D
## Тонкий координатор (TASK_15). Вся логика вынесена в компоненты
## (scripts/entities/hero/components/). Контроллер отвечает только за:
##   1. Регистрацию и инициализацию компонентов
##   2. Маршрутизацию сигналов между компонентами
##   3. Сериализацию/десериализацию (делегирование)
##   4. Обратную совместимость через свойства-аксессоры
##
## Компоненты создаются в _init (не в _ready), чтобы аксессоры
## (hero.magic, hero.inventory, hero.path_id и т.д.) работали сразу
## после new() — до входа в дерево (тесты, фабрики, SuccessionController).

const _Platform = preload("res://scripts/core/Platform.gd")

# ── Сигналы (проброс из компонентов) ──
signal hero_moved(cell: Vector2i)
signal movement_finished(cell: Vector2i)
signal hero_entered_village(cell: Vector2i)
signal movement_points_changed(current: float, max_val: float)
signal resources_changed(resources: Dictionary)
signal path_previewed(text: String)
signal planned_route_changed(committed: bool)
signal strategic_resources_changed(resources: Dictionary)
signal skills_changed()
signal tools_changed()
signal time_changed(hour: float)

# ── Реестр компонентов ──
var _components: Dictionary = {}
var _tween: Tween = null
var _setup_done: bool = false

# ── Внешние зависимости ──
var city_manager: CityManager = null

# ── Компоненты (создаются в _init) ──
var movement_comp: HeroMovementComponent
var army_comp: HeroArmyComponent
var magic_comp: HeroMagicComponent
var resources_comp: HeroResourcesComponent
var visual_comp: HeroVisualComponent
var needs_comp: HeroNeedsComponent
var inventory_comp: HeroInventoryComponent
var skills_comp: HeroSkillsComponent
var tools_comp: HeroToolsComponent
var time_comp: HeroTimeComponent
var strategic_comp: HeroStrategicResourcesComponent
var followers_comp: HeroFollowersComponent
var combat_comp: HeroCombatComponent
var stats_comp: HeroStatsComponent

# ═══════════════════════════════════════════
#  ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════

func _init() -> void:
	_register_components()
	_wire_cross_component_signals()
	# Инвентарь подвязываем к ресурсам сразу (до входа в дерево),
	# как это делал старый _ready: resources.inventory = inventory.
	resources_comp.initialize()

func _ready() -> void:
	# Компоненты уже зарегистрированы в _init; метод оставлен для
	# совместимости (тесты вызывают h._ready() явно).
	pass

func _register_components() -> void:
	movement_comp = _add_component("Movement", HeroMovementComponent.new())
	army_comp = _add_component("Army", HeroArmyComponent.new())
	magic_comp = _add_component("Magic", HeroMagicComponent.new())
	resources_comp = _add_component("Resources", HeroResourcesComponent.new())
	visual_comp = _add_component("Visual", HeroVisualComponent.new())
	needs_comp = _add_component("Needs", HeroNeedsComponent.new())
	inventory_comp = _add_component("Inventory", HeroInventoryComponent.new())
	skills_comp = _add_component("Skills", HeroSkillsComponent.new())
	tools_comp = _add_component("Tools", HeroToolsComponent.new())
	time_comp = _add_component("Time", HeroTimeComponent.new())
	strategic_comp = _add_component("StrategicResources", HeroStrategicResourcesComponent.new())
	followers_comp = _add_component("Followers", HeroFollowersComponent.new())
	combat_comp = _add_component("Combat", HeroCombatComponent.new())
	stats_comp = _add_component("Stats", HeroStatsComponent.new())

func _add_component(comp_name: String, comp: HeroComponent) -> HeroComponent:
	comp.name = comp_name
	add_child(comp)
	comp.setup_hero(self)
	_components[comp_name] = comp
	return comp

func _wire_cross_component_signals() -> void:
	# Движение → Визуал
	movement_comp.facing_changed.connect(visual_comp.set_facing)
	movement_comp.request_idle_animation.connect(visual_comp.idle_animation)
	movement_comp.request_hide_path_visual.connect(visual_comp.clear_path_visual)
	movement_comp.request_show_marker.connect(visual_comp.show_marker)
	movement_comp.request_set_position.connect(_on_set_position)
	movement_comp.move_requested.connect(_on_move_requested)
	movement_comp.request_kill_tween.connect(_kill_tween)
	movement_comp.request_time_update.connect(time_comp.spend_move_points)
	movement_comp.request_resource_pickup.connect(resources_comp.pickup_resource)

	# Проброс сигналов наверх
	movement_comp.hero_moved.connect(hero_moved.emit)
	movement_comp.movement_finished.connect(movement_finished.emit)
	movement_comp.hero_entered_village.connect(hero_entered_village.emit)
	movement_comp.movement_points_changed.connect(movement_points_changed.emit)
	movement_comp.path_previewed.connect(path_previewed.emit)
	movement_comp.planned_route_changed.connect(planned_route_changed.emit)
	resources_comp.resources_changed.connect(resources_changed.emit)
	strategic_comp.strategic_resources_changed.connect(strategic_resources_changed.emit)
	skills_comp.skills_changed.connect(skills_changed.emit)
	tools_comp.tools_changed.connect(tools_changed.emit)
	time_comp.time_changed.connect(time_changed.emit)

func get_component(comp_name: String) -> HeroComponent:
	return _components.get(comp_name, null)

# ═══════════════════════════════════════════
#  НАСТРОЙКА КАРТЫ (вызывается извне)
# ═══════════════════════════════════════════

func setup(map: MapGenerator) -> void:
	if _setup_done:
		return
	_setup_done = true

	# Инициализация компонентов в правильном порядке
	for comp_name in ["Army", "Magic", "StrategicResources", "Inventory"]:
		if _components.has(comp_name):
			_components[comp_name].initialize()

	movement_comp.setup_map(map)
	visual_comp.setup_visual(map)
	combat_comp.set_max_hp(20)

	if map.has_valid_tilemap():
		position = map.map_to_local(movement_comp.get_current_cell())

# ═══════════════════════════════════════════
#  ОБРАТНАЯ СОВМЕСТИМОСТЬ (свойства-аксессоры)
# ═══════════════════════════════════════════

# Старые имена → новые компоненты. Позволяют не менять 50+ файлов сразу.
# Сеттеры нужны тестам, которые подменяют под-объекты (h.movement = ...).

# TASK_20_1: тихое игнорирование заменено на push_warning (fail-fast при настройке до init).
var movement: HeroMovementController:
	get: return movement_comp.get_controller() if movement_comp else null
	set(v):
		if movement_comp:
			movement_comp.set_controller(v)
		else:
			push_warning("HeroController: 'movement' set before components init — ignored")

var army: HeroArmyController:
	get: return army_comp._controller if army_comp else null
	set(v):
		if army_comp:
			army_comp.set_controller(v)
		else:
			push_warning("HeroController: 'army' set before components init — ignored")

var resources: HeroResources:
	get: return resources_comp._controller if resources_comp else null
	set(v):
		if resources_comp:
			resources_comp.set_controller(v)
		else:
			push_warning("HeroController: 'resources' set before components init — ignored")

var visual: HeroVisualController:
	get: return visual_comp._controller if visual_comp else null

var magic: HeroMagic:
	get: return magic_comp.magic if magic_comp else null
	set(v): if magic_comp: magic_comp.set_magic(v)

var needs: HeroNeeds:
	get: return needs_comp.needs if needs_comp else null

var inventory: HeroInventory:
	get: return inventory_comp.inventory if inventory_comp else null

var skills: HeroSkills:
	get: return skills_comp.skills if skills_comp else null
	set(v): if skills_comp: skills_comp.set_skills(v)

var tools: HeroTools:
	get: return tools_comp.tools if tools_comp else null
	set(v): if tools_comp: tools_comp.set_tools(v)

var time: TimeSystem:
	get: return time_comp.time if time_comp else null
	set(v): if time_comp: time_comp.set_time(v)

var strategic_resources: HeroStrategicResources:
	get: return strategic_comp.strategic if strategic_comp else null
	set(v): if strategic_comp: strategic_comp.set_strategic(v)

var followers: Array:
	get: return followers_comp.followers if followers_comp else []
	set(v): if followers_comp: followers_comp.followers = v

var hero_name: String:
	get: return stats_comp.hero_name if stats_comp else "Darkstorn"
	set(v): if stats_comp: stats_comp.hero_name = v

var stats: Dictionary:
	get: return stats_comp.stats if stats_comp else {}
	set(v): if stats_comp: stats_comp.stats = v

var hero_race: String:
	get: return stats_comp.hero_race if stats_comp else ""
	set(v): if stats_comp: stats_comp.hero_race = v

var hero_class: String:
	get: return stats_comp.hero_class if stats_comp else ""
	set(v): if stats_comp: stats_comp.hero_class = v

var hero_culture: String:
	get: return stats_comp.hero_culture if stats_comp else ""
	set(v): if stats_comp: stats_comp.hero_culture = v

var hero_background: String:
	get: return stats_comp.hero_background if stats_comp else ""
	set(v): if stats_comp: stats_comp.hero_background = v

var path_id: StringName:
	get: return stats_comp.path_id if stats_comp else &""
	set(v): if stats_comp: stats_comp.path_id = v

var resurrected_once: bool:
	get: return stats_comp.resurrected_once if stats_comp else false
	set(v): if stats_comp: stats_comp.resurrected_once = v

var combat_hp: int:
	get: return combat_comp.combat_hp if combat_comp else 0
	set(v): if combat_comp: combat_comp.combat_hp = v

var max_combat_hp: int:
	get: return combat_comp.max_combat_hp if combat_comp else 0
	set(v): if combat_comp: combat_comp.max_combat_hp = v

var is_alive: bool:
	get: return combat_comp.is_alive if combat_comp else true
	set(v): if combat_comp: combat_comp.is_alive = v

var current_cell: Vector2i:
	get: return movement_comp.get_current_cell() if movement_comp else Vector2i(-1, -1)

var move_points: float:
	get: return movement_comp.get_move_points() if movement_comp else 0.0

# ═══════════════════════════════════════════
#  ПУБЛИЧНЫЙ ИНТЕРФЕЙС (делегирование)
# ═══════════════════════════════════════════

func on_map_clicked(cell: Vector2i) -> void:
	movement_comp.on_map_clicked(cell)

func move_to_cell(cell: Vector2i) -> bool:
	return movement_comp.move_to_cell(cell)

func can_reach(cell: Vector2i) -> bool:
	return movement_comp.can_reach(cell)

func reach_problem(cell: Vector2i) -> String:
	return movement_comp.reach_problem(cell)

func cancel_pending(clear_text: bool = true) -> void:
	movement_comp.cancel_pending(clear_text)

func cancel_planned_path() -> void:
	movement_comp.cancel_planned_path()

func force_stop() -> void:
	movement_comp.force_stop()

func get_army_for_battle() -> Array[UnitStack]:
	return army_comp.get_army_for_battle()

func apply_battle_results(surviving_army: Array[UnitStack]) -> void:
	army_comp.apply_battle_results(surviving_army)

func get_army() -> HeroArmyController:
	return army_comp._controller if army_comp else null

func get_map_gen() -> MapGenerator:
	return movement_comp.get_controller().get_map_gen() if movement_comp else null

func add_strategic_resource(id: StringName, amount: int) -> int:
	return strategic_comp.add(id, amount)

func remove_strategic_resource(id: StringName, amount: int) -> int:
	return strategic_comp.remove(id, amount)

func get_daily_movement_points() -> float:
	var mods := inventory_comp.get_total_modifiers()
	return movement_comp.get_daily_movement_points(int(mods.get("movement", 0)))

func get_avatar_texture() -> Texture2D:
	return visual_comp.get_avatar_texture()

func is_combat_dead() -> bool:
	return combat_comp.is_combat_dead()

func mark_combat_dead() -> void:
	combat_comp.mark_dead()

func set_combat_hp(amount: int) -> void:
	combat_comp.set_hp(amount)

func has_artifact_effect(effect: StringName) -> bool:
	return inventory_comp.has_special_effect(effect)

func get_battle_bonus() -> Dictionary:
	var mods := inventory_comp.get_total_modifiers()
	return stats_comp.get_battle_bonus(mods)

func get_hero_bonus() -> Dictionary:
	return stats_comp.get_hero_bonus()

func apply_build(profile: HeroBuildProfile) -> void:
	stats_comp.apply_build(profile)

func revive_at(city: City) -> void:
	combat_comp.revive()
	needs_comp.reset()
	inventory_comp.inventory.equipped.clear()
	inventory_comp.inventory.backpack.clear()
	if city != null:
		movement_comp.set_current_cell(city.center)

# ═══════════════════════════════════════════
#  КОНЕЦ ХОДА
# ═══════════════════════════════════════════

func end_turn() -> void:
	# Порядок: ресурсы → стратегические → магия → время → движение → потребности
	resources_comp.end_turn()
	strategic_comp.end_turn()
	magic_comp.end_turn()
	time_comp.end_turn()
	# Восстановление дневных очков движения (как в старой версии).
	movement_comp.set_move_points(get_daily_movement_points())
	movement_points_changed.emit(movement_comp.get_move_points(), get_daily_movement_points())
	movement_comp.end_turn()
	needs_comp.end_turn()

	if movement_comp != null:
		movement_comp.auto_follow_at_turn_start()

func _tick_needs() -> void:
	# Делегат для старых вызовов (тесты, WorldController).
	needs_comp.end_turn()

# ═══════════════════════════════════════════
#  СЕРИАЛИЗАЦИЯ
# ═══════════════════════════════════════════

func serialize() -> Dictionary:
	var data := {}
	for comp_name in _components:
		var comp: HeroComponent = _components[comp_name]
		var comp_data: Dictionary = comp.serialize()
		for key in comp_data:
			data[key] = comp_data[key]
	return data

func deserialize(data: Dictionary) -> void:
	for comp_name in _components:
		var comp: HeroComponent = _components[comp_name]
		comp.deserialize(data)

# ═══════════════════════════════════════════
#  ВНУТРЕННЕЕ
# ═══════════════════════════════════════════

func _on_set_position(pos: Vector2) -> void:
	position = pos

func _on_move_requested(target: Vector2, duration: float, callback: Callable) -> void:
	if _Platform.is_headless():
		callback.call()
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration)
	_tween.tween_callback(callback)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

extends Node2D
class_name HeroController
## Thin facade: composes Movement, Army, Resources, Visual.

signal hero_moved(cell: Vector2i)
signal hero_entered_village(cell: Vector2i)
signal movement_points_changed(current: float, max_val: float)
signal resources_changed(resources: Dictionary)
signal path_previewed(text: String)
signal strategic_resources_changed(resources: Dictionary)
signal skills_changed
signal tools_changed
signal time_changed(hour: float)

var movement: HeroMovementController
var army: HeroArmyController
var resources: HeroResources
var visual: HeroVisualController

var hero_name: String = "Darkstorn"
var stats := {"attack": 0, "defense": 0, "spell_power": 4, "knowledge": 2}
var inventory: HeroInventory = HeroInventory.new()

# Magic — HeroMagic handles mana/schools/spellbook internally.
var magic: HeroMagic = HeroMagic.new()

# Resource chains (Addendum 10)
var skills: HeroSkills
var tools: HeroTools
var time: TimeSystem
var strategic_resources: Dictionary = {}  # resource_id -> amount

# Backward-compat pass-throughs (kept for existing callers)
var mana_current: int:
	get: return magic.mana_current
var mana_max: int:
	get: return magic.mana_max
var magic_schools: Dictionary:
	get: return magic.schools
var spellbook: Array[StringName]:
	get: return magic.spellbook

var _tween: Tween

var current_cell: Vector2i:
	get: return movement.current_cell
var move_points: float:
	get: return movement.move_points


func _ready() -> void:
	movement = HeroMovementController.new()
	movement.name = "Movement"
	movement.max_move_points = 10.0
	add_child(movement)

	army = HeroArmyController.new()
	army.name = "Army"
	add_child(army)

	resources = HeroResources.new()
	resources.name = "Resources"
	resources.inventory = inventory
	add_child(resources)

	visual = HeroVisualController.new()
	visual.name = "Visual"
	add_child(visual)

	magic.init_defaults()

	# Resource chains (Addendum 10)
	time = TimeSystem.new()
	skills = HeroSkills.new()
	tools = HeroTools.new()

	_init_strategic_resources()

	_wire_signals()


func _init_strategic_resources() -> void:
	var all: Array = ResourceRegistry.get_all()
	for def in all:
		strategic_resources[def.id] = 0


func _wire_signals() -> void:
	movement.hero_moved.connect(hero_moved.emit)
	movement.movement_points_changed.connect(movement_points_changed.emit)
	movement.path_previewed.connect(path_previewed.emit)
	movement.hero_entered_village.connect(hero_entered_village.emit)
	movement.reach_preview_changed.connect(_on_reach_preview)
	movement.reach_preview_cleared.connect(_on_reach_cleared)
	resources.resources_changed.connect(resources_changed.emit)
	time.time_changed.connect(time_changed.emit)
	skills.skills_changed.connect(skills_changed.emit)
	tools.tools_changed.connect(tools_changed.emit)


func get_map_gen() -> MapGenerator:
	return movement.get_map_gen()


func setup(map: MapGenerator) -> void:
	movement.setup(map, self)
	visual.setup(map, self)
	visual.build_visual()
	visual.setup_path_visual()


# ==================== PASSTHROUGH — movement ====================

func on_map_clicked(cell: Vector2i) -> void:
	movement.on_map_clicked(cell)


func cancel_pending(clear_text: bool = true) -> void:
	movement.cancel_pending(clear_text)


# ==================== PASSTHROUGH — army ====================

func get_army_for_battle() -> Array[UnitStack]:
	return army.get_army_for_battle()


func apply_battle_results(surviving_army: Array[UnitStack]) -> void:
	army.apply_battle_results(surviving_army)


# ==================== PASSTHROUGH — resources ====================

func _on_resource_pickup(res_type: int) -> void:
	resources.pickup_resource(res_type)


# ==================== PASSTHROUGH — visual ====================

func _idle_animation() -> void:
	visual.idle_animation()


func _set_facing(delta: Vector2i) -> void:
	visual.set_facing(delta)


func _draw_path(pts: Array[Vector2i]) -> void:
	visual.draw_path(pts)


func _clear_path_visual() -> void:
	visual.clear_path_visual()


# Marker layer passthroughs (for new marker system)
func _on_reach_preview(_pts: Array[Vector2i], _dist: Dictionary, _mp: float) -> void:
	pass  # WorldController handles MarkerLayer rendering

func _on_reach_cleared() -> void:
	pass


func _hide_path_visual() -> void:
	visual.clear_path_visual()


func _show_marker(pos: Vector2) -> void:
	visual.show_marker(pos)


func _tween_to(target: Vector2, duration: float, callback: Callable) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", target, duration)
	_tween.tween_callback(callback)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


# ==================== TURN LOGIC ====================

func end_turn() -> void:
	resources.apply_daily_effects()
	magic.tick_restore(stats.get("knowledge", 0))

	# Auto-generate basic resources
	_add_strategic_resource(&"wood", GameSettings.RESOURCE_AUTO_WOOD_PER_DAY)
	_add_strategic_resource(&"stone", GameSettings.RESOURCE_AUTO_STONE_PER_DAY)

	# Reset time for new day
	time.reset_for_new_day()

	movement.move_points = get_daily_movement_points()
	movement_points_changed.emit(movement.move_points, get_daily_movement_points())
	movement.end_turn_movement()


func _add_strategic_resource(id: StringName, amount: int) -> void:
	if not strategic_resources.has(id):
		strategic_resources[id] = 0
	var current: int = strategic_resources[id]
	var new_val: int = min(current + amount, GameSettings.RESOURCE_CAPACITY)
	if new_val != current:
		strategic_resources[id] = new_val
		strategic_resources_changed.emit(strategic_resources)


func add_strategic_resource(id: StringName, amount: int) -> int:
	"""Add strategic resource. Returns amount actually added (may be capped)."""
	if amount <= 0:
		return 0
	if not strategic_resources.has(id):
		strategic_resources[id] = 0
	var current: int = strategic_resources[id]
	var space: int = GameSettings.RESOURCE_CAPACITY - current
	var actual: int = min(amount, max(0, space))
	strategic_resources[id] = current + actual
	strategic_resources_changed.emit(strategic_resources)
	return actual


func remove_strategic_resource(id: StringName, amount: int) -> int:
	"""Remove strategic resource (for tools/consumables). Returns amount actually removed."""
	if amount <= 0 or not strategic_resources.has(id):
		return 0
	var current: int = strategic_resources[id]
	var actual: int = min(amount, current)
	strategic_resources[id] = current - actual
	strategic_resources_changed.emit(strategic_resources)
	return actual


func force_stop() -> void:
	movement.force_stop()


func get_daily_movement_points() -> float:
	return movement.get_daily_movement_points()


## Для UI-панелей. По умолчанию — null (аватар не задан, используется эмодзи 🧙)
func get_avatar_texture() -> Texture2D:
	return null


func _on_time_update(step_cost: float) -> void:
	time.spend_move_points(step_cost)


# ==================== BATTLE ====================

func get_battle_bonus() -> Dictionary:
	var mods := inventory.get_total_modifiers()
	return {
		"attack": int(stats.get("attack", 0)) + int(mods.get("attack", 0)),
		"defense": int(stats.get("defense", 0)) + int(mods.get("defense", 0)),
		"spell_power": int(stats.get("spell_power", 0)) + int(mods.get("spell_power", 0)),
		"knowledge": int(stats.get("knowledge", 0)) + int(mods.get("knowledge", 0)),
		"luck": int(mods.get("luck", 0)),
		"morale": int(mods.get("morale", 0)),
	}


func has_artifact_effect(effect: StringName) -> bool:
	return inventory.has_special_effect(effect)


func get_hero_bonus() -> Dictionary:
	return {
		"attack": stats.get("attack", 0),
		"defense": stats.get("defense", 0),
		"spell_power": stats.get("spell_power", 0),
	}


# ==================== SERIALIZATION ====================

func serialize() -> Dictionary:
	return {
		"cell": {"x": movement.current_cell.x, "y": movement.current_cell.y},
		"move_points": movement.move_points,
		"hero_name": hero_name,
		"stats": stats.duplicate(),
		"resources": resources.serialize(),
		"army": army.serialize(),
		"inventory": inventory.serialize(),
		"mana_current": magic.mana_current,
		"mana_max": magic.mana_max,
		"magic_schools": magic.schools.duplicate(),
		"spellbook": magic.spellbook.duplicate(),
		"skills": skills.get_all(),
		"tools": tools.serialize(),
		"strategic_resources": strategic_resources.duplicate(),
		"time_mp_spent": time.mp_spent_today,
	}


func deserialize(data: Dictionary) -> void:
	movement.current_cell = Vector2i(int(data["cell"]["x"]), int(data["cell"]["y"]))
	movement.move_points = float(data.get("move_points", movement.move_points))
	hero_name = str(data.get("hero_name", hero_name))
	stats = data.get("stats", stats).duplicate()
	resources.deserialize(data.get("resources", {}))
	army.deserialize(data.get("army", []))
	inventory.deserialize(data.get("inventory", {}))
	magic.mana_current = int(data.get("mana_current", magic.mana_current))
	magic.mana_max = int(data.get("mana_max", magic.mana_max))
	magic.schools = data.get("magic_schools", magic.schools).duplicate()
	magic.spellbook = data.get("spellbook", magic.spellbook).duplicate()
	if skills == null:
		skills = HeroSkills.new()

	for skill in skills.get_all():
		skills.set_skill(StringName(skill), 0)

	var saved_skills: Dictionary = data.get("skills", {})
	for sk in saved_skills:
		skills.set_skill(StringName(sk), int(saved_skills[sk]))
	tools.deserialize(data.get("tools", []))
	strategic_resources = data.get("strategic_resources", strategic_resources).duplicate()
	time.mp_spent_today = float(data.get("time_mp_spent", 0.0))

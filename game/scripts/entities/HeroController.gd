extends Node2D
class_name HeroController
## Thin facade: composes Movement, Army, Resources, Visual.

const _Platform = preload("res://scripts/core/Platform.gd")
const ServiceContainer = preload("res://scripts/core/ServiceContainer.gd")
const _HeroProfile = preload("res://scripts/data/HeroBuildProfile.gd")

signal hero_moved(cell: Vector2i)
signal hero_entered_village(cell: Vector2i)
signal movement_points_changed(current: float, max_val: float)
signal resources_changed(resources: Dictionary)
signal path_previewed(text: String)
signal planned_route_changed(committed: bool)
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
# port-troles-heritage: идентичность героя из конструктора (создание мира).
var hero_race: String = ""
var hero_class: String = ""
var hero_culture: String = ""
var hero_background: String = ""
var inventory: HeroInventory = HeroInventory.new()

## succession-sigil: путь-легенда (build identity). Источник истины для
## выбора преемника (преемник должен быть последователем того же пути).
var path_id: StringName = &""

## hero-survival: core-потребности (rest/social/inspiration) и
## флаг «уже воскрешён в этом цикле» (воскресение — один раз за жизнь героя).
var needs := HeroNeeds.new()
var resurrected_once := false

## hero-survival: опциональная ссылка на города (world подставляет в setup;
## headless-тесты ставят вручную). null — герой всегда «в поле».
var city_manager: CityManager = null
## succession-sigil: бой. HP героя в бою; 0 = герой пал в бою.
## combat_hp обнуляется в _apply_results при полном уничтожении армии.
var combat_hp := 0
var max_combat_hp := 0
## succession-sigil: жив ли герой (смерть в бою / от потребностей).
var is_alive := true

# Magic — HeroMagic handles mana/schools/spellbook internally.
var magic: HeroMagic = HeroMagic.new()

# Resource chains (Addendum 10)
var skills: HeroSkills
var tools: HeroTools
var time: TimeSystem
var strategic_resources: HeroStrategicResources = HeroStrategicResources.new()

# city-in-world: именованные последователи (Follower). Найм — из населения
# городов (FollowerSystem.recruit). Персистентность — serialize/deserialize.
var followers: Array = []

# Backward-compat pass-throughs (kept for existing callers)
var mana_current: int:
	get: return magic.mana_current
var mana_max: int:
	get: return magic.mana_max
var magic_schools: Dictionary:
	get: return magic.schools
var spellbook: Array[StringName]:
	get: return magic.spellbook

# ==================== SUCCESSION-SIGIL: COMBAT DEATH ====================

## True, если герой получил смертельный урон в бою (combat_hp <= 0).
func is_combat_dead() -> bool:
	return combat_hp <= 0

## Обнулить боевое HP и пометить героя умершим.
func mark_combat_dead() -> void:
	combat_hp = 0
	is_alive = false

## Установить боевое HP (0..max). 0 → герой пал в бою.
func set_combat_hp(amount: int) -> void:
	combat_hp = clampi(amount, 0, max(max_combat_hp, 0))
	is_alive = combat_hp > 0

var _tween: Tween
var _setup_done := false

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

	# strategic_resources.init_from_registry() вызывается в setup() после ServiceContainer

	_wire_signals()





var _signals_wired := false

## Идемпотентно: _ready() вызывается ПРИ КАЖДОМ входе в дерево (перерождение:
## detach → attach), повторный connect() роняет ERR_INVALID_PARAMETER.
func _wire_signals() -> void:
	if _signals_wired:
		return
	_signals_wired = true
	movement.hero_moved.connect(hero_moved.emit)
	movement.movement_points_changed.connect(movement_points_changed.emit)
	movement.path_previewed.connect(path_previewed.emit)
	movement.hero_entered_village.connect(hero_entered_village.emit)
	movement.reach_preview_changed.connect(_on_reach_preview)
	movement.reach_preview_cleared.connect(_on_reach_cleared)
	movement.planned_route_changed.connect(planned_route_changed.emit)

	# R2: New signals replacing _parent back-references
	movement.facing_changed.connect(visual.set_facing)
	movement.move_requested.connect(_tween_to)
	movement.request_hide_path_visual.connect(visual.clear_path_visual)
	movement.request_show_marker.connect(visual.show_marker)
	movement.request_idle_animation.connect(visual.idle_animation)
	movement.request_kill_tween.connect(_kill_tween)
	movement.request_time_update.connect(_on_time_update)
	movement.request_resource_pickup.connect(_on_resource_pickup)
	movement.request_set_position.connect(func(pos: Vector2): position = pos)

	resources.resources_changed.connect(resources_changed.emit)
	strategic_resources.strategic_resources_changed.connect(strategic_resources_changed.emit)
	time.time_changed.connect(time_changed.emit)
	skills.skills_changed.connect(skills_changed.emit)
	tools.tools_changed.connect(tools_changed.emit)


func get_map_gen() -> MapGenerator:
	return movement.get_map_gen()


var _services: ServiceContainer = null

func setup(map: MapGenerator, services: ServiceContainer = null) -> void:
	if _setup_done:
		return
	_setup_done = true
	# Инъекция реестра в армию
	army.setup(_services.units if _services != null else null)
	# Инъекция реестра в стратегические ресурсы
	strategic_resources.init_from_registry(
		_services.resources if _services != null else null
	)

	movement.set_artifact_effect_fn(has_artifact_effect)  # must be before movement.setup()
	movement.setup(map)
	visual.setup(map, self)
	visual.build_visual()
	visual.setup_path_visual()


# ==================== PASSTHROUGH — movement ====================

func on_map_clicked(cell: Vector2i) -> void:
	movement.on_map_clicked(cell)


func move_to_cell(cell: Vector2i) -> bool:
	return movement.move_to_cell(cell)


func can_reach(cell: Vector2i) -> bool:
	return movement.can_reach(cell)


func reach_problem(cell: Vector2i) -> String:
	return movement.reach_problem(cell)


func cancel_pending(clear_text: bool = true) -> void:
	movement.cancel_pending(clear_text)

func cancel_planned_path() -> void:
	movement.cancel_planned_path()


# ==================== PASSTHROUGH — army ====================

func get_army_for_battle() -> Array[UnitStack]:
	return army.get_army_for_battle()


func apply_battle_results(surviving_army: Array[UnitStack]) -> void:
	army.apply_battle_results(surviving_army)


func get_army() -> HeroArmyController:
	return army


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


# ==================== TURN LOGIC ====================

func end_turn() -> void:
	_apply_daily_resource_effects()
	_restore_mana()
	_reset_time_and_movement()
	_tick_needs()


## hero-survival: тик потребностей. В городе (центр под ногами) — recovery
## по таблице citizens; в поле — только распад. Ноль DEATH_STREAK ходов
## подряд → смерть: hero_died(cause) (succession/endgame/DeathSequence —
## дальше по существующему потоку, как при боевой смерти).
func _tick_needs() -> void:
	if not is_alive:
		return
	var city: City = null
	if city_manager != null:
		city = city_manager.city_at(movement.current_cell)
	var cause := needs.tick(city != null, city)
	if cause != &"":
		is_alive = false
		GameLogger.world("Hero death by needs: %s" % String(cause))
		GameEventBus.hero_died.emit(cause)


## hero-survival: воскресение в великом храме. Возвращает героя в жизнь
## на центре города-храма: HP/потребности восстановлены, path и spellbook
## сохранены, инвентарь — шаблон (личное имущество гибнет с героем).
func revive_at(city: City) -> void:
	is_alive = true
	combat_hp = max_combat_hp
	needs.reset()
	inventory.equipped.clear()
	inventory.backpack.clear()
	if city != null:
		movement.current_cell = city.center


func _apply_daily_resource_effects() -> void:
	resources.apply_daily_effects()
	strategic_resources._add_internal(&"wood", GameSettings.RESOURCE_AUTO_WOOD_PER_DAY)
	strategic_resources._add_internal(&"stone", GameSettings.RESOURCE_AUTO_STONE_PER_DAY)
	strategic_resources.emit_changed()


func _restore_mana() -> void:
	magic.tick_restore(stats.get("knowledge", 0))


func _reset_time_and_movement() -> void:
	time.reset_for_new_day()
	movement.move_points = get_daily_movement_points()
	movement_points_changed.emit(movement.move_points, get_daily_movement_points())
	movement.end_turn_movement()
	# Автоход по зафиксированному маршруту в начале нового хода (D2).
	movement.auto_follow_at_turn_start()


func add_strategic_resource(id: StringName, amount: int) -> int:
	return strategic_resources.add(id, amount)


func remove_strategic_resource(id: StringName, amount: int) -> int:
	return strategic_resources.remove(id, amount)


func force_stop() -> void:
	movement.force_stop()


func get_daily_movement_points() -> float:
	var mods := inventory.get_total_modifiers()
	return movement.get_daily_movement_points(mods.get("movement", 0))


## Для UI-панелей. По умолчанию — null (аватар не задан, используется эмодзи 🧙)
func get_avatar_texture() -> Texture2D:
	return visual.get_avatar_texture() if visual != null else null


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


# ==================== HERO BUILD (port-troles-heritage) ====================

## Применить профиль создания героя: имя, статы, идентичность.
func apply_build(profile: _HeroProfile) -> void:
	if profile == null:
		return
	hero_name = profile.name if not profile.name.is_empty() else hero_name
	stats = profile.get_stats()
	hero_race = profile.race
	hero_class = profile.character_class
	hero_culture = profile.culture
	hero_background = profile.background

# ==================== SERIALIZATION ====================

func serialize() -> Dictionary:
	return {
		"cell": {"x": movement.current_cell.x, "y": movement.current_cell.y},
		"move_points": movement.move_points,
		"hero_name": hero_name,
		"stats": stats.duplicate(),
		"hero_race": hero_race,
		"hero_class": hero_class,
		"hero_culture": hero_culture,
		"hero_background": hero_background,
		"path_id": String(path_id),
		"resources": resources.serialize(),
		"army": army.serialize(),
		"inventory": inventory.serialize(),
		"mana_current": magic.mana_current,
		"mana_max": magic.mana_max,
		"magic_schools": magic.schools.duplicate(),
		"spellbook": magic.spellbook.duplicate(),
		"skills": skills.get_all(),
		"tools": tools.serialize(),
		"strategic_resources": strategic_resources.get_all(),
		"time_mp_spent": time.mp_spent_today,
		"followers": _followers_data(),
		"planned_path": _planned_path_data(),
		# hero-survival: потребности и флаг воскрешения (старые сейвы — дефолты).
		"needs": needs.serialize(),
		"resurrected_once": resurrected_once,
	}

func _planned_path_data() -> Array:
	var out: Array = []
	for c in movement.planned_path:
		out.append({"x": c.x, "y": c.y})
	return out

func _planned_path_from(data: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in data:
		if p is Dictionary:
			out.append(Vector2i(int(p.get("x", -1)), int(p.get("y", -1))))
	return out


func deserialize(data: Dictionary) -> void:
	movement.current_cell = Vector2i(int(data["cell"]["x"]), int(data["cell"]["y"]))
	movement.move_points = float(data.get("move_points", movement.move_points))
	hero_name = str(data.get("hero_name", hero_name))
	stats = data.get("stats", stats).duplicate()
	# port-troles-heritage: идентичность (старые сейвы без ключей → "").
	hero_race = str(data.get("hero_race", hero_race))
	hero_class = str(data.get("hero_class", hero_class))
	hero_culture = str(data.get("hero_culture", hero_culture))
	hero_background = str(data.get("hero_background", hero_background))
	path_id = StringName(str(data.get("path_id", path_id)))
	resources.deserialize(data.get("resources", {}))
	army.deserialize(data.get("army", []))
	inventory.deserialize(data.get("inventory", {}))
	magic.mana_current = int(data.get("mana_current", magic.mana_current))
	magic.mana_max = int(data.get("mana_max", magic.mana_max))
	magic.schools = data.get("magic_schools", magic.schools).duplicate()
	magic.spellbook = data.get("spellbook", magic.spellbook).duplicate()
	# hero-survival: потребности (старый сейв без ключа → 1.0), флаг воскрешения.
	needs.deserialize(data.get("needs", {}))
	resurrected_once = bool(data.get("resurrected_once", false))
	if skills == null:
		skills = HeroSkills.new()

	for skill in skills.get_all():
		skills.set_skill(StringName(skill), 0)

	var saved_skills: Dictionary = data.get("skills", {})
	for sk in saved_skills:
		skills.set_skill(StringName(sk), int(saved_skills[sk]))
	tools.deserialize(data.get("tools", []))
	strategic_resources.set_all(data.get("strategic_resources", strategic_resources.get_all()))
	time.mp_spent_today = float(data.get("time_mp_spent", 0.0))
	movement.planned_path = _planned_path_from(data.get("planned_path", []))
	followers.clear()
	for f_data in data.get("followers", []):
		var f := Follower.new()
		f.deserialize(f_data)
		followers.append(f)


func _followers_data() -> Array:
	var out: Array = []
	for f in followers:
		if f != null:
			out.append(f.serialize())
	return out


# Декомпозиция HeroController → Composition

## Структура файлов

```
scripts/entities/hero/
├── HeroController.gd
└── components/
    ├── HeroComponent.gd
    ├── HeroMovementComponent.gd
    ├── HeroArmyComponent.gd
    ├── HeroMagicComponent.gd
    ├── HeroResourcesComponent.gd
    ├── HeroVisualComponent.gd
    ├── HeroNeedsComponent.gd
    ├── HeroInventoryComponent.gd
    ├── HeroSkillsComponent.gd
    ├── HeroToolsComponent.gd
    ├── HeroTimeComponent.gd
    ├── HeroStrategicResourcesComponent.gd
    ├── HeroFollowersComponent.gd
    ├── HeroCombatComponent.gd
    └── HeroStatsComponent.gd
```

---

## 1. Базовый класс компонента

```gdscript
# scripts/entities/hero/components/HeroComponent.gd
class_name HeroComponent
extends Node
## Базовый класс для всех компонентов героя.
## Каждый компонент получает ссылку на контроллер через _hero.
## Компоненты НЕ обращаются друг к другу напрямую — только через сигналы
## или через _hero, когда это явно необходимо.

var _hero: HeroController = null

## Вызывается контроллером сразу после добавления в дерево.
func setup_hero(hero: HeroController) -> void:
	_hero = hero

## Фаза инициализации после того, как все компоненты зарегистрированы.
## Переопределять для логики, зависящей от других компонентов.
func initialize() -> void:
	pass

## Конец хода героя.
func end_turn() -> void:
	pass

## Сериализация состояния компонента.
func serialize() -> Dictionary:
	return {}

## Десериализация состояния компонента.
func deserialize(_data: Dictionary) -> void:
	pass
```

---

## 2. Компонент движения

```gdscript
# scripts/entities/hero/components/HeroMovementComponent.gd
class_name HeroMovementComponent
extends HeroComponent
## Обёртка над HeroMovementController.
## Перенаправляет вызовы и пробрасывает сигналы.

var _controller: HeroMovementController = null

signal hero_moved(cell: Vector2i)
signal movement_finished(cell: Vector2i)
signal hero_entered_village(cell: Vector2i)
signal movement_points_changed(current: float, max_val: float)
signal path_previewed(text: String)
signal planned_route_changed(committed: bool)
signal reach_preview_changed(pts: Array[Vector2i], dist: Dictionary, mp: float)
signal reach_preview_cleared()
signal facing_changed(delta: Vector2i)
signal move_requested(target: Vector2, duration: float, callback: Callable)
signal request_hide_path_visual()
signal request_show_marker(pos: Vector2)
signal request_idle_animation()
signal request_kill_tween()
signal request_time_update(step_cost: float)
signal request_resource_pickup(res_type: int)
signal request_set_position(pos: Vector2)

func setup_hero(hero: HeroController) -> void:
	super(hero)
	_controller = HeroMovementController.new()
	_controller.name = "Movement"
	_controller.max_move_points = GameNumbers.HERO_DAILY_MOVEMENT
	add_child(_controller)
	_wire_signals()

func initialize() -> void:
	pass

func setup_map(map: MapGenerator) -> void:
	_controller.set_artifact_effect_fn(_has_artifact_effect)
	_controller.setup(map)

func get_controller() -> HeroMovementController:
	return _controller

func on_map_clicked(cell: Vector2i) -> void:
	_controller.on_map_clicked(cell)

func move_to_cell(cell: Vector2i) -> bool:
	return _controller.move_to_cell(cell)

func can_reach(cell: Vector2i) -> bool:
	return _controller.can_reach(cell)

func reach_problem(cell: Vector2i) -> String:
	return _controller.reach_problem(cell)

func cancel_pending(clear_text: bool = true) -> void:
	_controller.cancel_pending(clear_text)

func cancel_planned_path() -> void:
	_controller.cancel_planned_path()

func force_stop() -> void:
	_controller.force_stop()

func end_turn_movement() -> void:
	_controller.end_turn_movement()

func auto_follow_at_turn_start() -> void:
	_controller.auto_follow_at_turn_start()

func get_daily_movement_points(movement_mod: int = 0) -> float:
	return _controller.get_daily_movement_points(movement_mod)

func get_current_cell() -> Vector2i:
	return _controller.current_cell

func set_current_cell(cell: Vector2i) -> void:
	_controller.current_cell = cell

func get_move_points() -> float:
	return _controller.move_points

func set_move_points(v: float) -> void:
	_controller.move_points = v

func is_moving() -> bool:
	return _controller.is_moving

func get_planned_path() -> Array[Vector2i]:
	return _controller.planned_path

func set_planned_path(path: Array[Vector2i]) -> void:
	_controller.planned_path = path

func teleport(cell: Vector2i) -> void:
	_controller.teleport(cell)

func end_turn() -> void:
	_controller.end_turn_movement()

func serialize() -> Dictionary:
	return {
		"cell": {"x": _controller.current_cell.x, "y": _controller.current_cell.y},
		"move_points": _controller.move_points,
		"planned_path": _serialize_planned_path(),
	}

func deserialize(data: Dictionary) -> void:
	var c: Dictionary = data.get("cell", {})
	_controller.current_cell = Vector2i(int(c.get("x", 0)), int(c.get("y", 0)))
	_controller.move_points = float(data.get("move_points", _controller.move_points))
	_controller.planned_path = _deserialize_planned_path(data.get("planned_path", []))

func _serialize_planned_path() -> Array:
	var out: Array = []
	for cell in _controller.planned_path:
		out.append({"x": cell.x, "y": cell.y})
	return out

func _deserialize_planned_path(data: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for p in data:
		if p is Dictionary:
			out.append(Vector2i(int(p.get("x", -1)), int(p.get("y", -1))))
	return out

func _has_artifact_effect(effect: StringName) -> bool:
	if _hero == null:
		return false
	return _hero.has_artifact_effect(effect)

func _wire_signals() -> void:
	_controller.hero_moved.connect(func(c): hero_moved.emit(c))
	_controller.movement_finished.connect(func(c): movement_finished.emit(c))
	_controller.hero_entered_village.connect(func(c): hero_entered_village.emit(c))
	_controller.movement_points_changed.connect(func(c, m): movement_points_changed.emit(c, m))
	_controller.path_previewed.connect(func(t): path_previewed.emit(t))
	_controller.planned_route_changed.connect(func(b): planned_route_changed.emit(b))
	_controller.reach_preview_changed.connect(func(p, d, m): reach_preview_changed.emit(p, d, m))
	_controller.reach_preview_cleared.connect(reach_preview_cleared.emit)
	_controller.facing_changed.connect(func(d): facing_changed.emit(d))
	_controller.move_requested.connect(func(t, d, cb): move_requested.emit(t, d, cb))
	_controller.request_hide_path_visual.connect(request_hide_path_visual.emit)
	_controller.request_show_marker.connect(func(p): request_show_marker.emit(p))
	_controller.request_idle_animation.connect(request_idle_animation.emit)
	_controller.request_kill_tween.connect(request_kill_tween.emit)
	_controller.request_time_update.connect(func(c): request_time_update.emit(c))
	_controller.request_resource_pickup.connect(func(r): request_resource_pickup.emit(r))
	_controller.request_set_position.connect(func(p): request_set_position.emit(p))
```

---

## 3. Компонент армии

```gdscript
# scripts/entities/hero/components/HeroArmyComponent.gd
class_name HeroArmyComponent
extends HeroComponent

var _controller: HeroArmyController = null

func setup_hero(hero: HeroController) -> void:
	super(hero)
	_controller = HeroArmyController.new()
	_controller.name = "Army"
	add_child(_controller)

func initialize() -> void:
	_controller.setup(Services.resolve(&"units"))

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
```

---

## 4. Компонент магии

```gdscript
# scripts/entities/hero/components/HeroMagicComponent.gd
class_name HeroMagicComponent
extends HeroComponent

var magic: HeroMagic = HeroMagic.new()

signal changed()

func setup_hero(hero: HeroController) -> void:
	super(hero)
	magic.changed.connect(changed.emit)

func initialize() -> void:
	magic.init_defaults()

func school_level(school_id: int) -> int:
	return magic.school_level(school_id)

func knows(spell_id: StringName) -> bool:
	return magic.knows(spell_id)

func learn(spell_id: StringName) -> bool:
	return magic.learn(spell_id)

func forget(spell_id: StringName) -> bool:
	return magic.forget(spell_id)

func can_cast(spell) -> bool:
	return magic.can_cast(spell)

func get_mana_cost(spell) -> int:
	return magic.get_mana_cost(spell)

func can_cast_def(spell: SpellRegistry.SpellDef) -> bool:
	return magic.can_cast_def(spell)

func get_mana_cost_def(spell: SpellRegistry.SpellDef) -> int:
	return magic.get_mana_cost_def(spell)

func spend_mana(cost: int) -> bool:
	return magic.spend_mana(cost)

func refund_mana(cost: int) -> void:
	magic.refund_mana(cost)

func restore_full() -> void:
	magic.restore_full()

func tick_restore(amount: int = 1) -> void:
	magic.tick_restore(amount)

func get_mana_current() -> int:
	return magic.mana_current

func set_mana_current(v: int) -> void:
	magic.mana_current = v

func get_mana_max() -> int:
	return magic.mana_max

func set_mana_max(v: int) -> void:
	magic.mana_max = v

func get_spellbook() -> Array[StringName]:
	return magic.spellbook

func set_spellbook(v: Array[StringName]) -> void:
	magic.spellbook = v

func get_schools() -> Dictionary:
	return magic.schools

func set_schools(v: Dictionary) -> void:
	magic.schools = v

func end_turn() -> void:
	var knowledge: int = 0
	if _hero != null:
		knowledge = int(_hero.stats.get("knowledge", 0))
	tick_restore(knowledge)

func serialize() -> Dictionary:
	return {
		"mana_current": magic.mana_current,
		"mana_max": magic.mana_max,
		"magic_schools": magic.serialize_schools(),
		"spellbook": magic.spellbook.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	magic.mana_current = int(data.get("mana_current", magic.mana_current))
	magic.mana_max = int(data.get("mana_max", magic.mana_max))
	magic.deserialize_schools(data.get("magic_schools", {}))
	magic.spellbook = data.get("spellbook", magic.spellbook).duplicate()
```

---

## 5. Компонент ресурсов

```gdscript
# scripts/entities/hero/components/HeroResourcesComponent.gd
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
	_controller.resources_changed.connect(resources_changed.emit)

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
```

---

## 6. Компонент визуала

```gdscript
# scripts/entities/hero/components/HeroVisualComponent.gd
class_name HeroVisualComponent
extends HeroComponent

var _controller: HeroVisualController = null

func setup_hero(hero: HeroController) -> void:
	super(hero)
	_controller = HeroVisualController.new()
	_controller.name = "Visual"
	add_child(_controller)

func setup_visual(map: MapGenerator) -> void:
	_controller.setup(map, _hero)
	_controller.build_visual()
	_controller.setup_path_visual()

func get_avatar_texture() -> Texture2D:
	if _controller == null:
		return null
	return _controller.get_avatar_texture()

func set_facing(delta: Vector2i) -> void:
	if _controller != null:
		_controller.set_facing(delta)

func idle_animation() -> void:
	if _controller != null:
		_controller.idle_animation()

func draw_path(pts: Array[Vector2i]) -> void:
	if _controller != null:
		_controller.draw_path(pts)

func clear_path_visual() -> void:
	if _controller != null:
		_controller.clear_path_visual()

func show_marker(pos: Vector2) -> void:
	if _controller != null:
		_controller.show_marker(pos)

func update_status_orb(mp_ratio: float) -> void:
	if _controller != null:
		_controller.update_status_orb(mp_ratio)
```

---

## 7. Компонент потребностей

```gdscript
# scripts/entities/hero/components/HeroNeedsComponent.gd
class_name HeroNeedsComponent
extends HeroComponent

var needs: HeroNeeds = HeroNeeds.new()

func tick(in_city: bool, city: City = null) -> StringName:
	return needs.tick(in_city, city)

func is_critical(id: int) -> bool:
	return needs.is_critical(id)

func get_need(id: int) -> float:
	return needs.get_need(id)

func reset() -> void:
	needs.reset()

func get_needs() -> Dictionary:
	return needs.needs

func set_needs(v: Dictionary) -> void:
	needs.needs = v

func end_turn() -> void:
	if _hero == null or not _hero.is_alive:
		return
	var city: City = null
	if _hero.city_manager != null:
		var mov_comp := _hero.get_component("Movement") as HeroMovementComponent
		if mov_comp != null:
			city = _hero.city_manager.city_at(mov_comp.get_current_cell())
	var cause := tick(city != null, city)
	if cause != &"":
		_hero.mark_combat_dead()
		GameLogger.world("Hero death by needs: %s" % String(cause))
		GameEventBus.hero_died.emit(cause)

func serialize() -> Dictionary:
	return {"needs": needs.serialize()}

func deserialize(data: Dictionary) -> void:
	needs.deserialize(data.get("needs", {}))
```

---

## 8. Компонент инвентаря

```gdscript
# scripts/entities/hero/components/HeroInventoryComponent.gd
class_name HeroInventoryComponent
extends HeroComponent

var inventory: HeroInventory = HeroInventory.new()

signal equipped_changed()
signal backpack_changed()
signal modifiers_changed()

func setup_hero(hero: HeroController) -> void:
	super(hero)
	inventory.equipped_changed.connect(equipped_changed.emit)
	inventory.backpack_changed.connect(backpack_changed.emit)
	inventory.modifiers_changed.connect(modifiers_changed.emit)

func get_total_modifiers() -> Dictionary:
	return inventory.get_total_modifiers()

func has_special_effect(effect: StringName) -> bool:
	return inventory.has_special_effect(effect)

func has_slot(slot: Artifact.Slot) -> bool:
	return inventory.has_slot(slot)

func get_equipped(slot: Artifact.Slot) -> Artifact:
	return inventory.get_equipped(slot)

func equip(artifact: Artifact, target_slot: Artifact.Slot = Artifact.Slot.RING_L) -> bool:
	return inventory.equip(artifact, target_slot)

func unequip(slot: Artifact.Slot) -> Artifact:
	return inventory.unequip(slot)

func add_to_backpack(artifact: Artifact) -> bool:
	return inventory.add_to_backpack(artifact)

func remove_from_backpack(idx: int) -> Artifact:
	return inventory.remove_from_backpack(idx)

func sell_artifact(idx: int) -> int:
	return inventory.sell_artifact(idx)

func get_equipped_dict() -> Dictionary:
	return inventory.equipped

func get_backpack() -> Array[Artifact]:
	return inventory.backpack

func serialize() -> Dictionary:
	return {"inventory": inventory.serialize()}

func deserialize(data: Dictionary) -> void:
	inventory.deserialize(data.get("inventory", {}))
```

---

## 9. Компонент навыков

```gdscript
# scripts/entities/hero/components/HeroSkillsComponent.gd
class_name HeroSkillsComponent
extends HeroComponent

var skills: HeroSkills = HeroSkills.new()

signal skills_changed()

func setup_hero(hero: HeroController) -> void:
	super(hero)
	skills.skills_changed.connect(skills_changed.emit)

func get_skill(skill: StringName) -> int:
	return skills.get_skill(skill)

func set_skill(skill: StringName, value: int) -> void:
	skills.set_skill(skill, value)

func add_point(skill: StringName) -> void:
	skills.add_point(skill)

func has_detection_key(skill: StringName) -> bool:
	return skills.has_detection_key(skill)

func get_yield_multiplier(skill: StringName) -> float:
	return skills.get_yield_multiplier(skill)

func get_all() -> Dictionary:
	return skills.get_all()

func reset() -> void:
	skills.reset()

func serialize() -> Dictionary:
	return {"skills": skills.get_all()}

func deserialize(data: Dictionary) -> void:
	var saved: Dictionary = data.get("skills", {})
	for sk in saved:
		skills.set_skill(StringName(sk), int(saved[sk]))
```

---

## 10. Компонент инструментов

```gdscript
# scripts/entities/hero/components/HeroToolsComponent.gd
class_name HeroToolsComponent
extends HeroComponent

var tools: HeroTools = HeroTools.new()

signal tools_changed()

func setup_hero(hero: HeroController) -> void:
	super(hero)
	tools.tools_changed.connect(tools_changed.emit)

func has_tool(tool_id: int) -> bool:
	return tools.has_tool(tool_id)

func get_tool_count(tool_id: int) -> int:
	return tools.get_tool_count(tool_id)

func add_tool(tool_id: int, quantity: int = 1) -> bool:
	return tools.add_tool(tool_id, quantity)

func remove_tool(tool_id: int, quantity: int = 1) -> bool:
	return tools.remove_tool(tool_id, quantity)

func get_all() -> Array[Dictionary]:
	return tools.get_all()

func serialize() -> Dictionary:
	return {"tools": tools.serialize()}

func deserialize(data: Dictionary) -> void:
	tools.deserialize(data.get("tools", []))
```

---

## 11. Компонент времени

```gdscript
# scripts/entities/hero/components/HeroTimeComponent.gd
class_name HeroTimeComponent
extends HeroComponent

var time: TimeSystem = TimeSystem.new()

signal time_changed(hour: float)

func setup_hero(hero: HeroController) -> void:
	super(hero)
	time.time_changed.connect(time_changed.emit)

func spend_move_points(amount: float) -> void:
	time.spend_move_points(amount)

func reset_for_new_day() -> void:
	time.reset_for_new_day()

func get_period_name() -> String:
	return time.get_period_name()

func is_noon() -> bool:
	return time.is_noon()

func is_night() -> bool:
	return time.is_night()

func format_time() -> String:
	return time.format_time()

func end_turn() -> void:
	reset_for_new_day()

func serialize() -> Dictionary:
	return {"time_mp_spent": time.mp_spent_today}

func deserialize(data: Dictionary) -> void:
	time.mp_spent_today = float(data.get("time_mp_spent", 0.0))
```

---

## 12. Компонент стратегических ресурсов

```gdscript
# scripts/entities/hero/components/HeroStrategicResourcesComponent.gd
class_name HeroStrategicResourcesComponent
extends HeroComponent

var strategic: HeroStrategicResources = HeroStrategicResources.new()

signal strategic_resources_changed(resources: Dictionary)

func setup_hero(hero: HeroController) -> void:
	super(hero)
	strategic.strategic_resources_changed.connect(strategic_resources_changed.emit)

func initialize() -> void:
	strategic.init_from_registry(Services.resolve(&"resources"))

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
```

---

## 13. Компонент последователей

```gdscript
# scripts/entities/hero/components/HeroFollowersComponent.gd
class_name HeroFollowersComponent
extends HeroComponent

var followers: Array = []

func add(f: Follower) -> void:
	followers.append(f)

func remove(f: Follower) -> void:
	followers.erase(f)

func clear() -> void:
	followers.clear()

func find_same_path(path_id: StringName) -> Follower:
	for f in followers:
		if f != null and f.path == path_id:
			return f
	return null

func has_eligible_successor(path_id: StringName) -> bool:
	return find_same_path(path_id) != null

func serialize() -> Dictionary:
	var out: Array = []
	for f in followers:
		if f != null:
			out.append(f.serialize())
	return {"followers": out}

func deserialize(data: Dictionary) -> void:
	followers.clear()
	for f_data in data.get("followers", []):
		var f := Follower.new()
		f.deserialize(f_data)
		followers.append(f)
```

---

## 14. Компонент боя

```gdscript
# scripts/entities/hero/components/HeroCombatComponent.gd
class_name HeroCombatComponent
extends HeroComponent

var combat_hp: int = 0
var max_combat_hp: int = 0
var is_alive: bool = true

func set_max_hp(v: int) -> void:
	max_combat_hp = v
	combat_hp = v
	is_alive = true

func set_hp(amount: int) -> void:
	combat_hp = clampi(amount, 0, max(max_combat_hp, 0))
	is_alive = combat_hp > 0

func mark_dead() -> void:
	combat_hp = 0
	is_alive = false

func is_combat_dead() -> bool:
	return combat_hp <= 0

func revive() -> void:
	is_alive = true
	combat_hp = max_combat_hp

func serialize() -> Dictionary:
	return {
		"combat_hp": combat_hp,
		"max_combat_hp": max_combat_hp,
		"is_alive": is_alive,
	}

func deserialize(data: Dictionary) -> void:
	combat_hp = int(data.get("combat_hp", 0))
	max_combat_hp = int(data.get("max_combat_hp", 0))
	is_alive = bool(data.get("is_alive", true))
```

---

## 15. Компонент характеристик

```gdscript
# scripts/entities/hero/components/HeroStatsComponent.gd
class_name HeroStatsComponent
extends HeroComponent

var hero_name: String = "Darkstorn"
var stats := {"attack": 0, "defense": 0, "spell_power": 4, "knowledge": 2}
var hero_race: String = ""
var hero_class: String = ""
var hero_culture: String = ""
var hero_background: String = ""
var path_id: StringName = &""
var resurrected_once: bool = false

func apply_build(profile: HeroBuildProfile) -> void:
	if profile == null:
		return
	hero_name = profile.name if not profile.name.is_empty() else hero_name
	stats = profile.get_stats()
	hero_race = profile.race
	hero_class = profile.character_class
	hero_culture = profile.culture
	hero_background = profile.background

func get_battle_bonus(inventory_mods: Dictionary) -> Dictionary:
	return {
		"attack": int(stats.get("attack", 0)) + int(inventory_mods.get("attack", 0)),
		"defense": int(stats.get("defense", 0)) + int(inventory_mods.get("defense", 0)),
		"spell_power": int(stats.get("spell_power", 0)) + int(inventory_mods.get("spell_power", 0)),
		"knowledge": int(stats.get("knowledge", 0)) + int(inventory_mods.get("knowledge", 0)),
		"luck": int(inventory_mods.get("luck", 0)),
		"morale": int(inventory_mods.get("morale", 0)),
	}

func get_hero_bonus() -> Dictionary:
	return {
		"attack": stats.get("attack", 0),
		"defense": stats.get("defense", 0),
		"spell_power": stats.get("spell_power", 0),
	}

func serialize() -> Dictionary:
	return {
		"hero_name": hero_name,
		"stats": stats.duplicate(),
		"hero_race": hero_race,
		"hero_class": hero_class,
		"hero_culture": hero_culture,
		"hero_background": hero_background,
		"path_id": String(path_id),
		"resurrected_once": resurrected_once,
	}

func deserialize(data: Dictionary) -> void:
	hero_name = str(data.get("hero_name", hero_name))
	stats = data.get("stats", stats).duplicate()
	hero_race = str(data.get("hero_race", hero_race))
	hero_class = str(data.get("hero_class", hero_class))
	hero_culture = str(data.get("hero_culture", hero_culture))
	hero_background = str(data.get("hero_background", hero_background))
	path_id = StringName(str(data.get("path_id", path_id)))
	resurrected_once = bool(data.get("resurrected_once", false))
```

---

## 16. Новый HeroController — тонкий координатор

```gdscript
# scripts/entities/hero/HeroController.gd
class_name HeroController
extends Node2D
## Тонкий координатор. Вся логика вынесена в компоненты.
## Контроллер отвечает только за:
##   1. Регистрацию и инициализацию компонентов
##   2. Маршрутизацию сигналов между компонентами
##   3. Сериализацию/десериализацию (делегирование)
##   4. Обратную совместимость через свойства-аксессоры

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

# ── Компоненты (создаются в _ready) ──
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

func _ready() -> void:
	_register_components()
	_wire_cross_component_signals()

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

var movement: HeroMovementController:
	get: return movement_comp.get_controller() if movement_comp else null

var army: HeroArmyController:
	get: return army_comp._controller if army_comp else null

var resources: HeroResources:
	get: return resources_comp._controller if resources_comp else null

var visual: HeroVisualController:
	get: return visual_comp._controller if visual_comp else null

var magic: HeroMagic:
	get: return magic_comp.magic if magic_comp else null

var needs: HeroNeeds:
	get: return needs_comp.needs if needs_comp else null

var inventory: HeroInventory:
	get: return inventory_comp.inventory if inventory_comp else null

var skills: HeroSkills:
	get: return skills_comp.skills if skills_comp else null

var tools: HeroTools:
	get: return tools_comp.tools if tools_comp else null

var time: TimeSystem:
	get: return time_comp.time if time_comp else null

var strategic_resources: HeroStrategicResources:
	get: return strategic_comp.strategic if strategic_comp else null

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
	# Порядок важен: ресурсы → стратегические → магия → время → потребности
	resources_comp.end_turn()
	strategic_comp.end_turn()
	magic_comp.end_turn()
	time_comp.end_turn()
	movement_comp.end_turn()
	needs_comp.end_turn()

	if movement_comp != null:
		movement_comp.auto_follow_at_turn_start()

	movement_points_changed.emit(
		movement_comp.get_move_points(), get_daily_movement_points())

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
```

---

## 17. Инструкция по миграции

### Шаг 1: Создать файлы компонентов

Создать 15 файлов из разделов 1–15 выше.

### Шаг 2: Заменить `HeroController.gd`

Заменить содержимое `scripts/entities/HeroController.gd` на код из раздела 16.

### Шаг 3: Проверить совместимость

Все существующие вызовы вида:
```gdscript
hero.movement.current_cell      # работает через аксессор
hero.army.army                  # работает
hero.magic.spellbook            # работает
hero.inventory.backpack         # работает
hero.skills.get_all()           # работает
hero.followers                  # работает
hero.stats                      # работает
hero.hero_name                  # работает
hero.path_id                    # работает
hero.is_alive                   # работает
hero.combat_hp                  # работает
```

### Шаг 4: Постепенная миграция на компоненты

В новых файлах использовать прямой доступ к компонентам:
```gdscript
# Вместо:
hero.movement.move_to_cell(cell)

# Писать:
hero.movement_comp.move_to_cell(cell)

# Или через реестр:
var mov := hero.get_component("Movement") as HeroMovementComponent
mov.move_to_cell(cell)
```

### Шаг 5: Удалить аксессоры (через 2-3 спринта)

Когда все вызовы мигрированы, удалить блок «Обратная совместимость» из `HeroController`.

### Критерии приёмки

| Проверка | Ожидание |
|---|---|
| `gdUnit4` тесты | Все 1273+ зелёные, 0 orphans |
| `hero.movement`, `hero.army`, `hero.magic` | Работают через аксессоры |
| `hero.serialize()` → `hero.deserialize()` | Полный раундтрип |
| `hero.end_turn()` | Все компоненты получают `end_turn()` |
| Новый код | Обращается к компонентам напрямую |
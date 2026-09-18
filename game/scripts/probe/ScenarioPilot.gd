class_name ScenarioPilot
extends BalanceProbe
## autopilot-scenario-matrix: базовый пилот сцenario-матрицы.
## Переиспользует автоигрока BalanceProbe (D1); роль — политика (pick_action
## через базовый _step, goal_met/metrics — через ScenarioRole).
## Класс героя задаётся ДО ботстлаба мира (pending_new_game), не после.

const _CollectorRole = preload("res://scripts/probe/CollectorRole.gd")

var role: ScenarioRole = null
var class_id: String = ""
var goal_reached_turn := -1
var extracted_total := 0
var _rare_ids: Array = []
var _rare_count := 0

func _ready() -> void:
	GameEventBus.resource_extracted.connect(_on_resource_extracted)

## Запуск сценарного прогона: seed = f(класс, роль), роль задаёт max_turns.
## Класс героя задаётся ПЕРЕД ботстлабом через prepare_world.
func start_scenario(world: Node, p_seed: int, role_id: String, p_class_id: String) -> Dictionary:
	class_id = p_class_id
	role = make_role(role_id, ScenarioTargets.role(role_id))
	if role == null:
		return {"error": "неизвестная роль: %s" % role_id}
	var target: Dictionary = role.target
	_rare_ids = target.get("rare_ids", [])
	_rare_count = 0
	extracted_total = 0
	goal_reached_turn = -1
	max_turns = int(target.get("max_turns", MAX_TURNS))
	var r: Dictionary = start_probe(world, p_seed)
	if r.get("error") != null or r.get("status") != "probe_started":
		return r
	# Класс проверяется по факту: prepare_world должен был зайти в ботстлаб.
	var hero: Node = world.get_hero()
	if hero != null and hero.get("hero_class") != null:
		var actual_class: String = str(hero.hero_class)
		if actual_class != p_class_id:
			return {"error": "класс не применён: ожидал %s, факт %s (prepare_world до ботстлаба?)" % [p_class_id, actual_class]}
	return {"status": "scenario_started", "role": role_id, "class": class_id,
		"seed": p_seed, "max_turns": max_turns}

static func make_role(role_id: String, target: Dictionary) -> ScenarioRole:
	match role_id:
		"collector":
			var r: ScenarioRole = _CollectorRole.new()
			r.id = role_id
			r.target = target
			return r
	return null

func rare_count() -> int:
	return _rare_count

func _on_resource_extracted(_cell: Vector2i, resource_id: StringName, amount: int) -> void:
	extracted_total += amount
	if _rare_ids.has(ResourceType.from_name(resource_id)):
		_rare_count += amount

## Ранний финиш: цель роли достигнута (проверяется перед каждым шагом).
func _step() -> void:
	if done:
		return
	if role != null and role.goal_met(self):
		goal_reached_turn = turn
		_finish()
		return
	super._step()

## autopilot-scenario-matrix: сбор — через игровую цепочку (WorldSpawner +
## GameEventBus), а не через ResourceNodeManager: скрытые узлы в
## resource_cells НЕ генерируются (generate_nodes_for_map — другой слой).
## BalanceProbe в headless ничего не собирал — здесь фиксим корневую причину.
func _try_collect_at(cell: Vector2i) -> bool:
	var sp: Node = _spawner
	if sp == null:
		return false
	var rt: int = int(sp.get_res_type_at(cell))
	if rt < 0:
		return false
	var removed: bool = sp.remove_resource_at(cell)
	var rid: StringName = ResourceIcons.res_type_id(rt)
	if rid != &"":
		GameEventBus.resource_extracted.emit(cell, rid, ResourceIcons.res_type_amount(rt))
	return removed

func _finish() -> void:
	super._finish()

func report() -> Dictionary:
	var rep: Dictionary = super.report()
	if role != null:
		rep["role"] = role.id
		rep["hero_class"] = class_id
		rep["goal_reached_turn"] = goal_reached_turn
		rep["role_metrics"] = role.metrics(self)
		rep["goal_met"] = role.goal_met(self)
	return rep

## ── Настройка мира ДО ботстлаба (вызывается из MCP-setup) ─────────────────
## seed в persistence + профиль героя (класс) в pending_new_game.
## WorldBootstrap._init_hero сам применит профиль и очистит pending_new_game.
static func prepare_world(p_seed: int, p_class_id: String) -> Dictionary:
	# WorldPersistence — RefCounted, НЕ Node: типизация под Node крашит Godot (MCP-eval).
	var persistence = Services.resolve(&"persistence")
	if persistence == null:
		return {"error": "persistence не найден (Services)"}
	if not HeroClasses.CLASSES.has(p_class_id):
		return {"error": "неизвестный класс: %s" % p_class_id}
	persistence.restart_game(p_seed)
	var prof := HeroBuildProfile.new()
	prof.name = "Pilot"
	prof.race = "human"
	prof.character_class = p_class_id
	prof.culture = "aedyr"
	prof.background = "soldier"
	persistence.pending_new_game = prof
	return {"status": "prepared", "seed": p_seed, "class": p_class_id}

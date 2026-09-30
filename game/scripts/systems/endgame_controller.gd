class_name EndgameController
extends Node

const GameOverScreenScene = preload("res://scenes/ui/game_over_screen.tscn")

var _session: GameSession = null
var _world_ctrl: Node = null
var _map_gen: Node = null
var _cities_mgr: CityManager = null
var _persistence: Variant = null
var _ui_manager: Node = null
var _screen: CanvasLayer = null

func setup(
	p_world_ctrl: Node,
	p_battle_coordinator: Node,
	p_map_gen: Node,
	p_cities_mgr: CityManager,
	p_persistence: Variant,
	p_enemy_proc: Variant = null,
	p_ui_manager: Node = null
) -> void:
	_ui_manager = p_ui_manager
	_world_ctrl = p_world_ctrl
	_map_gen = p_map_gen
	_cities_mgr = p_cities_mgr
	_persistence = p_persistence
	if p_persistence != null:
		_session = p_persistence.session

	if _session == null or _cities_mgr == null:
		return

	if not GameEventBus.hero_died.is_connected(_on_hero_died):
		GameEventBus.hero_died.connect(_on_hero_died)
	if not GameEventBus.turn_ended.is_connected(_on_turn_ended):
		GameEventBus.turn_ended.connect(_on_turn_ended)
	if p_enemy_proc != null and p_enemy_proc.has_signal("enemy_village_captured") \
			and not p_enemy_proc.enemy_village_captured.is_connected(_on_enemy_village_captured):
		p_enemy_proc.enemy_village_captured.connect(_on_enemy_village_captured)
	if not _cities_mgr.glory_changed.is_connected(_on_glory_changed):
		_cities_mgr.glory_changed.connect(_on_glory_changed)
	if p_battle_coordinator != null \
			and not p_battle_coordinator.enemy_stack_defeated.is_connected(_on_enemy_stack_defeated):
		p_battle_coordinator.enemy_stack_defeated.connect(_on_enemy_stack_defeated)
	if not GameEventBus.battle_won.is_connected(_on_run_battle_won):
		GameEventBus.battle_won.connect(_on_run_battle_won)
	if not GameEventBus.battle_lost.is_connected(_on_run_battle_lost):
		GameEventBus.battle_lost.connect(_on_run_battle_lost)
	if not GameEventBus.hero_successor.is_connected(_on_run_succession):
		GameEventBus.hero_successor.connect(_on_run_succession)

func restore() -> void:
	if _session == null or not _session.is_terminal():
		return
	var result := "VICTORY" if _session.state == GameSession.GameState.VICTORY else "DEFEAT"
	_show_screen(result, StringName(_session.end_reason), _build_summary(result, StringName(_session.end_reason)))

func _on_hero_died(_cause: StringName) -> void:
	var deceased = _world_ctrl.get_hero() if _world_ctrl != null else null
	if deceased == null:
		return
	if not _has_successor(deceased):
		_end("DEFEAT", &"unsuccessored_death")

func _has_successor(deceased: HeroController) -> bool:
	for f in deceased.followers:
		if f != null and f.path == deceased.path_id:
			return true
	return false

func _on_turn_ended(_turn: int, _month: int) -> void:
	if GameNumbers.ENDGAME_COLLAPSE_ENABLED and _player_cities_left() == 0:
		_end("DEFEAT", &"total_collapse")

func _on_enemy_village_captured(_city: City) -> void:
	if GameNumbers.ENDGAME_COLLAPSE_ENABLED and _player_cities_left() == 0:
		_end("DEFEAT", &"total_collapse")

func _on_glory_changed(_window_total: float) -> void:
	if _cities_mgr != null and _cities_mgr.glory != null \
			and _cities_mgr.glory.total >= GameNumbers.GLORY_VICTORY_THRESHOLD:
		_end("VICTORY", &"path_completed")

func _on_enemy_stack_defeated(_cell: Vector2i, _army: Array) -> void:
	if not GameNumbers.ENDGAME_DOMINATION_ENABLED:
		return
	if _map_gen != null and (_map_gen.enemy_stacks is Dictionary) \
			and (_map_gen.enemy_stacks as Dictionary).is_empty():
		_end("VICTORY", &"domination")

func _on_run_battle_won(_cell: Vector2i) -> void:
	if _session != null:
		_session.battles_won += 1

func _on_run_battle_lost(_cell: Vector2i) -> void:
	if _session != null:
		_session.battles_lost += 1

func _on_run_succession(_hero: Node) -> void:
	if _session != null:
		_session.successions += 1

func _player_cities_left() -> int:
	var left := 0
	if _cities_mgr == null:
		return left
	for city in _cities_mgr.cities:
		if city != null and city.owner == &"player":
			left += 1
	return left

func _end(result: String, reason: StringName) -> void:
	if _session == null or _session.is_terminal():
		return
	_session.state = (
		GameSession.GameState.VICTORY if result == "VICTORY" else GameSession.GameState.DEFEAT)
	_session.end_reason = String(reason)
	var summary := _build_summary(result, reason)
	_show_screen(result, reason, summary)
	GameEventBus.game_ended.emit(result, reason, summary)
	_append_chronicle_entry(result, summary)
	GameLogger.world("Endgame: %s — %s" % [result, String(reason)])

func _append_chronicle_entry(result: String, summary: Dictionary) -> void:
	if _persistence == null:
		return
	var chronicle = _persistence.chronicle
	if chronicle == null:
		return
	var h = _world_ctrl.get_hero() if _world_ctrl != null else null
	var valid := h != null and is_instance_valid(h)
	chronicle.append({
		"hero_name": str(h.hero_name) if valid else "—",
		"path": String(h.path_id) if valid else "",
		"end_turn": int(summary.get("turns", 0)),
		"cities": int(summary.get("cities_owned", 0)),
		"glory": int(summary.get("glory", 0)),
		"battles_won": int(summary.get("battles_won", 0)),
		"battles_lost": int(summary.get("battles_lost", 0)),
		"outcome": result,
	})

func _build_summary(result: String, reason: StringName) -> Dictionary:
	var s := _session
	var turns := 0
	var glory := 0
	if _cities_mgr != null:
		turns = int(_cities_mgr.current_turn)
		if _cities_mgr.glory != null:
			glory = int(round(_cities_mgr.glory.total))
	var date: Dictionary = _persistence.get_date() if _persistence != null else {}
	return {
		"result": result,
		"reason": String(reason),
		"turns": turns,
		"date": {
			"month": int(date.get("month", 1)),
			"week": int(date.get("week", 1)),
			"day": int(date.get("day", 1)),
		},
		"cities_owned": _player_cities_left(),
		"glory": glory,
		"battles_won": int(s.battles_won) if s != null else 0,
		"battles_lost": int(s.battles_lost) if s != null else 0,
		"generations": (int(s.successions) if s != null else 0) + 1,
	}

func _show_screen(result: String, reason: StringName, summary: Dictionary) -> void:
	if _screen == null:
		if _ui_manager != null and is_instance_valid(_ui_manager.game_over_screen):
			_screen = _ui_manager.game_over_screen
		else:
			_screen = GameOverScreenScene.instantiate()
			_screen.name = "GameOverScreen"
			add_child(_screen)
		if not _screen.return_to_menu.is_connected(_return_to_menu):
			_screen.return_to_menu.connect(_return_to_menu)
	_screen.show_result(result, reason, summary)

func _return_to_menu() -> void:

	Services.clear_session()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

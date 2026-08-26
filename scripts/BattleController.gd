extends Node2D
class_name BattleController
## Координатор боя: инициализация, визуал, связка сигналов.
## Логика ходов → BattleTurnExecutor, ввод → BattleInput, AI → BattleAI.
## Контроллер только проигрывает анимации и ждёт их завершения.

signal battle_finished(winner: String, surviving_atk: Array[UnitStack], surviving_def: Array[UnitStack])

var _state: BattleState
var _ai: BattleAI
var _view: BattleView
var _ui: BattleUI
var _input: BattleInput
var _executor: BattleTurnExecutor
var _fx: BattleFX
var obstacles: Dictionary = {}
var _obstacle_seed: int = 777


# ==================== READY ====================
func _ready() -> void:
	_state = BattleState.new()
	_ai = BattleAI.new()

	_view = BattleView.new()
	_view.name = "BattleView"
	add_child(_view)
	_view.setup()
	_view.paint_field()
	_place_obstacles()

	_ui = BattleUI.new()
	_ui.name = "BattleUI"
	add_child(_ui)
	_ui.retreat_requested.connect(_on_retreat)
	_ui.wait_requested.connect(_on_wait)
	_ui.attack_mode_requested.connect(_on_attack_mode)
	_ui.skip_requested.connect(_on_skip)
	_ui.defend_requested.connect(_on_defend)
	_ui.spellbook_requested.connect(_on_spellbook)
	_ui.settings_requested.connect(_on_settings)
	_ui.settings_closed.connect(resume_from_settings)

	_input = BattleInput.new()
	_input.name = "BattleInput"
	add_child(_input)
	_input.setup(_view, _state, obstacles)
	_input.unit_selected.connect(_on_unit_selected)
	_input.unit_move_requested.connect(_on_move_requested)
	_input.unit_attack_requested.connect(_on_attack_requested)
	_input.cancel_requested.connect(_on_cancel)

	_executor = BattleTurnExecutor.new()
	_executor.name = "BattleTurnExecutor"
	add_child(_executor)
	_executor.setup(_state, _ai, obstacles)

	_fx = BattleFX.new()
	_fx.name = "BattleFX"
	add_child(_fx)
	_fx.setup(_view)
	_executor.status_updated.connect(_on_status_updated)
	_executor.clear_highlights.connect(_on_clear_highlights)
	_executor.pulse_unit.connect(_view.pulse_unit)
	_executor.execute_move.connect(_on_execute_move)
	_executor.execute_attack.connect(_on_execute_attack)
	_executor.end_battle.connect(battle_finished.emit)
	_executor.phase_changed.connect(_on_executor_phase_changed)
	_executor.initiative_changed.connect(_on_initiative_changed)
	_executor.active_unit_changed.connect(_ui.update_active_unit)
	_executor.floating_text.connect(_view.show_floating_text)
	_input.attack_preview_updated.connect(_ui.set_attack_preview)

	await get_tree().process_frame
	_view.fit_camera()


func _place_obstacles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _obstacle_seed
	var n := 0
	while n < 8:
		var cell := Vector2i(rng.randi_range(4, BattleState.BW - 5), rng.randi_range(1, BattleState.BH - 2))
		if obstacles.has(cell):
			continue
		obstacles[cell] = true
		var emoji := "🪨" if rng.randf() > 0.5 else "🌳"
		_view.add_obstacle(cell, emoji)
		n += 1


# ==================== INPUT CALLBACKS → EXECUTOR ====================
func _on_unit_selected(u: BattleState.BattleUnit) -> void:
	_on_status_updated("%s: синий контур — ход, красный — атака." % u.get_display_name())
	_ui.update_active_unit(u)
	_ui.set_attack_enabled(_input.highlight_attack.size() > 0)


func _on_move_requested(unit: BattleState.BattleUnit, target: Vector2i) -> void:
	_executor.request_move(unit, target)


func _on_attack_requested(atk: BattleState.BattleUnit, def: BattleState.BattleUnit) -> void:
	if _executor.is_input_active():
		_executor.request_attack(atk, def)


func _on_cancel() -> void:
	_on_status_updated("Выберите существо…")


# ==================== BUTTON CALLBACKS → EXECUTOR ====================
func _on_retreat() -> void:
	_executor.request_retreat()


func _on_wait() -> void:
	_executor.request_wait()


func _on_attack_mode() -> void:
	_input.show_attack_only()
	_on_status_updated("⚔️ Кликните врага с красным контуром.")


func _on_skip() -> void:
	_executor.request_skip()


func _on_defend() -> void:
	_executor.request_defend()


func _on_spellbook() -> void:
	_on_status_updated("📖 Книга заклинаний открыта.")


func _on_settings() -> void:
	# Pause battle and open settings
	_executor.pause_battle()
	_ui.open_settings()


func resume_from_settings() -> void:
	_executor.resume_battle()


# ==================== EXECUTOR ACTIONS → VIEW ====================
func _on_execute_move(unit: BattleState.BattleUnit, path: Array[Vector2i]) -> void:
	var tween := _view.animate_move(unit, path)

	if tween != null:
		await tween.finished

	_executor.on_move_completed()


func _on_execute_attack(
	atk: BattleState.BattleUnit,
	def: BattleState.BattleUnit,
	result: Dictionary
) -> void:
	if def == null:
		_executor.on_attack_completed()
		return

	_view.animate_attack(atk, def)
	_view.update_unit_count(def)
	_view.show_damage_number(def, int(result.get("damage", 0)))

	if result.get("is_retaliation", false):
		_view.show_retaliation_arrow(atk, def)

	if int(result.get("kills", 0)) > 0:
		_view.show_floating_text(
			def.cell,
			"KILLED: %d" % int(result.get("kills", 0)),
			Color.WHITE
		)

	Logger.battle("%s -> %s: damage=%d killed=%d" % [
		atk.get_display_name(),
		def.get_display_name(),
		result.get("damage", 0),
		result.get("kills", 0),
	])

	if def.get_count() <= 0:
		_view.remove_unit(def)

	await get_tree().create_timer(0.35).timeout

	if not is_inside_tree():
		return

	_executor.on_attack_completed()


# ==================== STATUS / HIGHLIGHTS ====================
func _on_status_updated(text: String) -> void:
	_ui.set_status(text)


func _on_clear_highlights() -> void:
	_input.clear_highlights()
	_ui.set_attack_enabled(false)
	_ui.set_attack_preview("")


# ==================== PHASE CHANGED → INPUT LOCK ====================
func _on_executor_phase_changed(phase: BattleTurnExecutor.State) -> void:
	var locked := phase != BattleTurnExecutor.State.WAITING_INPUT

	_input.set_action_lock(locked)
	_ui.set_controls_enabled(not locked)

	if locked:
		_ui.set_attack_enabled(false)

	_on_initiative_changed()


# ==================== START ====================
func start_battle(
	atk: Array[UnitStack],
	def: Array[UnitStack],
	attacker_bonus: Dictionary = {},
	defender_bonus: Dictionary = {},
	attacker_artifact_mods: Dictionary = {},
	defender_artifact_mods: Dictionary = {},
	obstacle_seed: int = 777
) -> void:
	_obstacle_seed = obstacle_seed
	_state.set_hero_bonuses(attacker_bonus, defender_bonus)
	_input.setup_bonuses(attacker_bonus, defender_bonus)
	_state.place_army(atk, def, attacker_artifact_mods, defender_artifact_mods)

	for u in _state.get_units_by_side("attacker"):
		_view.create_unit_sprite(u)

	for u in _state.get_units_by_side("defender"):
		_view.create_unit_sprite(u)

	_view.spawn_hero_figure()
	_view.fit_camera()

	_state.build_queue()
	_executor.start_battle()


func _on_initiative_changed() -> void:
	_ui.update_initiative(_state.turn_queue, _state.active_unit)

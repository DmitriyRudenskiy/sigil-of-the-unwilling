extends Node2D
class_name BattleController

signal battle_finished(winner: BattleState.Side, surviving_atk: Array[UnitStack], surviving_def: Array[UnitStack])

var _state: BattleState
var _ai: BattleAI
@onready var _view: BattleView = $BattleView
@onready var _ui: BattleUI = $BattleUI
var _input: BattleInput
var _executor: BattleTurnExecutor
var _fx: BattleFX
var obstacles: Dictionary = {}
var _obstacle_seed: int = -1
var _hero_magic: HeroMagic = null
var _last_spell_cost := 0

func _ready() -> void:
	_init_state()
	_init_executor()
	_init_input()
	_init_fx()
	_wire_signals()
	_wire_ui_signals()
	_view.setup()
	_view.paint_field()

	await get_tree().process_frame
	_view.fit_camera()

func _init_state() -> void:
	_state = BattleState.new()
	_ai = BattleAI.new()

func _init_executor() -> void:
	_executor = BattleTurnExecutor.new()
	_executor.name = "BattleTurnExecutor"
	add_child(_executor)
	_executor.setup(_state, _ai, obstacles)

func _wire_ui_signals() -> void:
	_ui.retreat_requested.connect(_on_retreat)
	_ui.wait_requested.connect(_on_wait)
	_ui.attack_mode_requested.connect(_on_attack_mode)
	_ui.skip_requested.connect(_on_skip)
	_ui.defend_requested.connect(_on_defend)
	_ui.spellbook_requested.connect(_on_spellbook)
	_ui.spell_chosen.connect(_on_spell_chosen)
	_ui.settings_requested.connect(_on_settings)
	_ui.settings_closed.connect(resume_from_settings)

func _init_input() -> void:
	_input = BattleInput.new()
	_input.name = "BattleInput"
	add_child(_input)
	_input.setup(_view, _state, obstacles)
	_input.unit_pick_requested.connect(_executor.request_select)
	_input.unit_selected.connect(_on_unit_selected)
	_input.unit_move_requested.connect(_on_move_requested)
	_input.unit_attack_requested.connect(_on_attack_requested)
	_input.spell_cast_requested.connect(_on_spell_cast_requested)
	_input.cancel_requested.connect(_on_cancel)

func _init_fx() -> void:
	_fx = BattleFX.new()
	_fx.name = "BattleFX"
	add_child(_fx)
	_fx.setup(_view)

func _wire_signals() -> void:
	_executor.status_updated.connect(_on_status_updated)
	_executor.clear_highlights.connect(_on_clear_highlights)
	_executor.spell_cast_failed.connect(_on_spell_cast_failed)
	_executor.pulse_unit.connect(_view.pulse_unit)
	_executor.execute_move.connect(_on_execute_move)
	_executor.execute_attack.connect(_on_execute_attack)
	_executor.spell_cast_executed.connect(_on_execute_spell)
	_executor.end_battle.connect(battle_finished.emit)
	_executor.phase_changed.connect(_on_executor_phase_changed)
	_executor.initiative_changed.connect(_on_initiative_changed)
	_executor.active_unit_changed.connect(_ui.update_active_unit)
	_executor.floating_text.connect(_view.show_floating_text)
	_input.attack_preview_updated.connect(_ui.set_attack_preview)

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

func _on_unit_selected(u: BattleState.BattleUnit) -> void:
	_on_status_updated(GameText.battle_move_help(u.get_display_name()))
	_ui.update_active_unit(u)
	_ui.set_attack_enabled(_input.highlight_attack.size() > 0)

func _on_move_requested(unit: BattleState.BattleUnit, target: Vector2i) -> void:
	_executor.request_move(unit, target)

func _on_attack_requested(atk: BattleState.BattleUnit, def: BattleState.BattleUnit) -> void:
	if _executor.is_input_active():
		_executor.request_attack(atk, def)

func _on_retreat() -> void:
	_executor.request_retreat()

func _on_wait() -> void:
	_executor.request_wait()

func _on_attack_mode() -> void:
	_input.show_attack_only()
	if _state.active_unit != null and _state.active_unit.is_ranged():
		_input.set_cursor_mode(BattleView.CursorMode.RANGED)
	else:
		_input.set_cursor_mode(BattleView.CursorMode.ATTACK)
	_view.set_cursor_visible(true)
	_on_status_updated(GameText.battle_click_enemy())

func _on_skip() -> void:
	_executor.request_skip()

func _on_defend() -> void:
	_executor.request_defend()

func _on_spellbook() -> void:
	_ui.open_spellbook(_state, _hero_magic)

func _on_spell_chosen(spell_id: StringName) -> void:
	if not _executor.is_input_active():
		return
	var reg: Node = Services.resolve(&"spells")
	if reg == null:
		GameLogger.error("Spell registry unavailable", "Battle")
		return
	var spell = reg.get_spell(spell_id)
	if spell == null:
		GameLogger.warn("Unknown spell: %s" % spell_id, "Battle")
		return
	var ally_side := BattleState.Side.ATTACKER
	var enemy_side := BattleState.Side.DEFENDER
	var side := ally_side if spell.target_type == SpellRegistry.TargetType.SINGLE_ALLY else enemy_side
	var include_dead := spell_id == &"resurrection"
	_executor.request_spell_cast(spell_id)
	_input.start_spell_targeting(spell_id, side, include_dead)

func _on_spell_cast_requested(spell_id: StringName, target: BattleState.BattleUnit) -> void:
	if _hero_magic != null:
		var reg: Node = Services.resolve(&"spells")
		var spell = reg.get_spell(spell_id) if reg != null else null
		if spell == null or not _hero_magic.can_cast_def(spell):
			_ui.set_status(GameText.battle_no_mana())
			return
		var cost = _hero_magic.get_mana_cost_def(spell)
		_hero_magic.spend_mana(cost)
		_last_spell_cost = cost
	_executor.on_spell_target_selected(spell_id, target)

func _on_spell_cast_failed(_reason: String) -> void:
	if _hero_magic != null and _last_spell_cost > 0:
		_hero_magic.refund_mana(_last_spell_cost)
		_last_spell_cost = 0

func _on_cancel() -> void:
	_ui.close_spellbook()
	_input.set_cursor_mode(BattleView.CursorMode.DEFAULT)
	_input.clear_highlights()
	_view.set_cursor_visible(_executor.is_input_active())
	_on_status_updated(GameText.battle_select_unit())

func _on_execute_spell(caster: BattleState.BattleUnit, target: BattleState.BattleUnit, result: Dictionary) -> void:
	_fx.show_spell_cast(target.cell, result.get("spell_id", &""))

	if result.has("healed"):
		_fx.show_heal(target.cell, int(result["healed"]))

	_show_damage_feedback(target, result)
	await _get_damage_wait()

	if not is_inside_tree():
		return

	if result.has("status") and int(result.get("status", -1)) != -1:
		_fx.show_status(target.cell, int(result.get("status")))

	if is_instance_valid(_executor):
		_executor.on_spell_anim_completed()

func _on_settings() -> void:
	_executor.pause_battle()
	_ui.open_settings()

func resume_from_settings() -> void:
	_executor.resume_battle()

func _on_execute_move(unit: BattleState.BattleUnit, path: Array[Vector2i]) -> void:
	var tween := _view.animate_move(unit, path)

	if tween != null:
		await tween.finished
		if not is_inside_tree():
			return

	if is_instance_valid(_executor):
		_executor.on_move_completed()

func _on_execute_attack(
	atk: BattleState.BattleUnit,
	def: BattleState.BattleUnit,
	result: Dictionary
) -> void:
	if def == null:
		if is_instance_valid(_executor):
			_executor.on_attack_completed()
		return

	_show_damage_feedback(def, result)
	await _fx.play_attack_sequence(atk, def, result)

	if not is_inside_tree():
		return

	if is_instance_valid(_executor):
		_executor.on_attack_completed()

func _show_damage_feedback(target: BattleState.BattleUnit, result: Dictionary) -> void:
	_view.update_unit_count(target)
	_view.show_damage_number(target, int(result.get("damage", 0)))
	if int(result.get("kills", 0)) > 0:
		_view.show_floating_text(target.cell, GameText.battle_killed(int(result.get("kills", 0))), Color.WHITE)
	if target.get_count() <= 0:
		_view.remove_unit(target)

func _get_damage_wait() -> SceneTreeTimer:
	return get_tree().create_timer(GameNumbers.BATTLE_SPELL_ANIM_TIME, false)

func _on_status_updated(text: String) -> void:
	_ui.set_status(text)

func _on_clear_highlights() -> void:
	_input.clear_highlights()
	_ui.set_attack_enabled(false)
	_ui.set_attack_preview("")

func _on_executor_phase_changed(phase: BattleTurnExecutor.State) -> void:
	var locked := phase != BattleTurnExecutor.State.WAITING_INPUT

	_input.set_action_lock(locked)
	_ui.set_controls_enabled(not locked)

	if locked:
		_ui.set_attack_enabled(false)
		_input.set_cursor_mode(BattleView.CursorMode.DEFAULT)
		_view.set_cursor_visible(false)
	else:
		_input.set_cursor_mode(BattleView.CursorMode.DEFAULT)
		_view.set_cursor_visible(true)

	_on_initiative_changed()

func start_battle(
	atk: Array[UnitStack],
	def: Array[UnitStack],
	attacker_bonus: Dictionary = {},
	defender_bonus: Dictionary = {},
	attacker_artifact_mods: Dictionary = {},
	defender_artifact_mods: Dictionary = {},
	obstacle_seed: int = -1,
	hero_magic: HeroMagic = null
) -> void:
	_hero_magic = hero_magic
	if obstacle_seed < 0:
		obstacle_seed = randi()
	_obstacle_seed = obstacle_seed
	_place_obstacles()
	_state.set_hero_bonuses(attacker_bonus, defender_bonus)
	_state.place_army(atk, def, attacker_artifact_mods, defender_artifact_mods)

	for u in _state.get_units_by_side(BattleState.Side.ATTACKER):
		_view.create_unit_sprite(u)

	for u in _state.get_units_by_side(BattleState.Side.DEFENDER):
		_view.create_unit_sprite(u)

	_view.spawn_hero_figure()
	_view.fit_camera()

	_executor.start_battle()

func _on_initiative_changed() -> void:
	_ui.update_initiative(_state.turn_queue, _state.active_unit)

func get_battle_state() -> BattleState:
	return _state

func do_retreat() -> void:
	_on_retreat()

func force_retreat() -> void:
	if _executor:
		_executor.force_retreat()

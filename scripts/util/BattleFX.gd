class_name BattleFX
extends Node2D
## Visual and audio FX for battle (spells, damage, morale).
## Attached to the BattleController so it has access to the BattleView.
## Not a singleton; instantiated per battle scene.

var _view: BattleView
var _rng := RandomNumberGenerator.new()

func setup(view: BattleView) -> void:
	_view = view
	_rng.randomize()


func show_spell_cast(cell: Vector2i, spell_id: StringName) -> void:
	if _view == null:
		return

	var school_colors := {
		"air": Color(0.4, 0.7, 1.0),
		"fire": Color(1.0, 0.4, 0.2),
		"water": Color(0.2, 0.6, 0.9),
		"earth": Color(0.5, 0.8, 0.3),
	}

	var color := Color.WHITE
	var spell := Spells.get_spell(spell_id)
	if spell:
		color = school_colors.get(spell.school, Color.WHITE)

	_view.show_floating_text(cell, "SPELL: %s" % spell_id, color)


func show_heal(cell: Vector2i, amount: int) -> void:
	if _view == null:
		return
	_view.show_floating_text(cell, "+%d HP" % amount, Color(0.2, 1.0, 0.4))


func show_damage(cell: Vector2i, amount: int) -> void:
	if _view == null:
		return
	_view.show_floating_text(cell, "-%d HP" % amount, Color(1.0, 0.2, 0.2))


func show_status(cell: Vector2i, status: int) -> void:
	if _view == null:
		return
	_view.show_floating_text(cell, StatusEffects.get_name(status), Color.YELLOW)


func show_morale(cell: Vector2i) -> void:
	if _view == null:
		return
	_view.show_floating_text(cell, "HIGH MORALE!", Color.YELLOW)


func show_retaliation_arrow(from_unit: BattleState.BattleUnit, to_unit: BattleState.BattleUnit) -> void:
	if _view == null:
		return
	_view.show_retaliation_arrow(from_unit, to_unit)


func show_damage_number(unit: BattleState.BattleUnit, damage: int) -> void:
	if _view == null:
		return
	_view.show_damage_number(unit, damage)


func show_kill(cell: Vector2i, count: int) -> void:
	if _view == null:
		return
	_view.show_floating_text(cell, "KILLED: %d" % count, Color.WHITE)


## Play full attack animation sequence: animate → feedback → log → wait.
## @warning: must be awaited — `_executor.on_attack_completed()` fires after timer.
## Asserts `is_inside_tree()` to catch missing `await`.
func play_attack_sequence(
	atk: BattleState.BattleUnit,
	def: BattleState.BattleUnit,
	result: Dictionary,
	wait_time: float = 0.3
) -> SceneTreeTimer:
	assert(is_inside_tree(), "BattleFX.play_attack_sequence: not in tree")
	_view.animate_attack(atk, def)

	if result.get("is_retaliation", false):
		_view.show_retaliation_arrow(atk, def)

	show_damage_number(def, int(result.get("damage", 0)))

	GameLogger.battle("%s -> %s: damage=%d killed=%d" % [
		atk.get_display_name(),
		def.get_display_name(),
		result.get("damage", 0),
		result.get("kills", 0),
	])

	return get_tree().create_timer(wait_time)

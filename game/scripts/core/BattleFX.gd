class_name BattleFX
extends Node2D


var _view: BattleView
var _rng := RandomNumberGenerator.new()

func setup(view: BattleView) -> void:
	_view = view
	_rng.randomize()


func show_spell_cast(cell: Vector2i, spell_id: StringName) -> void:
	if _view == null:
		return

	var school_colors := {
		"air": ThemeConfig.C_SCHOOL_AIR,
		"fire": ThemeConfig.C_SCHOOL_FIRE,
		"water": ThemeConfig.C_SCHOOL_WATER,
		"earth": ThemeConfig.C_SCHOOL_EARTH,
	}

	var color := Color.WHITE
	var spell: Dictionary = _resolve_spell(spell_id)
	if spell:
		color = school_colors.get(spell.get("school", ""), Color.WHITE)

	_view.show_floating_text(cell, GameText.battle_spell_label(spell_id), color)


func show_heal(cell: Vector2i, amount: int) -> void:
	if _view == null:
		return
	_view.show_floating_text(cell, GameText.battle_heal(amount), ThemeConfig.C_TEXT_SUCCESS)


func show_damage(cell: Vector2i, amount: int) -> void:
	if _view == null:
		return
	_view.show_floating_text(cell, GameText.battle_hp_loss(amount), ThemeConfig.C_TEXT_DAMAGE)


func show_status(cell: Vector2i, status: int) -> void:
	if _view == null:
		return
	_view.show_floating_text(cell, StatusEffects.get_name(status), Color.YELLOW)


func show_morale(cell: Vector2i) -> void:
	if _view == null:
		return
	_view.show_floating_text(cell, GameText.battle_high_morale(), ThemeConfig.C_BATTLE_MORALE)


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
	_view.show_floating_text(cell, GameText.battle_killed(count), Color.WHITE)


func play_attack_sequence(
	atk: BattleState.BattleUnit,
	def: BattleState.BattleUnit,
	result: Dictionary,
	wait_time: float = GameNumbers.BATTLE_ATTACK_ANIM_SEC
) -> SceneTreeTimer:
	if not is_inside_tree():
		push_warning("BattleFX.play_attack_sequence: not in tree — sequence skipped")
		return null
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


func _resolve_spell(spell_id: StringName) -> Dictionary:
	var reg: Node = Services.resolve(&"spells")
	if reg != null and reg.has_method("get_spell"):
		var result = reg.get_spell(spell_id)
		if result != null:
			return result
	return {}

## scripts/card/CardSpellResolver.gd
class_name CardSpellResolver
extends RefCounted
## Точка входа: валидация → оплата → диспетчеризация в шаблон.

const _Engine = preload("res://scripts/card/CardTemplateEngine.gd")
const _Utils = preload("res://scripts/card/CardUtils.gd")

static func resolve(
	spell,
	state: Variant,
	caster: Variant,
	target: Variant = null
) -> Dictionary:
	# 1. Валидация
	if spell == null:
		return {"result": "invalid_spell", "effects": []}

	if spell.template.is_empty():
		return {"result": "no_template", "effects": []}

	# 2. Проверка маны
	if caster != null and _has_power(caster):
		if caster.current_power < spell.cost:
			return {"result": "insufficient_power", "effects": []}
		caster.current_power -= spell.cost

	# 3. Проверка influence requirements
	if caster != null:
		for color in spell.influence_req:
			var required: int = int(spell.influence_req[color])
			var current: int = _get_influence(caster, str(color))
			if current < required:
				return {"result": "insufficient_influence", "effects": []}

	# 4. Диспетчеризация в шаблон
	var result: Variant = _Engine.execute(
		spell.template,
		spell.params,
		spell.condition,
		spell.secondary_effects,
		state,
		caster,
		target
	)

	# 5. Логирование
	if result.get("result") == "success" and state != null:
		if _Utils.has_obj_method(state, "add_to_history"):
			state.add_to_history(spell.id, _get_player_id(caster), result.get("effects", []))

	return result


# ==================== УТИЛИТЫ ====================

static func _has_power(obj: Variant) -> bool:
	if obj == null:
		return false
	if obj is Dictionary:
		return obj.has("current_power")
	return false

static func _get_influence(caster: Variant, color: String) -> int:
	if caster == null:
		return 0
	if _Utils.has_obj_method(caster, "get_influence"):
		return caster.get_influence(color)
	if _Utils.has_attr(caster, "influence"):
		var inf: Dictionary = caster.influence
		return int(inf.get(color, 0))
	return 0

static func _get_player_id(caster: Variant) -> Variant:
	if caster == null:
		return null
	if _Utils.has_attr(caster, "player_id"):
		return caster.player_id
	return caster

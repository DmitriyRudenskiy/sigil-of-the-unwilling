class_name TemplateEngine
extends RefCounted

static var _handlers: Dictionary = {}


static func register_handler(template: StringName, handler: Callable) -> void:
	_handlers[template] = handler


static func reset() -> void:
	_handlers.clear()


static func execute(
	template: StringName, params: Dictionary, condition: Dictionary,
	secondary: Array[Dictionary], state: Variant, caster: Variant, target: Variant
) -> Dictionary:
	if not TemplateContext.check_condition(condition, state, caster, target):
		return {"result": "condition_not_met", "effects": []}

	if not _handlers.has(template):
		return {"result": "unknown_template", "template": str(template), "effects": []}

	if template == &"COMBAT_TRICK":
		return _handlers[template].call(params, secondary, state, caster, target)
	return _handlers[template].call(params, state, caster, target)

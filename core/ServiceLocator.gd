## scripts/core/ServiceLocator.gd
class_name ServiceLocator
## Единый резолвер сервисов: инъекция → ServiceContainer → autoload.
## Заменяет дублирующиеся _get_*_registry() функции.

const ServiceContainer = preload("res://core/ServiceContainer.gd")

const _AUTOLOAD: Dictionary = {
	&"units": "Units",
	&"resources": "Resources",
	&"spells": "Spells",
	&"artifacts": "Artifacts",
	&"card_spells": "CardSpells",
}

static func resolve(injected: Node, key: StringName) -> Node:
	if injected != null:
		return injected
	if ServiceContainer.current != null:
		var n: Node = ServiceContainer.current.get(key)
		if n != null:
			return n
	var autoload_name: String = _AUTOLOAD.get(key, "")
	if autoload_name != "":
		return Engine.get_main_loop().root.get_node_or_null(autoload_name)
	return null

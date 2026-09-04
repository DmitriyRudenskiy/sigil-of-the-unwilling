## scripts/core/ServiceLocator.gd
class_name ServiceLocator
## Единый резолвер сервисов: инъекция → ServiceContainer → autoload.
## Заменяет дублирующиеся _get_*_registry() функции.

const _AUTOLOAD: Dictionary = {
	&"units": "Units",
	&"resources": "Resources",
	&"spells": "Spells",
	&"artifacts": "Artifacts",
	&"spellbook": "Spellbook",
}

static func resolve(injected: Node, key: StringName) -> Node:
	if injected != null:
		return injected
	var autoload_name: String = _AUTOLOAD.get(key, "")
	if autoload_name != "":
		return Engine.get_main_loop().root.get_node_or_null(autoload_name)
	return null

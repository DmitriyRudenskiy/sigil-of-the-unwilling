class_name ServiceLocator
## @deprecated Используйте Services.resolve(&"key") напрямую.
## Оставлен для обратной совместимости. Внутри делегирует в Services.

static func resolve(injected: Node, key: StringName) -> Node:
	if injected != null:
		return injected
	var services := _get_services()
	if services != null:
		var service: Object = services.try_resolve(key)
		if service is Node:
			return service
	# Fallback: прямой поиск автозагрузки (для тестов без Services).
	return _resolve_autoload_fallback(key)


static func clear_cache() -> void:
	var services := _get_services()
	if services != null and services.has_method("clear_session"):
		services.call("clear_session")
	else:
		HexUtils.reset()


static func _get_services() -> Node:
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var tree := main_loop as SceneTree
	return tree.root.get_node_or_null("/root/Services")


static func _resolve_autoload_fallback(key: StringName) -> Node:
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var tree := main_loop as SceneTree
	# Пробуем имя как есть, затем с заглавной.
	var name := String(key)
	var node := tree.root.get_node_or_null("/root/" + name)
	if node != null:
		return node
	node = tree.root.get_node_or_null("/root/" + name.capitalize())
	return node

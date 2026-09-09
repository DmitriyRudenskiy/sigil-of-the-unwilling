class_name ServiceRegistry
extends RefCounted

var _singletons: Dictionary = {}
var _autoloads: Dictionary = {}


func register_singleton(key: StringName, service: Object) -> void:
	if key == StringName(""):
		push_error("ServiceRegistry: попытка зарегистрировать сервис с пустым ключом.")
		return
	_singletons[key] = service


func register_autoload(key: StringName, autoload_name: StringName) -> void:
	if key == StringName(""):
		return
	_autoloads[key] = autoload_name


func clear() -> void:
	_singletons.clear()
	_autoloads.clear()


func try_resolve(key: StringName) -> Object:
	if key == StringName(""):
		return null
	if _singletons.has(key):
		return _singletons[key]
	if _autoloads.has(key):
		return _find_autoload(_autoloads[key])
	return null


func resolve(key: StringName) -> Object:
	var service := try_resolve(key)
	if service == null:
		push_error("ServiceRegistry: сервис не найден: %s" % String(key))
	return service


func _find_autoload(autoload_name: StringName) -> Object:
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var tree := main_loop as SceneTree
	var path := "/root/" + String(autoload_name)
	return tree.root.get_node_or_null(path)

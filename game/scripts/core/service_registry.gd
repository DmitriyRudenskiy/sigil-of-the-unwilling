class_name ServiceRegistry
extends RefCounted
## Небольшой DI-контейнер.
##
## Использование:
##   var services: ServiceRegistry = Services.registry
##   var units = services.resolve(&"units")
##
## Регистрация:
##   services.register_singleton(&"units", Units)
##   services.register_factory(&"battle_state_builder", func(reg): return BattleStateBuilder.new())
##
## Внедрение:
##   Если у объекта есть метод inject_services(registry), он будет вызван.

signal service_registered(key: StringName)
signal service_unregistered(key: StringName)

var _singletons: Dictionary = {}
var _factories: Dictionary = {}
var _resolving: Dictionary = {}


func register_singleton(key: StringName, service: Object) -> void:
	if key == StringName(""):
		push_error("ServiceRegistry: попытка зарегистрировать сервис с пустым ключом.")
		return

	_singletons[key] = service
	service_registered.emit(key)


func register_factory(key: StringName, factory: Callable) -> void:
	if key == StringName(""):
		push_error("ServiceRegistry: попытка зарегистрировать фабрику с пустым ключом.")
		return

	if not factory.is_valid():
		push_error("ServiceRegistry: фабрика для ключа '%s' невалидна." % String(key))
		return

	_factories[key] = factory
	service_registered.emit(key)


func register_autoload(key: StringName, autoload_name: StringName) -> void:
	register_factory(
		key,
		func(_registry: ServiceRegistry) -> Object:
			return _find_autoload(autoload_name)
	)


func unregister(key: StringName) -> void:
	var had := false

	if _singletons.has(key):
		_singletons.erase(key)
		had = true

	if _factories.has(key):
		_factories.erase(key)
		had = true

	if had:
		service_unregistered.emit(key)


func clear() -> void:
	_singletons.clear()
	_factories.clear()
	_resolving.clear()


func has_service(key: StringName) -> bool:
	return _singletons.has(key) or _factories.has(key)


func try_resolve(key: StringName) -> Object:
	if key == StringName(""):
		return null

	if _singletons.has(key):
		return _singletons[key]

	if _factories.has(key):
		if _resolving.has(key):
			push_error("ServiceRegistry: циклическое создание сервиса '%s'." % String(key))
			return null

		_resolving[key] = true

		var factory: Callable = _factories[key]
		var service: Object = factory.call(self)

		_resolving.erase(key)

		if service != null:
			_singletons[key] = service

		return service

	return null


func resolve(key: StringName) -> Object:
	var service := try_resolve(key)

	if service == null:
		push_error("ServiceRegistry: сервис не найден: %s" % String(key))

	return service


func inject(target: Object) -> void:
	if target == null:
		return

	if target.has_method("inject_services"):
		target.inject_services(self)


func _find_autoload(autoload_name: StringName) -> Object:
	var main_loop := Engine.get_main_loop()

	if not (main_loop is SceneTree):
		return null

	var tree := main_loop as SceneTree
	var path := "/root/" + String(autoload_name)

	return tree.root.get_node_or_null(path)

extends Node

var registry := ServiceRegistry.new()

func _ready() -> void:
	_register_core_services()

func _register_core_services() -> void:
	registry.register_singleton(&"services", self)
	registry.register_singleton(&"service_registry", registry)

	registry.register_singleton(&"persistence", WorldPersistence.new())

func resolve(key: StringName) -> Object:
	return registry.try_resolve(key)

func register_singleton(key: StringName, service: Object) -> void:
	registry.register_singleton(key, service)

func clear_session() -> void:
	registry.clear()
	_register_core_services()
	StaticCaches.reset_all()

extends Node
## Центральная точка композиции сервисов.

var registry := ServiceRegistry.new()


func _ready() -> void:
	_register_core_services()


func _register_core_services() -> void:
	registry.register_singleton(&"services", self)
	registry.register_singleton(&"service_registry", registry)

	registry.register_autoload(&"units", &"Units")
	registry.register_autoload(&"resources", &"Resources")
	registry.register_autoload(&"spells", &"Spells")
	registry.register_autoload(&"artifacts", &"Artifacts")
	registry.register_autoload(&"spellbook", &"Spellbook")
	registry.register_autoload(&"settings", &"Settings")
	registry.register_autoload(&"event_bus", &"GameEventBus")
	registry.register_autoload(&"sound", &"SoundManager")
	registry.register_autoload(&"cursor", &"CursorController")
	registry.register_autoload(&"tile_atlas_cache", &"TileAtlasCache")
	registry.register_autoload(&"template_bootstrap", &"TemplateBootstrap")

	registry.register_singleton(&"persistence", WorldPersistence.new())


func resolve(key: StringName) -> Object:
	return registry.try_resolve(key)


func register_singleton(key: StringName, service: Object) -> void:
	registry.register_singleton(key, service)


func clear_session() -> void:
	registry.clear()
	_register_core_services()
	StaticCaches.reset_all()

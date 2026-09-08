extends Node
## Центральная точка композиции сервисов.
##
## Важно:
## - Это НЕ статический singleton.
## - Кэш сервисов живёт в экземпляре автозагрузки.
## - При смене сессии можно вызывать clear_session().

var registry := ServiceRegistry.new()


func _ready() -> void:
	_register_core_services()


func _register_core_services() -> void:
	registry.register_singleton(&"services", self)
	registry.register_singleton(&"service_registry", registry)

	# Старые автозагрузки проекта.
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

	# Фабрики для объектов, создаваемых по запросу.
	registry.register_factory(
		&"battle_state_builder",
		func(_services: ServiceRegistry) -> Object:
			return BattleStateBuilder.new()
	)


func resolve(key: StringName) -> Object:
	return registry.try_resolve(key)


func try_resolve(key: StringName) -> Object:
	return registry.try_resolve(key)


func register_singleton(key: StringName, service: Object) -> void:
	registry.register_singleton(key, service)


func register_factory(key: StringName, factory: Callable) -> void:
	registry.register_factory(key, factory)


func register_autoload(key: StringName, autoload_name: StringName) -> void:
	registry.register_autoload(key, autoload_name)


func inject(target: Object) -> void:
	registry.inject(target)


func clear_session() -> void:
	registry.clear()
	_register_core_services()
	# Сброс статического состояния на границе сессии — единая точка: StaticCaches.
	StaticCaches.reset_all()

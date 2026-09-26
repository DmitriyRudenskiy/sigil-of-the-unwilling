extends Node

var registry := ServiceRegistry.new()

func _ready() -> void:
	_register_core_services()

func _register_core_services() -> void:
	registry.register_singleton(&"services", self)
	registry.register_singleton(&"service_registry", registry)

	# persistence требует SaveManager, которого на этапе _ready() этого
	# autoload ещё нет, поэтому создаётся лениво: полноценный объект —
	# в WorldBootstrap._init_services (set_save_manager), а до bootstrap
	# (экраны меню/создания персонажа) здесь — экземпляр без save-менеджера,
	# достаточный для передачи pending_new_game / pending_save.
	var early_persistence := WorldPersistence.new()
	early_persistence.name = "WorldPersistence"
	add_child(early_persistence)
	registry.register_singleton(&"persistence", early_persistence)
	registry.register_autoload(&"event_bus", &"GameEventBus")
	registry.register_singleton(&"resources", Resources)
	registry.register_singleton(&"spells", Spells)
	registry.register_singleton(&"artifacts", Artifacts)
	registry.register_singleton(&"units", Units)
	registry.register_singleton(&"settings", Settings)

func resolve(key: StringName) -> Object:
	return registry.try_resolve(key)

func register_singleton(key: StringName, service: Object) -> void:
	registry.register_singleton(key, service)

func clear_session() -> void:
	registry.clear()
	_register_core_services()
	StaticCaches.reset_all()

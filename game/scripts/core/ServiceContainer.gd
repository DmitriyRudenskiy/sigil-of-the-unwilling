## scripts/core/ServiceContainer.gd
class_name ServiceContainer
extends RefCounted
## Единый контейнер сервисов. Создаётся в WorldBootstrap / BattleController,
## передаётся в подсистемы через setup().
##
## Использование:
##   var services := ServiceContainer.new()
##   services.units = Units          # autoload-реестр
##   services.spells = Spells
##   ...
##   my_system.setup(services)
##
## Для обратной совместимости:
##   ServiceContainer.current = services
##   # В немобилизованном коде:
##   var def := ServiceContainer.current.resources.get_resource(id)

# ==================== РЕЕСТРЫ (RefCounted / Node) ====================
var units: Node = null          # UnitRegistry   (autoload Units)
var resources: Node = null      # ResourceRegistry (autoload Resources)
var spells: Node = null         # SpellRegistry  (autoload Spells)
var artifacts: Node = null      # ArtifactRegistry (autoload Artifacts)
var spellbook: Node = null    # SpellbookRegistry (autoload Spellbook)

# ==================== СИСТЕМНЫЕ СЕРВИСЫ (Node) ====================
var settings: Node = null       # Settings (autoload)
var event_bus: Node = null      # GameEventBus (autoload)

# ==================== ГЛОБАЛЬНЫЙ ДОСТУП (обратная совместимость) ====================
## ponytail: DEPRECATED — глобальный fallback для неомобилизованного кода.
## Единый путь сервисов — DI: передать ServiceContainer через setup() и хранить
## в поле системы. Миграция вызывающих идет по системно (см. R4), а не одним
## махом — чтобы не ломать боёв/героев/карту полуготовой миграцией.
## callers, всё ещё использующие .current: ServiceLocator, MapGenerator,
## WorldBattleCoordinator, BattleController, HeroController.
static var current: ServiceContainer = null

## DEPRECATED — см. comment у `current`. Вызывается ОДИН раз в WorldBootstrap.
static func setup_global(container: ServiceContainer) -> void:
	current = container

## Создаёт контейнер, заполненный из autoload-ов.
## Вызывать только из дерева сцены (autoload уже готовы).
static func from_autoloads() -> ServiceContainer:
	var c := new()
	c.units = Engine.get_main_loop().root.get_node_or_null("Units")
	c.resources = Engine.get_main_loop().root.get_node_or_null("Resources")
	c.spells = Engine.get_main_loop().root.get_node_or_null("Spells")
	c.artifacts = Engine.get_main_loop().root.get_node_or_null("Artifacts")
	c.spellbook = Engine.get_main_loop().root.get_node_or_null("Spellbook")
	c.settings = Engine.get_main_loop().root.get_node_or_null("Settings")
	c.event_bus = Engine.get_main_loop().root.get_node_or_null("GameEventBus")
	return c

## Валидация: все критичные сервисы на месте.
func validate() -> Array[String]:
	var missing: Array[String] = []
	if units == null:
		missing.append("units")
	if resources == null:
		missing.append("resources")
	if spells == null:
		missing.append("spells")
	if artifacts == null:
		missing.append("artifacts")
	return missing

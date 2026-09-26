class_name HeroComponent
extends Node
## Базовый класс для всех компонентов героя.
## Каждый компонент получает ссылку на контроллер через _hero.
## Компоненты НЕ обращаются друг к другу напрямую — только через сигналы
## или через _hero, когда это явно необходимо.

var _hero: HeroController = null

## Вызывается контроллером сразу после добавления в дерево.
func setup_hero(hero: HeroController) -> void:
	_hero = hero

## Фаза инициализации после того, как все компоненты зарегистрированы.
## Переопределять для логики, зависящей от других компонентов.
func initialize() -> void:
	pass

## Конец хода героя.
func end_turn() -> void:
	pass

## Сериализация состояния компонента.
func serialize() -> Dictionary:
	return {}

## Десериализация состояния компонента.
func deserialize(_data: Dictionary) -> void:
	pass

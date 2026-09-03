extends "res://tests/test_base.gd"
## hero-lifecycle: изолированное тестирование HeroLifecycleSystem (RefCounted,
## detached — без дерева сцены). Охватываем то, чего нет в
## test_worldcontroller_succession_wiring (выбор преемника) / test_hero_combat_death
## (гейт смерти): перепричинение (re-wiring потребителей героя), выбор преемника
## / воскрешения.

const _HeroLifecycle = preload("res://scripts/world/HeroLifecycleSystem.gd")
const _Hero = preload("res://scripts/entities/HeroController.gd")
const _Succession = preload("res://scripts/world/SuccessionController.gd")
const _City = preload("res://scripts/world/City.gd")
const _CityManager = preload("res://scripts/world/CityManager.gd")

## Хост-координатор: Node2D с get_hero/set_hero (владеет активным героем).
class MockHost extends Node2D:
	var _hero: HeroController = null
	func get_hero() -> HeroController:
		return _hero
	func set_hero(h: HeroController) -> void:
		_hero = h

## Потребитель героя: battle_coordinator / interaction_controller держат реф.
class MockConsumer extends RefCounted:
	var hero: Node = null

## bootstrap_result: enemy-ai + input + shortcuts — каждый держит hero.
## (re-wiring после перепричинения: иначе ИИ/ввод смотрят на freed-героя.)
class MockBootstrap extends RefCounted:
	var enemy_proc = null
	var input_controller = null
	var shortcuts = null
	func _init() -> void:
		enemy_proc = MockConsumer.new()
		input_controller = MockConsumer.new()
		shortcuts = MockConsumer.new()

## Собрать HeroLifecycleSystem с подставленными потребителями (map_gen/event_router/
## ui_manager/camera — null, headless; все ветки загеджены).
func _make_sys(host: Node2D, bc: MockConsumer, ic: MockConsumer, boot: MockBootstrap) -> RefCounted:
	var sys := _HeroLifecycle.new()
	sys.setup(
		host,        # p (world)
		null,        # persistence
		null,        # rng
		null,        # cities
		null,        # map_gen (headless — setup героя пропускается)
		null,        # event_router
		null,        # ui_manager
		bc,          # battle_coordinator
		ic,          # interaction_controller
		boot,        # bootstrap_result
		null,        # succession
		null         # camera
	)
	return sys

func test_install_hero_rewires_all_consumers() -> void:
	var host := MockHost.new()
	root.add_child(host)
	var bc := MockConsumer.new()
	var ic := MockConsumer.new()
	var boot := MockBootstrap.new()
	var sys := _make_sys(host, bc, ic, boot)

	var hero := _Hero.new()
	hero.path_id = &"archivist"
	sys._install_hero(hero)

	assert_eq(host.get_hero(), hero, "active hero pointer обновлён")
	assert_true(host.has_child(hero), "герой добавлен в мир")
	assert_eq(bc.hero, hero, "battle_coordinator перенаправлен на героя")
	assert_eq(ic.hero, hero, "interaction_controller перенаправлен на героя")
	assert_eq(boot.enemy_proc.hero, hero, "enemy-ai перенаправлен на героя")
	assert_eq(boot.input_controller.hero, hero, "input перенаправлен на героя")
	assert_eq(boot.shortcuts.hero, hero, "shortcuts перенаправлен на героя")

	hero.free()
	host.free()

func test_find_resurrection_city_null_when_already_resurrected() -> void:
	## _find_resurrection_city требует _succession + _cities (гвард), но
	## resurrected_once отсеивает ДО проверки городов.
	var sys := _HeroLifecycle.new()
	var controller := _Succession.new()
	var mgr := _CityManager.new()
	sys.setup(
		null, null, null, mgr, null, null, null,
		null, null, null, controller, null
	)
	var deceased := _Hero.new()
	deceased.resurrected_once = true
	assert_null(sys._find_resurrection_city(deceased),
		"уже воскрешал — вариант воскрешения нет")
	deceased.free()
	(controller).free()
	(mgr).free()
	sys.free()

func test_find_resurrection_city_null_when_no_cities() -> void:
	## Пустой мир — выбирать не из чего → null (воскрешения нет).
	var sys := _HeroLifecycle.new()
	var controller := _Succession.new()
	var mgr := _CityManager.new()
	sys.setup(
		null, null, null, mgr, null, null, null,
		null, null, null, controller, null
	)
	var deceased := _Hero.new()
	assert_null(sys._find_resurrection_city(deceased),
		"нет городов — воскрешение недоступно")
	deceased.free()
	(controller).free()
	(mgr).free()
	sys.free()

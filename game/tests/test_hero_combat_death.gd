extends "res://tests/test_base.gd"
## succession-sigil: поражение в бою + полное уничтожение армии → смерть героя.
## Проверяет гатя смерти в WorldBattleCoordinator._apply_results.

const _Coordinator = preload("res://scripts/world/WorldBattleCoordinator.gd")
const _Hero = preload("res://scripts/entities/HeroController.gd")
const _HeroArmy = preload("res://scripts/entities/HeroArmyController.gd")
const _BattleState = preload("res://scripts/systems/BattleState.gd")
const _UnitStack = preload("res://scripts/entities/UnitStack.gd")

var _hero = null

func _cleanup_test(on_died: Callable) -> void:
	## Армия — свойство героя (не child), free() героя её не освобождает.
	var a: Variant = _hero.get("army")
	(_hero).free()
	_hero = null
	if a != null:
		a.free()
	GameEventBus.hero_died.disconnect(on_died)

func _make_hero(path: StringName = &"rebel") -> HeroController:
	var h := _Hero.new()
	## max_combat_hp по умолчанию 0 → set_combat_hp схлопнется в 0, и герой
	## сразу «мертв» по is_combat_dead(). Задаем запас, иначе тест не рабочий.
	h.max_combat_hp = 20
	h.set_combat_hp(20)
	h.path_id = path
	## _ready() в detached SceneTree не вызывается → army null. Координатор в
	## _apply_results сначала вызывает hero.apply_battle_results(), который
	## упал бы на null-army и прервал метод до гатя смерти. Даем валидную армию,
	## не пустую, чтобы не триггерить фолбэк с реестром юнитов.
	h.army = _HeroArmy.new()
	h.army.army = [_UnitStack.new(null, 10)]
	return h

func _make_coord(enabled: bool = true) -> Object:
	var c := _Coordinator.new()
	c.rng = RandomNumberGenerator.new()
	c.hero = _hero
	c.battle_death_enabled = enabled
	c._pending_enemy_cell = Vector2i(3, 4)
	return c


func test_battle_loss_zero_hp_emits_hero_died() -> void:
	var data: Dictionary = {}
	var on_died := func(cause: Variant): data["cause"] = cause
	GameEventBus.hero_died.connect(on_died)

	_hero = _make_hero()
	var coord := _make_coord(true)

	# Поражение (DEFENDER) + полное уничтожение армии (пустые массивы).
	var empty_u: Array[UnitStack] = []
	coord.call("_apply_results", _BattleState.Side.DEFENDER, empty_u, empty_u)

	assert_true(_hero.is_combat_dead(), "hero is_combat_dead after annihilation loss")
	assert_false(_hero.get("is_alive"), "hero marked dead (is_alive = false)")
	assert_eq(data.get("cause"), &"battle", "hero_died(&\"battle\") emitted")

	_cleanup_test(on_died)
	coord.free()


func test_battle_won_no_death() -> void:
	var data: Dictionary = {}
	var on_died := func(cause: Variant): data["cause"] = cause
	GameEventBus.hero_died.connect(on_died)

	_hero = _make_hero()
	var coord := _make_coord(true)

	# Победа (ATTACKER) — герой жив, hero_died НЕ испускается.
	var empty_u: Array[UnitStack] = []
	coord.call("_apply_results", _BattleState.Side.ATTACKER, empty_u, empty_u)

	assert_true(_hero.is_combat_dead() == false, "hero alive after victory")
	assert_true(not data.has("cause"), "no hero_died on victory")

	_cleanup_test(on_died)
	coord.free()


func test_death_gate_can_be_disabled() -> void:
	var data: Dictionary = {}
	var on_died := func(cause: Variant): data["cause"] = cause
	GameEventBus.hero_died.connect(on_died)

	_hero = _make_hero()
	var coord := _make_coord(false)

	# Гать выключена → смерть НЕ наступает даже при поражении.
	var empty_u: Array[UnitStack] = []
	coord.call("_apply_results", _BattleState.Side.DEFENDER, empty_u, empty_u)

	assert_false(_hero.is_combat_dead(), "no death when gate disabled")
	assert_true(not data.has("cause"), "no hero_died when gate disabled")

	_cleanup_test(on_died)
	coord.free()

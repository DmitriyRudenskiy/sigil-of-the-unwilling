extends GdUnitTestSuite

const _Coordinator = preload("res://scripts/world/WorldBattleCoordinator.gd")
const _Hero = preload("res://scripts/entities/HeroController.gd")
const _HeroArmy = preload("res://scripts/entities/HeroArmyController.gd")
const _BattleState = preload("res://scripts/systems/BattleState.gd")
const _UnitStack = preload("res://scripts/entities/UnitStack.gd")

var _hero = null

func _cleanup_test(on_died: Callable) -> void:
	var a: Variant = _hero.get("army")
	(_hero).free()
	_hero = null
	if a != null:
		a.free()
	GameEventBus.hero_died.disconnect(on_died)

## R8: база героя — TestFactories.make_hero, здесь только армия и боевой HP.
func _combat_hero(path: StringName = &"rebel") -> HeroController:
	var h := TestFactories.make_hero(path)
	h.max_combat_hp = 20
	h.set_combat_hp(20)
	h.army = _HeroArmy.new()
	h.army.army = [_UnitStack.new(null, 10)]
	return h

func _make_coord(enabled: bool = true) -> Object:
	var c := _Coordinator.new()
	c.rng = TestFactories.seeded(7966)
	c.hero = _hero
	c.battle_death_enabled = enabled
	c._pending_enemy_cell = Vector2i(3, 4)
	return c


func test_battle_loss_zero_hp_emits_hero_died() -> void:
	var data: Dictionary = {}
	var on_died := func(cause: Variant): data["cause"] = cause
	GameEventBus.hero_died.connect(on_died)

	_hero = _combat_hero()
	var coord := _make_coord(true)

	var empty_u: Array[UnitStack] = []
	coord.call("_apply_results", _BattleState.Side.DEFENDER, empty_u, empty_u)

	assert_bool(_hero.is_combat_dead()).is_true()
	assert_bool(_hero.get("is_alive")).is_false()
	assert_that(data.get("cause")).is_equal(&"battle")

	_cleanup_test(on_died)
	coord.free()


func test_battle_won_no_death() -> void:
	var data: Dictionary = {}
	var on_died := func(cause: Variant): data["cause"] = cause
	GameEventBus.hero_died.connect(on_died)

	_hero = _combat_hero()
	var coord := _make_coord(true)

	var empty_u: Array[UnitStack] = []
	coord.call("_apply_results", _BattleState.Side.ATTACKER, empty_u, empty_u)

	assert_bool(_hero.is_combat_dead() == false).is_true()
	assert_bool(not data.has("cause")).is_true()

	_cleanup_test(on_died)
	coord.free()


func test_death_gate_can_be_disabled() -> void:
	var data: Dictionary = {}
	var on_died := func(cause: Variant): data["cause"] = cause
	GameEventBus.hero_died.connect(on_died)

	_hero = _combat_hero()
	var coord := _make_coord(false)

	var empty_u: Array[UnitStack] = []
	coord.call("_apply_results", _BattleState.Side.DEFENDER, empty_u, empty_u)

	assert_bool(_hero.is_combat_dead()).is_false()
	assert_bool(not data.has("cause")).is_true()

	_cleanup_test(on_died)
	coord.free()

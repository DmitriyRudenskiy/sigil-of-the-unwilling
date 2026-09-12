extends BaseTest






var _hero = null

func _cleanup_test(on_died: Callable) -> void:
	var a: Variant = _hero.get("army")
	(_hero).free()
	_hero = null
	if a != null:
		a.free()
	GameEventBus.hero_died.disconnect(on_died)

func _combat_hero(path: StringName = &"rebel") -> HeroController:
	var h := TestFactories.make_hero(path)
	h.max_combat_hp = 20
	h.set_combat_hp(20)
	h.army = HeroArmyController.new()
	h.army.army = [UnitStack.new(null, 10)]
	return h

func _make_coord(enabled: bool = true) -> Object:
	var c = auto_free( WorldBattleCoordinator.new())
	c.rng = TestFactories.seeded(7966)
	c.hero = _hero
	c.battle_death_enabled = enabled
	c._pending_enemy_cell = Vector2i(3, 4)
	return c

func test_battle_loss_hero_wounded_not_dead() -> void:
	var data: Dictionary = {}
	var on_died := func(cause: Variant): data["cause"] = cause
	GameEventBus.hero_died.connect(on_died)

	_hero = _combat_hero()
	var coord := _make_coord(true)

	var empty_u: Array[UnitStack] = []
	coord.call("_apply_results", BattleState.Side.DEFENDER, empty_u, empty_u)

	# Ранняя игра: герой не погибает в одном бою — раненый выживает (early-game-foundation)
	assert_bool(_hero.is_combat_dead() == false).is_true()
	assert_that(_hero.get("combat_hp")).is_equal(1)
	assert_bool(not data.has("cause")).is_true()

	_cleanup_test(on_died)
	coord.free()

func test_battle_won_no_death() -> void:
	var data: Dictionary = {}
	var on_died := func(cause: Variant): data["cause"] = cause
	GameEventBus.hero_died.connect(on_died)

	_hero = _combat_hero()
	var coord := _make_coord(true)

	var empty_u: Array[UnitStack] = []
	coord.call("_apply_results", BattleState.Side.ATTACKER, empty_u, empty_u)

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
	coord.call("_apply_results", BattleState.Side.DEFENDER, empty_u, empty_u)

	assert_bool(_hero.is_combat_dead()).is_false()
	assert_bool(not data.has("cause")).is_true()

	_cleanup_test(on_died)
	coord.free()

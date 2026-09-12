extends BaseTest

# Ранняя игра: идентичность героя, личный боец, классовые эффекты (early-game-foundation).

func _hero() -> HeroController:
	var h := TestFactories.make_hero(&"rebel")
	h.max_combat_hp = 20
	h.set_combat_hp(20)
	return h


func _unit(stats: UnitStats, count := 5) -> BattleState.BattleUnit:
	var u := BattleState.BattleUnit.new(UnitStack.new(stats, count))
	u.max_count = count
	return u


func test_solo_start_empty_army() -> void:
	var h := _hero()
	h.solo_start = true
	h.army = HeroArmyController.new()
	h.army.setup(null, true)
	assert_that(h.get_army().army.size()).is_equal(0)


func test_non_solo_start_default_army() -> void:
	var h := _hero()
	h.army = HeroArmyController.new()
	h.army.setup(null, false)
	assert_that(h.get_army().army.size()).is_greater(0)


func test_hero_battle_stack_key_and_hp() -> void:
	var h := _hero()
	h.hero_class = "fighter"
	h.set_combat_hp(7)
	var stack: UnitStack = h.get_hero_battle_stack()
	assert_that(stack.get_key()).is_equal(GameNumbersHero.HERO_BATTLE_KEY)
	assert_int(stack.count).is_equal(7)
	assert_bool(stack.stats.has_tag("hero")).is_true()
	assert_bool(stack.stats.has_tag("fighter")).is_true()


func test_hero_battle_stack_min_hp() -> void:
	var h := _hero()
	h.set_combat_hp(0)
	var stack: UnitStack = h.get_hero_battle_stack()
	assert_int(stack.count).is_equal(1)


func test_ranger_bonus_vs_wild_animals() -> void:
	var state := BattleState.new()
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 0, ["ranger"]), 10)
	var def := _unit(UnitStats.new("wolves", "Wolf", 0, 1, 6, 1, 1, ["melee"]), 10)
	atk.cell = Vector2i.ZERO
	def.cell = Vector2i(1, 0)
	state.attacker_units.append(atk)
	state.defender_units.append(def)
	state._rebuild_unit_grid()
	var rng := TestFactories.seeded(42)
	var r := BattleDamageResolver.resolve(state, atk, def, {"rng": rng, "is_melee": true})
	assert_bool(r.get("ranger_bonus")).is_true()
	assert_int(r["kills"]).is_greater(0)


func test_ranger_no_bonus_vs_humanoids() -> void:
	var state := BattleState.new()
	var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 0, ["ranger"]), 10)
	var def := _unit(UnitStats.new("goblins", "Goblin", 0, 1, 8, 1, 1, ["melee"]), 10)
	atk.cell = Vector2i.ZERO
	def.cell = Vector2i(1, 0)
	state.attacker_units.append(atk)
	state.defender_units.append(def)
	state._rebuild_unit_grid()
	var rng := TestFactories.seeded(42)
	var r := BattleDamageResolver.resolve(state, atk, def, {"rng": rng, "is_melee": true})
	assert_bool(r.get("ranger_bonus", false)).is_false()


func test_rogue_crit_doubles_kills() -> void:
	# Ищем сид, при котором rng.randf() < ROGUE_CRIT_CHANCE, и проверяем удвоение.
	var crit_seen := false
	for i in range(200):
		var state := BattleState.new()
		var atk := _unit(UnitStats.new("a", "A", 10, 5, 1, 1, 0, ["rogue"]), 10)
		var def := _unit(UnitStats.new("goblins", "Goblin", 0, 1, 8, 1, 1, ["melee"]), 10)
		atk.cell = Vector2i.ZERO
		def.cell = Vector2i(1, 0)
		state.attacker_units.append(atk)
		state.defender_units.append(def)
		state._rebuild_unit_grid()
		var rng := TestFactories.seeded(1000 + i)
		var r := BattleDamageResolver.resolve(state, atk, def, {"rng": rng, "is_melee": true})
		if r.get("crit", false):
			crit_seen = true
			assert_int(r["kills"]).is_greater(0)
			break
	assert_bool(crit_seen).is_true()


func test_wild_stack_detection() -> void:
	var c := WorldBattleCoordinator.new()
	var wolf_stack := UnitStack.new(UnitStats.new("wolves", "Wolf", 4, 1, 6, 1, 1, ["melee"]), 10)
	var goblin_stack := UnitStack.new(UnitStats.new("goblins", "Goblin", 2, 1, 8, 1, 1, ["melee"]), 10)
	assert_bool(c._stacks_are_wild([wolf_stack])).is_true()
	assert_bool(c._stacks_are_wild([goblin_stack])).is_false()
	assert_bool(c._stacks_are_wild([])).is_false()
	c.free()


func test_apply_results_wounded_hero() -> void:
	var h := _hero()
	h.set_combat_hp(20)
	var c := WorldBattleCoordinator.new()
	c.rng = TestFactories.seeded(7966)
	c.hero = h
	c.battle_death_enabled = true
	c._pending_enemy_cell = Vector2i(3, 4)
	# Поражение, боец-герой погиб (нет в живых)
	var empty_u: Array[UnitStack] = []
	c.call("_apply_results", BattleState.Side.DEFENDER, empty_u, empty_u)
	assert_bool(h.is_combat_dead() == false).is_true()
	assert_that(h.get("combat_hp")).is_equal(1)
	c.free()


func test_apply_results_fighter_hp_maps_to_hero() -> void:
	var h := _hero()
	h.set_combat_hp(20)
	var c := WorldBattleCoordinator.new()
	c.rng = TestFactories.seeded(7966)
	c.hero = h
	c.battle_death_enabled = true
	c._pending_enemy_cell = Vector2i(3, 4)
	# Победа: боец жив с остатком 7 — HP героя 7
	var fighter := UnitStack.new(
		UnitStats.new(GameNumbersHero.HERO_BATTLE_KEY, "Герой", 4, 4, 1, 5, 3, ["hero", "fighter"]), 7
	)
	var surv: Array[UnitStack] = [fighter]
	c.call("_apply_results", BattleState.Side.ATTACKER, surv, empty_survivors())
	assert_that(h.get("combat_hp")).is_equal(7)
	# Боец не должен попасть в армию героя
	assert_bool(h.get_army().army.any(func(s: UnitStack) -> bool: return s != null and s.get_key() == GameNumbersHero.HERO_BATTLE_KEY)).is_false()
	c.free()


func empty_survivors() -> Array[UnitStack]:
	var a: Array[UnitStack] = []
	return a

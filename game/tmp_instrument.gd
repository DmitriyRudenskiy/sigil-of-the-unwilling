extends SceneTree
func _init() -> void:
	var _Coordinator = preload("res://scripts/world/WorldBattleCoordinator.gd")
	var _Hero = preload("res://scripts/entities/HeroController.gd")
	var _HeroArmy = preload("res://scripts/entities/HeroArmyController.gd")
	var _UnitStack = preload("res://scripts/entities/UnitStack.gd")
	var _BattleState = preload("res://scripts/systems/BattleState.gd")
	var h = _Hero.new()
	h.max_combat_hp = 20
	h.set_combat_hp(20)
	h.army = _HeroArmy.new()
	var stacks: Array[UnitStack] = [_UnitStack.new(null, 10)]
	h.army.army = stacks
	var c = _Coordinator.new()
	c.rng = RandomNumberGenerator.new()
	c.hero = h
	c.battle_death_enabled = true
	c._pending_enemy_cell = Vector2i(3,4)
	print("PROBE pre combat_hp=" + str(h.get("combat_hp")) + " is_combat_dead=" + str(h.call("is_combat_dead")))
	var empty: Array[UnitStack] = []
	c.call("_apply_results", _BattleState.Side.DEFENDER, empty, empty)
	print("PROBE post combat_hp=" + str(h.get("combat_hp")) + " is_combat_dead=" + str(h.call("is_combat_dead")) + " is_alive=" + str(h.get("is_alive")))
	quit()

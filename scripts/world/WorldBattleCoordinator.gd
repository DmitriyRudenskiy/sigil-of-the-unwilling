extends Node
class_name WorldBattleCoordinator
## Handles enemy contact, battle lifecycle, and post-battle results.

const UnitStack = preload("res://scripts/unit_stack.gd")

var hero: HeroController
var map_gen: MapGenerator
var spawner: WorldSpawner
var battle_flow: BattleFlow
var rng: RandomNumberGenerator

var _pending_enemy_cell: Vector2i = Vector2i(-1, -1)


func setup(h: HeroController, m: MapGenerator, s: WorldSpawner, bf: BattleFlow, r: RandomNumberGenerator) -> void:
	hero = h
	map_gen = m
	spawner = s
	battle_flow = bf
	rng = r


func connect_battle_signals(owner: Node) -> void:
	battle_flow.battle_started.connect(owner._on_battle_started)
	battle_flow.battle_completed.connect(owner._on_battle_completed)


func check_enemy_contact(cell: Vector2i) -> void:
	if map_gen.enemy_stacks.has(cell):
		start_battle(map_gen.enemy_stacks[cell], cell)
		return
	for nb in HexUtils.get_all_neighbors(cell):
		if map_gen.enemy_stacks.has(nb):
			start_battle(map_gen.enemy_stacks[nb], nb)
			return


func start_battle(enemy_army: Array[UnitStack], enemy_cell: Vector2i) -> void:
	if battle_flow == null or hero == null:
		return

	_pending_enemy_cell = enemy_cell
	hero.force_stop()

	var attacker_bonus: Dictionary = hero.get_battle_bonus()
	var defender_bonus: Dictionary = {}
	if spawner != null:
		defender_bonus = spawner.get_enemy_defender_bonus()

	battle_flow.start_battle(
		hero.get_army_for_battle(),
		enemy_army,
		attacker_bonus,
		defender_bonus,
		hero.inventory.get_total_modifiers(),
		{},
		rng.randi()  # obstacle_seed derived from run_seed
	)


func on_battle_completed(winner: String, surv_atk: Array[UnitStack], surv_def: Array[UnitStack]) -> void:
	if hero == null:
		return

	hero.apply_battle_results(surv_atk)

	if hero.army.army.is_empty():
		var fallback: Array[UnitStack] = []
		var stack := Units.make_fixed_stack("swordsmen", 10)
		if stack != null:
			fallback.append(stack)

		hero.army.apply_battle_results(fallback)
		GameLogger.hero("Hero routed: awarded minimal stack")

	if winner == "attacker":
		map_gen.enemy_stacks.erase(_pending_enemy_cell)
		if spawner:
			spawner.remove_enemy_at(_pending_enemy_cell)
		GameLogger.battle("Enemy defeated at %s" % _pending_enemy_cell)
	else:
		GameLogger.battle("Battle lost / retreated")

	_pending_enemy_cell = Vector2i(-1, -1)

	if winner == "attacker" and hero.inventory != null:
		if rng.randf() < GameSettings.MONSTER_DROP_CHANCE:
			var arts := Artifacts.get_by_rarity(Artifact.Rarity.MINOR)
			if arts.size() > 0:
				var drop := arts[rng.randi() % arts.size()]
				if hero.inventory.add_to_backpack(drop):
					GameLogger.world("Monster drop: %s" % drop.display_name)
				else:
					GameLogger.world("Backpack full, drop lost!")


func get_pending_enemy_cell() -> Vector2i:
	return _pending_enemy_cell

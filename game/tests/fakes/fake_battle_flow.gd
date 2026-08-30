extends BattleFlow
## Тестовый фейк: фиксирует вызовы start_battle без инстанцирования сцены боя.
var started := 0
var last_enemy_army: Array = []

func start_battle(
	attacker_army: Array[UnitStack],
	defender_army: Array[UnitStack],
	attacker_bonus: Dictionary = {},
	defender_bonus: Dictionary = {},
	attacker_artifact_mods: Dictionary = {},
	defender_artifact_mods: Dictionary = {},
	obstacle_seed: int = -1,
	hero_magic: Variant = null
) -> void:
	started += 1
	last_enemy_army = defender_army

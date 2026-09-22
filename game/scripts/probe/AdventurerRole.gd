class_name AdventurerRole
extends ScenarioRole
## autopilot-scenario-matrix: Приключенец — логово второго кольца.
## Политика: охота на отряды 2-го кольца (12..24 от старта), без сбора
## ресурсов; базовый цикл сам защищает город и следит за потребностями.

var _kills := 0

func _in_ring(cell: Vector2i, pilot: Node) -> bool:
	# Старт = центр города (точка появления героя).
	var start: Vector2i = pilot._city_center()
	if start == Vector2i(-1000, -1000):
		return false
	var d: int = HexUtils.hex_distance(cell, start)
	return d >= MapSpawner.THREAT_RING2_RADIUS and d < MapSpawner.THREAT_RING3_RADIUS

func collect_target(_pilot: Node):
	return Vector2i(-1, -1)  # сбор не нужен — только охота

func enemy_target(pilot: Node):
	var here: Vector2i = pilot._hero_cell()
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c in pilot._map().enemy_stacks.keys():
		if not _in_ring(c, pilot):
			continue
		var d := HexUtils.hex_distance(c, here)
		if d > 0 and d < best_d:
			best_d = d
			best = c
	return best if best != Vector2i(-1, -1) else null

func on_battle_won(pilot: Node, cell: Vector2i) -> void:
	if _in_ring(cell, pilot):
		_kills += 1

func goal_met(pilot: Node) -> bool:
	return _kills >= int(target.get("kill_goal", 5))

func metrics(pilot: Node) -> Dictionary:
	return {
		"kills": _kills,
		"kill_goal": int(target.get("kill_goal", 5)),
		"boss_ring": int(target.get("boss_ring", 2)),
		"turns": pilot.turn,
		"hp": int(pilot._hero.combat_hp) if pilot._hero != null else 0,
		"survived": survived(pilot),
	}

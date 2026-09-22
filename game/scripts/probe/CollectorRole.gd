class_name CollectorRole
extends ScenarioRole
## autopilot-scenario-matrix: Собиратель — собрать N редких ресурсов за 60 ходов.
## Политика: приоритет — редкие узлы (кристалл/самоцветы/золото); если
## редких в поле зрения нет — базовая логика (любой узел, выживаемость).

func collect_target(pilot: Node):
	var sp: Node = pilot._spawner
	if sp == null:
		return null
	var here: Vector2i = pilot._hero_cell()
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c in pilot._map().resource_cells.keys():
		var rt: int = int(sp.get_res_type_at(c))
		if rt < 0 or not (target.get("rare_ids", []) as Array).has(rt):
			continue
		var d := HexUtils.hex_distance(c, here)
		if d > 0 and d < best_d:
			best_d = d
			best = c
	return best if best != Vector2i(-1, -1) else null

func goal_met(pilot: Node) -> bool:
	return pilot.rare_count() >= int(target.get("rare_goal", 0))

func metrics(pilot: Node) -> Dictionary:
	var t: int = maxi(1, pilot.turn)
	return {
		"rare_extracted": pilot.rare_count(),
		"rare_goal": int(target.get("rare_goal", 0)),
		"resources_extracted": pilot.extracted_total,
		"resources_per_day": float(pilot.extracted_total) / float(t),
		"survived": survived(pilot),
	}

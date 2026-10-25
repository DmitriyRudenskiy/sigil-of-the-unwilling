class_name CollectorRole
extends ScenarioRole
## autopilot-scenario-matrix: Собиратель — собрать N редких ресурсов за 60 ходов.
## Политика: приоритет — редкие узлы (кристалл/самоцветы/золото); если
## редких в поле зрения нет — базовая логика (любой узел, выживаемость).
##
## Единицы и узлы — разные числа (задача 4.2, T-209): `rare_goal = 10` считается
## движком в ЕДИНИЦАХ добычи, а у золота `pickup_amount = 50` на узел. Один найденный
## золотой узел закрывает цель с пятикратным запасом и завершает забег, поэтому
## метрика `rare_nodes` (сколько узлов снято) печатается рядом с `rare_extracted`
## (сколько единиц): без неё строка матрицы выдаёт удачу спавна за политику роли.
## `rare_targets_seen` — сколько РАЗНЫХ редких клеток политика вообще выбрала целью:
## «не нашёл», «не дошёл» и «дошёл, но не собрал» — три разных диагноза (4.2).

var _seen_targets: Array = []

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
	if best == Vector2i(-1, -1):
		return null
	if not _seen_targets.has(best):
		_seen_targets.append(best)
	return best

func goal_met(pilot: Node) -> bool:
	return pilot.rare_count() >= int(target.get("rare_goal", 0))

func metrics(pilot: Node) -> Dictionary:
	var t: int = maxi(1, pilot.turn)
	return {
		"rare_extracted": pilot.rare_count(),
		"rare_nodes": pilot.rare_nodes(),
		"rare_targets_seen": _seen_targets.size(),
		"rare_goal": int(target.get("rare_goal", 0)),
		"resources_extracted": pilot.extracted_total,
		"resource_nodes_extracted": pilot.extracted_nodes,
		"resources_per_day": float(pilot.extracted_total) / float(t),
		"survived": survived(pilot),
	}

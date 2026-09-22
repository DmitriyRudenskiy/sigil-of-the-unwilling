class_name BuilderRole
extends ScenarioRole
## autopilot-scenario-matrix: Городостроитель — развитие города.
## Политика: держаться рядом с городом (сбор — только узлы в радиусе 3),
## базовый цикл строит по BUILD_QUEUE, рекрутит и поднимает уровень.
## Цель: city_level >= 2 и buildings >= 4.

const NEAR_RADIUS := 3

func collect_target(pilot: Node):
	var center: Vector2i = pilot._city_center()
	if center == Vector2i(-1000, -1000):
		return Vector2i(-1, -1)
	var sp: Node = pilot._spawner
	if sp == null:
		return Vector2i(-1, -1)
	var here: Vector2i = pilot._hero_cell()
	var best := Vector2i(-1, -1)
	var best_d := INF
	for c in pilot._map().resource_cells.keys():
		if int(sp.get_res_type_at(c)) < 0:
			continue
		if HexUtils.hex_distance(c, center) > NEAR_RADIUS:
			continue
		var d := HexUtils.hex_distance(c, here)
		if d > 0 and d < best_d:
			best_d = d
			best = c
	return best if best != Vector2i(-1, -1) else null

func act(pilot: Node) -> bool:
	# Далеко от города — вернуться (строка/рекрутка/уровень только рядом).
	var center: Vector2i = pilot._city_center()
	if center == Vector2i(-1000, -1000):
		return false
	if pilot._hero_cell().distance_to(center) > float(NEAR_RADIUS + 1):
		if pilot._walk_to(center):
			return true
		var probe: Vector2i = pilot._explore_target(center)
		if probe != Vector2i(-1, -1) and pilot._walk_to(probe):
			return true
	return false

func goal_met(pilot: Node) -> bool:
	var city = pilot._player_city
	if city == null:
		return false
	return int(city.level) >= int(target.get("city_level_goal", 2)) \
		and int(city.buildings.size()) >= int(target.get("buildings_goal", 4))

func metrics(pilot: Node) -> Dictionary:
	var city = pilot._player_city
	return {
		"population": int(city.pop_total()) if city != null else 0,
		"population_goal": int(target.get("population_goal", 30)),
		"city_level": int(city.level) if city != null else 0,
		"city_level_goal": int(target.get("city_level_goal", 2)),
		"buildings": int(city.buildings.size()) if city != null else 0,
		"buildings_goal": int(target.get("buildings_goal", 4)),
		"turns": pilot.turn,
		"survived": survived(pilot),
	}

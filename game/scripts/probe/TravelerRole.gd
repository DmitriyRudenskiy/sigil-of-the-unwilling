class_name TravelerRole
extends ScenarioRole
## autopilot-scenario-matrix: Путешественник — A→B через биомы.
## Политика: разово выбирает дальнюю цель (distance_goal от старта),
## ходит к ней, доживая ходами; следит за потребностями (город — реквери);
## считает пройденные биомы (типы террейна).

var _target: Vector2i = Vector2i(-1, -1)
var _start: Vector2i = Vector2i(-1, -1)
var _biomes: Array = []

func _pick_target(pilot: Node) -> void:
	_start = pilot._hero_cell()
	var map = pilot._map()
	var goal_d: int = int(target.get("distance_goal", 25))
	var best := Vector2i(-1, -1)
	var best_d := 0
	# Дальнейшая проходимая клетка в кольце [goal, goal+15] — маршрут
	# гарантированно длинный, но достижимый за max_turns.
	for c in map.terrain_grid:
		if not map.is_walkable(c):
			continue
		var d := HexUtils.hex_distance(c, _start)
		if d >= goal_d and d < goal_d + 15 and d > best_d:
			best_d = d
			best = c
	if best == Vector2i(-1, -1):
		# Кольцо пустое (малая карта) — просто самая дальняя проходимая.
		for c in map.terrain_grid:
			if not map.is_walkable(c):
				continue
			var d := HexUtils.hex_distance(c, _start)
			if d > best_d:
				best_d = d
				best = c
	_target = best

func act(pilot: Node) -> bool:
	if _target == Vector2i(-1, -1):
		_pick_target(pilot)
		if _target == Vector2i(-1, -1):
			pilot._fail("traveler: нет проходимой цели")
			return true
	# Биом текущей клетки (счётчик пройденных биомов)
	var tid: int = pilot._map().get_terrain_id(pilot._hero_cell())
	if tid >= 0 and not _biomes.has(tid):
		_biomes.append(tid)
	# Потребности: в городе — ждать реквери, вне — идти в город.
	if pilot._needs_low():
		if pilot._hero_cell() == pilot._city_center():
			pilot._end_turn()
			return true
		if pilot._walk_to(pilot._city_center()):
			return true
	# Маршрут к B (доживая ходами); цель в тумане — к границе тумана в её сторону.
	if pilot._walk_to(_target):
		return true
	var probe: Vector2i = pilot._explore_target(_target)
	if probe != Vector2i(-1, -1) and pilot._walk_to(probe):
		return true
	pilot._end_turn()
	return true

func goal_met(pilot: Node) -> bool:
	return _target != Vector2i(-1, -1) and pilot._hero_cell() == _target

func metrics(pilot: Node) -> Dictionary:
	var arrived: bool = goal_met(pilot)
	var dist := 0
	if _start != Vector2i(-1, -1):
		dist = HexUtils.hex_distance(pilot._hero_cell(), _start)
	return {
		"arrived": arrived,
		"distance": dist,
		"distance_goal": int(target.get("distance_goal", 25)),
		"biomes": int(_biomes.size()),
		"biome_goal": int(target.get("biome_goal", 3)),
		"turns": pilot.turn,
		"hp": int(pilot._hero.combat_hp) if pilot._hero != null else 0,
		"survived": survived(pilot),
	}

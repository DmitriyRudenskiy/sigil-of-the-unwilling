extends RefCounted

const NeedType = preload("res://scripts/data/NeedType.gd")

var _city_serializer = null
var _root: Node = null

func setup(root: Node, city_serializer) -> void:
	_root = root
	_city_serializer = city_serializer

func get_state(world_ctrl, battle_ctrl) -> Dictionary:
	var state = {"mode": "unknown"}

	var in_battle := battle_ctrl != null
	state.mode = "battle" if in_battle else "world"

	if world_ctrl:
		var hero = world_ctrl.get_hero()
		var map_gen = world_ctrl.get_map_gen()

		if hero:
			state.hero_pos = SerializationUtils.vec2i_to_dict(hero.current_cell)
			state.move_points = hero.move_points
			state.max_move_points = hero.get_daily_movement_points()
			state.basic_resources = hero.resources.to_string_dict()
			state.strategic_resources = hero.strategic_resources.get_all()
			state.moving = hero.movement != null and hero.movement.is_moving
			var followers_out: Array = []
			for f in hero.followers:
				if f != null and f.has_method("to_dict"):
					followers_out.append(f.to_dict())
				else:
					followers_out.append({"name": str(f)})
			state.followers = followers_out
			var needs_out := {}
			for _nkey in hero.needs.needs:
				needs_out[NeedType.to_name(int(_nkey))] = float(hero.needs.needs[_nkey])
			state.needs = needs_out

		if map_gen:
			var res_nodes = []
			for cell in map_gen.resource_cells:
				res_nodes.append({"x": cell.x, "y": cell.y, "type": map_gen.resource_cells[cell]})
			state.map_resources = res_nodes

			var enemies = []
			if map_gen.enemy_stacks:
				for cell in map_gen.enemy_stacks:
					var army: Array = map_gen.enemy_stacks[cell]
					var composition = ""
					if army.size() > 0:
						var parts = []
						for stack in army:
							if stack.has_method("get_key"):
								parts.append("%s x%d" % [stack.get_key(), stack.count])
						composition = ", ".join(parts)
					else:
						composition = "Empty"

					enemies.append({
						"x": cell.x,
						"y": cell.y,
						"composition": composition
					})
			state.map_enemies = enemies

			var fog = world_ctrl.get_fog() if world_ctrl.has_method("get_fog") else null
			if fog != null:
				state.fog = {"explored": fog.explored.size(), "visible": fog.visible.size()}
				var visible_enemies: Array = []
				for cell in map_gen.enemy_stacks:
					if fog.is_visible(cell):
						visible_enemies.append(SerializationUtils.vec2i_to_dict(cell))
				state.visible_enemies = visible_enemies

		var cities_mgr = world_ctrl.get_cities()
		if cities_mgr != null:
			var city_list: Array = []
			for city in cities_mgr.cities:
				city_list.append(_city_serializer.city_state_dict(city))
			state.cities = city_list
			state.capital = _city_serializer.city_state_dict(cities_mgr.capital)
		var ui_mgr = world_ctrl.get_ui_manager()
		state.city_screen_open = ui_mgr.city_overlay_open() if ui_mgr != null else false

		if world_ctrl.has_method("get_endgame_state"):
			state.endgame = world_ctrl.get_endgame_state()

		var _villages: Array = []
		for _c in map_gen.village_cells:
			_villages.append(SerializationUtils.vec2i_to_dict(_c))
		state.map_villages = _villages

	if battle_ctrl:
		var bstate = battle_ctrl.get_battle_state()
		if bstate:
			state.battle_over = bstate.battle_over
			state.is_player_turn = bstate.is_player_turn

	return state

func move_to(world_ctrl, x: int, y: int) -> Dictionary:
	var hero = world_ctrl.get_hero()
	if hero == null:
		return {"error": "Hero not initialized"}
	var map = world_ctrl.get_map_gen()
	if map == null:
		return {"error": "Map not initialized"}
	var target := Vector2i(x, y)
	if not map.is_in_bounds(target):
		return {"error": "Out of bounds: (%d, %d)" % [x, y]}
	if hero.current_cell == target:
		return {"status": "already_at", "target": {"x": x, "y": y}}
	var will_reach: bool = hero.can_reach(target)
	var success: bool = hero.move_to_cell(target)
	if success:
		return {"status": "moving", "will_reach": will_reach, "target": {"x": x, "y": y}}
	var problem: String = hero.reach_problem(target)
	var reason := "unreachable" if problem == "unreachable" else "not enough movement points"
	return {"error": "Cannot move to (%d, %d): %s" % [x, y, reason]}

func end_turn(world_ctrl) -> Dictionary:
	world_ctrl.do_end_turn()
	return {"status": "turn_ended"}

func start_game() -> Dictionary:
	if _root.get_node_or_null("/root/World"):
		return {"status": "already_started"}
	var world_scene = load("res://scenes/World.tscn")
	var world = world_scene.instantiate()
	_root.get_tree().root.add_child(world)
	return {"status": "game_started"}

func save_game(world_ctrl) -> Dictionary:
	if not bool(world_ctrl.save_game()):
		return {"status": "save_failed"}
	var snap: Dictionary = world_ctrl.get_last_save_dict()
	return {
		"status": "saved",
		"version": snap.get("version", 0),
		"active_shard_id": snap.get("active_shard_id", ""),
		"shards": snap.get("shards", {}),
		"run_seed": snap.get("run_seed", 0),
	}

func load_game(world_ctrl) -> Dictionary:
	var data = world_ctrl.load_game()
	if data == null or not data.is_valid():
		return {"status": "load_failed"}
	world_ctrl.apply_save(data)
	return {"status": "loaded"}

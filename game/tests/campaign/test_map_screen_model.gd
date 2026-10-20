extends BaseTest

## Экран карты (view model поверх RegionMap) — headless-логика, mvp-ui-flow.
## Инвариант 3.3: каждое действие/опция возвращает {available, reason}.
## Топология MVP: R01→R02→R03→R04→R05 (линейная цепь), старт R01.
## Узлы: R02=camp, R03=ruin, R04=ore, R05=[camp,ruin].

const M = preload("res://scripts/ui/map_screen_model.gd")


func _make(food: float = 600.0) -> RegionMap:
	var m := RegionMap.new()
	m.init_campaign(2, food)
	return m


func _action(m: RegionMap, id: String) -> Dictionary:
	return M.action_by_id(m, id)


func test_visible_and_fog() -> void:
	var m := _make()
	var vis: Array = M.visible_regions(m)
	assert_bool(vis.has("R01") and vis.has("R02")).is_true()
	var fog: Array = M.fog_regions(m)
	assert_bool(fog.has("R03") and fog.has("R04") and fog.has("R05")).is_true()
	assert_bool(not fog.has("R01") and not fog.has("R02")).is_true()


func test_hero() -> void:
	var m := _make()
	var h: Dictionary = M.hero(m)
	assert_str(h["region"]).is_equal("R01")
	assert_str(h["state"]).is_equal(RegionMap.STATE_EXPLORE)


func test_region_card_start() -> void:
	var m := _make()
	var c: Dictionary = M.region_card(m, "R01")
	assert_str(c["biome"]).is_equal("plains")
	assert_str(c["node_type"]).is_equal("")
	assert_bool(c["visible"]).is_true()
	assert_bool(c["is_hero"]).is_true()
	assert_bool(c["is_start"]).is_true()
	assert_bool(c["looted"]).is_false()


func test_region_card_node() -> void:
	var m := _make()
	var c: Dictionary = M.region_card(m, "R02")
	assert_str(c["node_type"]).is_equal("camp")
	assert_bool(c["visible"]).is_true()
	assert_bool(c["is_hero"]).is_false()
	assert_bool(c["is_start"]).is_false()


func test_region_card_fog_hidden() -> void:
	var m := _make()
	var c: Dictionary = M.region_card(m, "R03")
	assert_bool(c["visible"]).is_false()


func test_travel_options_available() -> void:
	var m := _make(600.0)
	var opts: Array = M.travel_options(m)
	assert_int(opts.size()).is_equal(1)  # R01 → только R02
	var o: Dictionary = opts[0]
	assert_str(o["region"]).is_equal("R02")
	assert_bool(o["available"]).is_true()
	assert_int(o["days"]).is_equal(1)  # plains
	assert_bool(absf(float(o["food_cost"]) - 2.0) < 1e-6).is_true()  # 2 × 1 дн.
	assert_str(o["reason"]).is_equal("")


func test_travel_options_no_food() -> void:
	var m := _make(0.0)
	var o: Dictionary = M.travel_options(m)[0]
	assert_bool(o["available"]).is_false()
	assert_bool(str(o["reason"]).find("провизии") >= 0).is_true()


func test_travel_options_not_explore() -> void:
	var m := _make(600.0)
	m.hero_state = RegionMap.STATE_ENGAGE
	var o: Dictionary = M.travel_options(m)[0]
	assert_bool(o["available"]).is_false()
	assert_bool(str(o["reason"]).find("EXPLORE") >= 0).is_true()


func test_actions_move_with_food() -> void:
	var m := _make(600.0)
	assert_bool(_action(m, "move")["available"]).is_true()


func test_actions_move_no_food() -> void:
	var m := _make(0.0)
	var a: Dictionary = _action(m, "move")
	assert_bool(a["available"]).is_false()
	assert_str(a["reason"]).is_equal("нет доступных соседей")


func test_actions_visit_node_no_node() -> void:
	var m := _make()  # герой в R01 (без узла)
	var a: Dictionary = _action(m, "visit_node")
	assert_bool(a["available"]).is_false()
	assert_str(a["reason"]).is_equal("нет узла")


func test_actions_visit_node_available() -> void:
	var m := _make(600.0)
	m.travel("R02")  # R02 = camp
	var a: Dictionary = _action(m, "visit_node")
	assert_bool(a["available"]).is_true()


func test_actions_visit_node_looted() -> void:
	var m := _make(600.0)
	m.travel("R02")
	m.visit_node("R02")  # выграбить camp
	var a: Dictionary = _action(m, "visit_node")
	assert_bool(a["available"]).is_false()
	assert_str(a["reason"]).is_equal("уже выграблен")


func test_actions_retreat() -> void:
	var m := _make()
	assert_bool(_action(m, "retreat")["available"]).is_false()
	m.hero_state = RegionMap.STATE_ENGAGE
	assert_bool(_action(m, "retreat")["available"]).is_true()


func test_actions_field_raid() -> void:
	var m := _make()  # герой в R01 (город)
	var a: Dictionary = _action(m, "field_raid")
	assert_bool(a["available"]).is_false()
	assert_bool(str(a["reason"]).find("город") >= 0).is_true()
	m.travel("R02")  # полевой регион, EXPLORE
	assert_bool(_action(m, "field_raid")["available"]).is_true()


func test_action_by_id_unknown() -> void:
	var m := _make()
	var a: Dictionary = _action(m, "nope")
	assert_bool(a["available"]).is_false()

extends "res://tests/test_base.gd"
## Тесты строительной арены: CityArenaModel + ArenaBalance (синхронно).

const _Model = preload("res://city/CityArenaModel.gd")
const _Balance = preload("res://city/ArenaBalance.gd")
const _BuildingDefs = preload("res://data/BuildingDefs.gd")
const _PopUnit = preload("res://world/PopUnit.gd")


var city: City

func before_each() -> void:
	city = _Model.make_city()


## Первая свободная клетка кольца (или Vector2i(-1,-1)).
func _free_cell(ring: int) -> Vector2i:
	for c in _Model.cells_in_ring(ring):
		if not city.cell_is_built(c):
			return c
	return Vector2i(-1, -1)


# ==================== ГЕОМЕТРИЯ ====================

func test_arena_cells_unique() -> void:
	var cells: Array = _Model.cells_in_arena()
	var seen: Dictionary = {}
	for c in cells:
		seen[c] = true
	assert_eq(seen.size(), cells.size(), "клетки уникальны")
	assert_eq(cells.size(), 91, "91 клетка (радиус 5)")


func test_center_ring_zero() -> void:
	assert_eq(_Model.ring_of(_Model.ARENA_CENTER), 0, "центр — кольцо 0")
	assert_eq(city.center, _Model.ARENA_CENTER, "город в центре арены")
	assert_true(city.center.y % 2 == 0, "ряд центра чётный (odd-r parity)")


func test_all_cells_within_radius() -> void:
	var ok := true
	for c in _Model.cells_in_arena():
		if _Model.ring_of(c) > _Balance.ARENA_RADIUS:
			ok = false
	assert_true(ok, "все клетки в пределах радиуса")


func test_ring_colors_distinct() -> void:
	var seen: Array = []
	for r in range(0, _Balance.ARENA_RADIUS + 1):
		seen.append(_Model.ring_color(r))
	var ok := true
	for i in seen.size():
		for j in range(i + 1, seen.size()):
			if seen[i] == seen[j]:
				ok = false
	assert_true(ok, "цвета колец различаются")


# ==================== СТАРТОВЫЙ ГОРОД ====================

func test_start_city() -> void:
	assert_eq(city.pop_total(), 8, "8 жителей (4 рабочих + 4 последователя)")
	assert_eq(city.count_state(_PopUnit.State.WORKER), 4, "4 рабочих")
	assert_eq(city.count_state(_PopUnit.State.FOLLOWER), 4, "4 последователя")
	assert_true(city.food_stockpile >= 20.0, "стартовые запасы еды")


# ==================== ПОСТРОЙКА И РАБОЧИЕ ====================

func test_place_farm() -> void:
	var cell: Vector2i = _free_cell(1)
	assert_true(cell != Vector2i(-1, -1), "клетка кольца 1 найдена")
	var industry_before: float = float(city.storage.get(&"industry", 0.0))
	var res: Dictionary = _Model.place_building(city, _BuildingDefs.def_by_id(&"farm"), cell)
	assert_true(bool(res.get("ok", false)), "ферма построена: %s" % str(res.get("reason", "")))
	assert_true(city.cell_is_built(cell), "клетка занята")
	var industry_after: float = float(city.storage.get(&"industry", 0.0))
	assert_true(industry_after < industry_before, "промышленность списана")
	var b: UniqueBuilding = city.get_building_at(cell)
	# На момент постройки без кластеров/фич: множитель = 1 + бонус кольца.
	assert_true(b.zone_multiplier >= 1.0, "зональный множитель >= 1")
	assert_true(is_equal_approx(b.zone_multiplier,
			1.0 + _Balance.ring_bonus(&"farm", 1)),
		"множитель = 1 + ring_bonus(farm, кольцо)")


func test_place_outside_arena() -> void:
	var res: Dictionary = _Model.place_building(city, _BuildingDefs.def_by_id(&"farm"), Vector2i(60, 60))
	assert_false(bool(res.get("ok", true)), "вне арены не строится")


func test_seating_unique_tiles() -> void:
	var seated: int = _Model.seat_workers(city)
	assert_true(seated >= 3, "посажено большинство рабочих: %d" % seated)
	var tiles: Dictionary = {}
	var ok := true
	for u in city.pop:
		if u.state == _PopUnit.State.WORKER and u.tile.x >= 0:
			if tiles.has(u.tile):
				ok = false
			tiles[u.tile] = true
	assert_true(ok, "плитки уникальны")


func test_seating_avoids_buildings() -> void:
	var farm: Vector2i = _free_cell(1)
	_Model.place_building(city, _BuildingDefs.def_by_id(&"farm"), farm)
	for u in city.pop:
		if u.state == _PopUnit.State.WORKER and u.tile == farm:
			u.tile = Vector2i(-1, -1)
	_Model.seat_workers(city)
	var ok := true
	for u in city.pop:
		if u.state == _PopUnit.State.WORKER and u.tile == farm:
			ok = false
	assert_true(ok, "рабочий не на фундаменте")


func test_hire_worker() -> void:
	var farm: Vector2i = _free_cell(1)
	_Model.place_building(city, _BuildingDefs.def_by_id(&"farm"), farm)
	var hired: int = _Model.hire_worker(city)
	assert_eq(hired, 1, "нанял рабочего (есть цепочка)")
	assert_eq(city.pop_total(), 9, "население выросло")


# ==================== БАЛАНС (ArenaBalance) ====================

func test_ring_yield_bounds() -> void:
	assert_true(_Balance.ring_yield(0).is_empty(), "центр — пусто")
	assert_true(_Balance.ring_yield(_Balance.ARENA_RADIUS + 1).is_empty(), "вне арены — пусто")
	var y: Dictionary = _Balance.ring_yield(1)
	assert_true(y.has(&"food") and y.has(&"industry"), "поля выхода")
	assert_true(float(y[&"food"]) > 0.0, "еда на кольце 1 > 0")


## Механика ring_bonus (значения тюнятся — проверяем свойства, не числа).
func test_ring_bonus() -> void:
	assert_eq(_Balance.ring_bonus(&"nonexistent", 1), 0.0, "неизвестное здание")
	for ring in range(1, _Balance.ARENA_RADIUS + 1):
		for bid in [&"farm", &"mill", &"bakery", &"mine", &"smithy", &"tavern",
				&"trade_post", &"school", &"market", &"shack", &"walls"]:
			var v: float = _Balance.ring_bonus(bid, ring)
			assert_true(v >= 0.0 and v <= 0.6,
				"%s кольцо %d бонус в [0; 0.6]" % [str(bid), ring])
	# Таблица не вырождена: хотя бы один бонус > 0.
	var any_positive := false
	for ring in range(1, _Balance.ARENA_RADIUS + 1):
		for bid in [&"farm", &"mill", &"bakery", &"mine", &"smithy", &"tavern",
				&"trade_post", &"school", &"market", &"shack", &"walls"]:
			if _Balance.ring_bonus(bid, ring) > 0.0:
				any_positive = true
	assert_true(any_positive, "хотя бы один кольцевой бонус > 0")


# ==================== ДЕТЕРМИНИРОВАННОСТЬ ====================

func test_demo_plan_deterministic() -> void:
	var a: Dictionary = _Model.run_demo_plan(12)
	var b: Dictionary = _Model.run_demo_plan(12)
	assert_eq(float(a["score"]), float(b["score"]), "score повторяется")
	assert_eq(int(a["starve_days"]), int(b["starve_days"]), "голод повторяется")


# ==================== КЛАСТЕРЫ ×4 ====================

## Связка из 4 клеток кольца 3 (hex-цепочка): (4,1)-(5,1)-(6,1)-(7,2).
const _CLUSTER_CELLS: Array = [
	Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1), Vector2i(7, 2),
]


func _place_farm(cell: Vector2i) -> void:
	var res: Dictionary = _Model.place_building(city, _BuildingDefs.def_by_id(&"farm"), cell)
	assert_true(bool(res.get("ok", false)), "ферма на %s: %s" % [
		str(cell), str(res.get("reason", ""))])


func test_cluster_forms_on_four_connected() -> void:
	for i in 3:
		_place_farm((_CLUSTER_CELLS[i] as Vector2i))
	assert_eq(_Model.clusters(city).size(), 0, "3 фермы — кластера нет")
	_place_farm((_CLUSTER_CELLS[3] as Vector2i))
	var cls: Array = _Model.clusters(city)
	assert_eq(cls.size(), 1, "4 связанные фермы — один кластер")
	assert_eq(((cls[0] as Dictionary)["cells"] as Array).size(), 4, "кластер из 4 клеток")


func test_disconnected_groups_not_cluster() -> void:
	# Две пары: (4,1)-(5,1) и (2,4)-(2,5); пары не соседствуют между собой.
	for c in [Vector2i(4, 1), Vector2i(5, 1), Vector2i(2, 4), Vector2i(2, 5)]:
		_place_farm(c as Vector2i)
	assert_eq(_Model.clusters(city).size(), 0, "две пары не образуют кластер")


func test_cluster_different_types_not_merged() -> void:
	# 4 здания, но два разных типа — не кластер.
	for c in [Vector2i(4, 1), Vector2i(5, 1)]:
		_place_farm(c as Vector2i)
	for c in [Vector2i(6, 1), Vector2i(7, 2)]:
		var res: Dictionary = _Model.place_building(city, _BuildingDefs.def_by_id(&"mill"), c as Vector2i)
		assert_true(bool(res.get("ok", false)), "мельница: %s" % str(res.get("reason", "")))
	assert_eq(_Model.clusters(city).size(), 0, "разные типы не сливаются")


func test_cluster_multiplier_applied() -> void:
	for c in _CLUSTER_CELLS:
		_place_farm(c as Vector2i)
	_Model.apply_ring_multipliers(city)
	for c in _CLUSTER_CELLS:
		var b: UniqueBuilding = city.get_building_at(c as Vector2i)
		assert_true(b != null and b.zone_multiplier >= 1.49, \
			"кластер ×1.5: %.2f" % (b.zone_multiplier if b != null else 0.0))


func test_cluster_housing_bonus() -> void:
	for c in _CLUSTER_CELLS:
		_place_farm(c as Vector2i)
	assert_eq(_Model.cluster_worker_housing(city),
		city.free_housing(_PopUnit.State.WORKER) + ArenaBalance.CLUSTER_HOUSING,
		"бонус рабочих +CLUSTER_HOUSING")
	var city2 := _Model.make_city()
	assert_eq(_Model.cluster_worker_housing(city2),
		city2.free_housing(_PopUnit.State.WORKER), "без кластеров бонуса нет")


# ==================== ОСОБЕННОСТИ КЛЕТОК ====================

func test_cell_features_deterministic() -> void:
	var city2 := _Model.make_city()
	var count := 0
	for c in _Model.cells_in_arena():
		var f1: StringName = _Model.cell_feature(city, c as Vector2i)
		var f2: StringName = _Model.cell_feature(city2, c as Vector2i)
		assert_eq(f1, f2, "детерминизм на %s" % str(c))
		if f1 != &"":
			count += 1
		assert_true(f1 == &"" or f1 == &"quarry" or f1 == &"spring"
				 or f1 == &"river" or f1 == &"ruins", "известный вид: %s" % str(f1))
	assert_true(count >= 5, "особенностей достаточно: %d" % count)


func test_cell_features_rings_only() -> void:
	for c in _Model.cells_in_ring(0):
		assert_eq(_Model.cell_feature(city, c as Vector2i), &"", "центр — без особенностей")
	for c in _Model.cells_in_ring(1):
		assert_eq(_Model.cell_feature(city, c as Vector2i), &"", "кольцо 1 — без особенностей")
	for c in _Model.cells_in_ring(5):
		assert_eq(_Model.cell_feature(city, c as Vector2i), &"", "кольцо 5 — без особенностей")


func test_feature_mults() -> void:
	# uid=1 детерминированно: карьер (2,4), родник (2,5), река (2,2), руины (2,3).
	var quarry := Vector2i(2, 4)
	var spring := Vector2i(2, 5)
	var river := Vector2i(2, 2)
	assert_eq(_Model.cell_feature(city, quarry), &"quarry")
	assert_eq(_Model.cell_feature(city, spring), &"spring")
	assert_eq(_Model.cell_feature(city, river), &"river")
	assert_eq(_Model.feature_mult(city, &"mine", quarry),
		ArenaBalance.FEATURE_QUARRY_MULT, "карьер усиливает рудник")
	assert_eq(_Model.feature_mult(city, &"farm", quarry), 1.0, "карьер не влияет на ферму")
	assert_eq(_Model.feature_mult(city, &"farm", spring),
		ArenaBalance.FEATURE_SPRING_MULT, "родник усиливает ферму")
	assert_eq(_Model.feature_mult(city, &"mine", spring), 1.0, "родник не влияет на рудник")
	assert_eq(_Model.feature_mult(city, &"tavern", river),
		ArenaBalance.FEATURE_RIVER_MULT, "река усиливает любое здание")


func test_ruins_gold_bonus() -> void:
	var cell := Vector2i(2, 3)
	assert_eq(_Model.cell_feature(city, cell), &"ruins")
	var gold_before: float = float(city.storage.get(&"gold", 0.0))
	var res: Dictionary = _Model.place_building(city, _BuildingDefs.def_by_id(&"shack"), cell)
	assert_true(bool(res.get("ok", false)), "хижина: %s" % str(res.get("reason", "")))
	assert_eq(float(res.get("ruins_gold", 0.0)), ArenaBalance.FEATURE_RUINS_GOLD, "бонус руин")
	var gold_after: float = float(city.storage.get(&"gold", 0.0))
	assert_eq(gold_after, gold_before + ArenaBalance.FEATURE_RUINS_GOLD, "золото начислено")


# ==================== ШТОРМ ====================

func test_storm_periodicity() -> void:
	assert_true(_Model.is_storm_turn(6), "ход 6 — шторм")
	assert_true(_Model.is_storm_turn(12), "ход 12 — шторм")
	assert_false(_Model.is_storm_turn(5), "ход 5 — без шторма")
	assert_false(_Model.is_storm_turn(1), "ход 1 — без шторма")
	assert_false(_Model.is_storm_turn(0), "ход 0 — без шторма")


func test_storm_food_and_production() -> void:
	# Ферма на кольце 3 БЕЗ особенности: базовый множитель 1.0.
	var cell := Vector2i(-1, -1)
	for c in _Model.cells_in_ring(3):
		var cc: Vector2i = c
		if _Model.cell_feature(city, cc) == &"":
			cell = cc
			break
	assert_true(cell != Vector2i(-1, -1), "найдена обычная клетка кольца 3")
	_place_farm(cell)
	var rep: Dictionary = _Model.run_turn(city, 6)
	assert_true(bool(rep.get("storm", false)), "отчёт: шторм на ходу 6")
	assert_eq(float(rep.get("storm_food", 0.0)), ArenaBalance.STORM_FOOD, "потери еды")
	var b: UniqueBuilding = city.get_building_at(cell)
	assert_true(b != null and absf(b.zone_multiplier - ArenaBalance.STORM_PRODUCTION_MULT) < 0.001,
		"производство ×%.2f в шторме" % (b.zone_multiplier if b != null else 0.0))


func test_storm_mitigated_by_walls() -> void:
	var cell: Vector2i = _free_cell(1)
	var res: Dictionary = _Model.place_building(city, _BuildingDefs.def_by_id(&"walls"), cell)
	assert_true(bool(res.get("ok", false)), "стены: %s" % str(res.get("reason", "")))
	var b: UniqueBuilding = city.get_building_at(cell)
	assert_true(b != null, "стены построены")
	b.level = 2  # апгрейд до 2-го уровня (условие смягчения шторма)
	assert_eq(_Model.storm_production_mult(city, 6),
		ArenaBalance.STORM_MITIGATED_PRODUCTION_MULT, "смягчённый множитель")
	assert_eq(_Model.storm_food_penalty(city, 6), ArenaBalance.STORM_MITIGATED_FOOD, "смягчённые потери")


func test_storm_absent_turn() -> void:
	var rep: Dictionary = _Model.run_turn(city, 5)
	assert_false(bool(rep.get("storm", false)), "ход 5 без шторма")
	assert_eq(float(rep.get("storm_food", 0.0)), 0.0, "без потерь еды")


# ==================== ДЕМО-ПЛАН С КЛАСТЕРОМ ====================

func test_demo_plan_forms_farm_cluster() -> void:
	var r: Dictionary = _Model.run_demo_plan(48)
	var cls: Array = _Model.clusters(r["city"])
	assert_true(cls.size() >= 1, "в демо-плане собирается 4-ферменный кластер")
	var last: Dictionary = r["last"]
	assert_true(last.has("storm") and last.has("clusters"), "отчёт хода содержит шторм/кластеры")


# ==================== ЦЕЛОСТНОСТЬ АВТО-БАЛАНСА ====================
## ArenaBalance.gd переписывается тюнером; ловим битую авто-генерацию.

func test_balance_yield_table_shape() -> void:
	assert_eq(_Balance.RING_YIELD.size(), 6, "6 строк (центр + 5 колец)")
	for r in range(6):
		var row: Array = _Balance.RING_YIELD[r]
		assert_eq(row.size(), 5, "кольцо %d: 5 ресурсов" % r)
		for i in range(5):
			assert_true(float(row[i]) >= 0.0, "кольцо %d res %d неотрицательно" % [r, i])


func test_balance_yield_within_bounds() -> void:
	# Границы совпадают с YIELD_BOUNDS тюнера.
	var bounds: Array = [[0.0, 8.0], [0.0, 6.0], [0.0, 2.0], [0.0, 2.0], [0.0, 2.0]]
	for r in range(1, 6):
		var row: Array = _Balance.RING_YIELD[r]
		for i in range(5):
			assert_true(float(row[i]) <= float(bounds[i][1]),
				"кольцо %d res %d <= %s" % [r, i, str(bounds[i][1])])


func test_balance_bonus_within_bounds() -> void:
	var buildings: Array[StringName] = [
		&"farm", &"mill", &"bakery", &"mine", &"smithy", &"tavern",
		&"trade_post", &"school", &"market", &"shack", &"walls",
	]
	for bid in buildings:
		assert_true(_Balance.RING_BONUS.has(bid), "бонусы здания %s есть" % str(bid))
		var row: Dictionary = _Balance.RING_BONUS[bid]
		for ring in range(1, 6):
			var v: float = float(row.get(ring, 0.0))
			assert_true(v >= 0.0 and v <= 0.6,
				"%s кольцо %d в [0; 0.6]" % [str(bid), ring])


func test_balance_mechanics_constants_present() -> void:
	assert_eq(_Balance.CLUSTER_MIN, 4, "кластер из 4")
	assert_gt(_Balance.CLUSTER_MULT, 1.0, "кластерный множитель > 1")
	assert_gt(_Balance.CLUSTER_HOUSING, 0, "кластер даёт слоты рабочих")
	assert_gt(_Balance.STORM_PERIOD, 0, "период шторма > 0")
	assert_true(_Balance.STORM_PRODUCTION_MULT < 1.0, "шторм бьёт по производству")
	assert_true(_Balance.STORM_MITIGATED_PRODUCTION_MULT > _Balance.STORM_PRODUCTION_MULT,
			"стены смягчают шторм")
	assert_gt(_Balance.STORM_FOOD, 0.0, "шторм ест еду")
	assert_true(_Balance.STORM_MITIGATED_FOOD <= _Balance.STORM_FOOD,
			"стены смягчают потери еды")
	assert_gt(_Balance.FEATURE_QUARRY_MULT, 1.0, "карьер усиливает рудник")
	assert_gt(_Balance.FEATURE_SPRING_MULT, 1.0, "родник усиливает ферму")
	assert_gt(_Balance.FEATURE_RIVER_MULT, 1.0, "река усиливает любое здание")
	assert_gt(_Balance.FEATURE_RUINS_GOLD, 0.0, "руины дают золото")
	assert_true(_Balance.FEATURE_CHANCE > 0.0 and _Balance.FEATURE_CHANCE < 1.0,
			"вероятность фичи в (0; 1)")

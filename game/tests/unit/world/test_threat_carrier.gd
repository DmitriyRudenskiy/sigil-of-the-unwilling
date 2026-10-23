extends BaseTest

# world-map-art-variety 8.1–8.2: визуальный носитель тира вражеского стэка.
#
# Спека «Визуальный носитель тира» требует трёх вещей: смежные кольца различимы
# измеримо, носитель читается из тира (не случайно), и носитель не подменяет
# данные стэка. Тесты ниже — по сценарию на требование.

## Порог различия смежных колец в единицах RGB 0..255 (средний тон по принятым
## пикселям). Замер листа `world_map_threat.webp` на 2026-10-23: 30.7 (1→2) и
## 34.5 (2→3); порог вдвое ниже замера — это «заметно», а не «чуть заметно».
const MIN_RING_DELTA := 20.0


# ------------------------------------------------------------------ лист и манифест

func test_sheet_and_manifest() -> void:
	var tex: Texture2D = load(MapThreat.SHEET_PATH)
	assert_that(tex).is_not_null()
	assert_that((tex as Texture2D).get_image()).is_not_null()
	var manifest := MapThreat.manifest()
	assert_that(int(manifest.get("tile", -1))).is_equal(GameNumbers.TILE_SIZE)
	assert_that(MapThreat.ids().size()).is_equal(MapThreat.RINGS.size())
	# Соответствие «кольцо → клетка» задаёт код, манифест обязан с ним согласиться:
	# иначе перестановка ролей в map_spec.json переопределила бы тиры молча.
	for ring in MapThreat.RINGS:
		var r: int = int(ring)
		var cell_id := MapThreat.cell_id_for(r)
		assert_that(cell_id).is_not_empty()
		assert_bool(MapThreat.ids().has(cell_id)).is_true()
		assert_that(MapThreat.manifest_ring(cell_id)).is_equal(r)
		assert_that(MapThreat.coords_for(cell_id) != Vector2i(-1, -1)).is_true()


## Номера колец, которых нет в таблице, не имеют права молча превращаться в
## «какой-нить носитель».
func test_unknown_ring_has_no_cell() -> void:
	assert_that(MapThreat.cell_id_for(0)).is_empty()
	assert_that(MapThreat.cell_id_for(4)).is_empty()


func test_carrier_per_ring() -> void:
	var seen: Array[Vector2i] = []
	for ring in MapThreat.RINGS:
		var r: int = int(ring)
		var tex: Texture2D = MapThreat.carrier_texture(r)
		assert_that(tex).is_not_null()
		assert_bool(tex is AtlasTexture).is_true()
		var region: Rect2 = (tex as AtlasTexture).region
		assert_that(region.size).is_equal(
				Vector2(GameNumbers.TILE_SIZE, GameNumbers.TILE_SIZE))
		# Разные кольца — разные клетки листа: «различаются» не по слову в коде.
		assert_bool(seen.has(Vector2i(int(region.position.x), int(region.position.y)))) \
				.is_false()
		seen.append(Vector2i(int(region.position.x), int(region.position.y)))


# ------------------------------------------------------------------- различие числом

func test_adjacent_rings_are_distinguishable() -> void:
	var img: Image = (load(MapThreat.SHEET_PATH) as Texture2D).get_image()
	assert_that(img).is_not_null()
	for pair in [[1, 2], [2, 3]]:
		var a: int = int((pair as Array)[0])
		var b: int = int((pair as Array)[1])
		var ca := _mean_color(img, MapThreat.coords_for(MapThreat.cell_id_for(a)))
		var cb := _mean_color(img, MapThreat.coords_for(MapThreat.cell_id_for(b)))
		assert_float(ca.distance_to(cb)).is_greater(MIN_RING_DELTA)


## Различие держится не только тоном: силуэты колец обязаны различаться площадью
## принятого рисунка, иначе на зуме карты кольца сошлись бы в одно пятно, а средний
## тон расходился бы только на палитре.
func test_ring_silhouettes_differ() -> void:
	var img: Image = (load(MapThreat.SHEET_PATH) as Texture2D).get_image()
	var fills: Array[float] = []
	for ring in MapThreat.RINGS:
		fills.append(_fill(img, MapThreat.coords_for(MapThreat.cell_id_for(int(ring)))))
	assert_float(fills.max() / fills.min()).is_greater(1.5)


# ---------------------------------------------------------------- тир из модели мира

## Записанный тир важнее состава: создатель стэка знает, из какого кольца его
## набрал пул, и носитель обязан смотреть на это решение.
func test_written_tier_wins() -> void:
	var model := _model()
	var cell := Vector2i(30, 30)
	model.enemy_tiers[cell] = MapThreat.RING_RAIDERS
	var army: Array = [_stack("red_dragon")]
	model.enemy_stacks[cell] = army
	assert_that(MapSpawner.resolve_threat_ring(model, cell, army)) \
			.is_equal(MapThreat.RING_RAIDERS)


## Без записанного тира кольцо берётся из состава; «максимум по юнитам» — чтобы
## стэк с троллем не притворялся кольцом диких животных.
func test_composition_tier_when_not_written() -> void:
	var model := _model()
	var cell := Vector2i(30, 30)
	assert_that(MapSpawner.resolve_threat_ring(model, cell, [_stack("wolves")])) \
			.is_equal(MapThreat.RING_WILD)
	var mixed: Array = [_stack("wolves"), _stack("trolls")]
	assert_that(MapSpawner.resolve_threat_ring(model, cell, mixed)) \
			.is_equal(MapThreat.RING_MONSTERS)


## Сценарий «носитель следует за тиром»: один и тот же стэк, разные тира — разные
## пиксели носителя. Смена тира на месте (пересборка, сезон) обязана менять картинку
## без пересоздания узла с нуля.
func test_carrier_follows_tier() -> void:
	var model := _model()
	var cell := Vector2i(30, 30)
	var army: Array = [_stack("goblins")]
	model.enemy_stacks[cell] = army
	model.enemy_tiers[cell] = MapThreat.RING_WILD
	var near: Texture2D = MapThreat.carrier_texture(
			MapSpawner.resolve_threat_ring(model, cell, army))
	model.enemy_tiers[cell] = MapThreat.RING_MONSTERS
	var far: Texture2D = MapThreat.carrier_texture(
			MapSpawner.resolve_threat_ring(model, cell, army))
	assert_that(near).is_not_null()
	assert_that(far).is_not_null()
	assert_that((near as AtlasTexture).region) \
			.is_not_equal((far as AtlasTexture).region)


## Случайности в выборе носителя нет: тот же мир (тот же seed) даёт те же тиры,
## а значит и те же носители.
func test_placement_tiers_are_deterministic() -> void:
	var a := MapModel.new()
	var b := MapModel.new()
	_place(a)
	_place(b)
	assert_that(b.enemy_tiers).is_equal(a.enemy_tiers)
	assert_that(a.enemy_tiers.is_empty()).is_false()


# ------------------------------------------------- расстановка пишет тир рядом со стэком

## Каждый стэк, поставленный place_enemies, имеет тир; он легален; он совпадает с
## дистанционным правилом и с тем, чем стэк реально набран. Три совпадения в одном
## тесте — это и есть «номера колец не расходятся с пулом»: до 8.2 их держало только
## молчаливое согласие двух разных выражений одного правила.
func test_placement_records_tier() -> void:
	var model := MapModel.new()
	_place(model)
	var origin: Vector2i = model.find_spawn_cell()
	assert_that(origin.x >= 0).is_true()
	assert_that(model.enemy_stacks.size() > 0).is_true()
	for cell in model.enemy_stacks:
		var c: Vector2i = cell
		var army: Array = model.enemy_stacks[cell]
		assert_bool(MapThreat.RINGS.has(int(model.enemy_tiers.get(c, 0)))).is_true()
		var tier: int = int(model.enemy_tiers[c])
		assert_that(tier).is_equal(MapSpawner.threat_ring(HexUtils.hex_distance(c, origin)))
		assert_that(MapSpawner.threat_ring_of_army(army)).is_equal(tier)


## То же, что и в спеке: кольцо 1 ближе всех к истоку, кольцо 3 дальше кольца 2.
## Радиусы — данные спавнера; тест сторожит границу, а не копирует её.
func test_ring_bounds_follow_distance() -> void:
	assert_that(MapSpawner.threat_ring(0)).is_equal(MapThreat.RING_WILD)
	assert_that(MapSpawner.threat_ring(MapSpawner.THREAT_RING2_RADIUS - 1)) \
			.is_equal(MapThreat.RING_WILD)
	assert_that(MapSpawner.threat_ring(MapSpawner.THREAT_RING2_RADIUS)) \
			.is_equal(MapThreat.RING_RAIDERS)
	assert_that(MapSpawner.threat_ring(MapSpawner.THREAT_RING3_RADIUS - 1)) \
			.is_equal(MapThreat.RING_RAIDERS)
	assert_that(MapSpawner.threat_ring(MapSpawner.THREAT_RING3_RADIUS)) \
			.is_equal(MapThreat.RING_MONSTERS)


## Юниты faction sets, которых нет в пулах колец, не имеют своего тира — и не
## получают его «по умолчанию ноль»: 0 отличается от 1 именно затем, чтобы зовущий
## выбрал кольцо по другому правилу, а не нарисовал кольцо 1 у чего попало.
func test_unknown_unit_has_no_ring() -> void:
	assert_that(MapSpawner.threat_ring_of_unit("pikeman")).is_equal(0)
	assert_that(MapSpawner.threat_ring_of_army([_stack("pikeman")])).is_equal(0)


## Пулы колец обязаны оставаться разбиением: ключ из двух колец сделал бы «тир по
## составу» двусмысленным, а тест ниже ловит это до того, как носитель начнёт
## врать о кольце.
func test_ring_pools_are_disjoint() -> void:
	var pools: Array = [MapSpawner.THREAT_RING1, MapSpawner.THREAT_RING2, MapSpawner.THREAT_RING3]
	for i in pools.size():
		for j in range(i + 1, pools.size()):
			for key in (pools[i] as Array):
				assert_bool((pools[j] as Array).has(key)).is_false()


# ------------------------------------------------------------------ узел на карте

## Носитель — потомок стэка: туман войны прячет вражеский стэк целиком (вердикт
## В2 → (в), D-205), и подложка обязана прятаться вместе с ним, иначе затемнённое
## кольцо отдало бы разведку врагом.
func test_carrier_is_child_of_stack() -> void:
	var world := _world()
	var nodes := _enemy_nodes(world["spawner"] as WorldSpawner)
	assert_bool(nodes.size() > 0).is_true()
	for node in nodes:
		var back := node.get_node_or_null("Backing")
		assert_that(back).is_not_null()
		assert_bool(back is Sprite2D).is_true()
		assert_int((back as Sprite2D).z_index) \
				.is_less((node.get_node("Sprite") as Sprite2D).z_index)


## Номера колец на узлах совпадают с моделью для всех стэков разом — это и есть
## «носитель читается из тира» на собранной карте, а не на одном подставном стэке.
func test_spawned_carriers_match_model_tiers() -> void:
	var world := _world()
	var gen: MapGenerator = world["gen"]
	var nodes := _enemy_nodes(world["spawner"] as WorldSpawner)
	assert_bool(nodes.size() > 0).is_true()
	for node in nodes:
		var cell: Vector2i = node.get_meta("enemy_cell")
		var back: Sprite2D = node.get_node("Backing")
		assert_that(back.texture).is_not_null()
		var tier: int = int(gen.enemy_tiers.get(cell, 0))
		assert_bool(MapThreat.RINGS.has(tier)).is_true()
		assert_that((back.texture as AtlasTexture).region) \
				.is_equal((MapThreat.carrier_texture(tier) as AtlasTexture).region)


## Три кольца на одной карте — три разных носителя. Стэки расставляются самим
## тестом: реальная карта с одним истоком угрозы обязана иметь все три кольца, но
## проверять «различимость на карте» случайным составом карты — значит ловить падение
## только на удачных затравках.
func test_three_rings_show_three_carriers() -> void:
	var world := _world()
	var gen: MapGenerator = world["gen"]
	var spawner: WorldSpawner = world["spawner"]
	var cells := _three_walkable_cells(gen)
	assert_that(cells.size()).is_equal(MapThreat.RINGS.size())
	for i in MapThreat.RINGS.size():
		var c: Vector2i = cells[i]
		gen.model.enemy_stacks[c] = [_stack("goblins")]
		gen.model.enemy_tiers[c] = int(MapThreat.RINGS[i])
	spawner.respawn_enemies()
	await get_tree().process_frame
	var regions: Array[Rect2] = []
	for node in _enemy_nodes(spawner):
		var cell: Vector2i = node.get_meta("enemy_cell")
		if not cells.has(cell):
			continue
		var back: Sprite2D = node.get_node("Backing")
		assert_that(back.texture).is_not_null()
		var region: Rect2 = (back.texture as AtlasTexture).region
		assert_bool(not regions.has(region)).is_true()
		regions.append(region)
		assert_that(region) \
				.is_equal((MapThreat.carrier_texture(int(gen.enemy_tiers[cell])) as AtlasTexture).region)
	assert_that(regions.size()).is_equal(MapThreat.RINGS.size())


## Сценарий «носитель не подменяет данные»: пиксели носителя — чтение, запись в
## модель из них не идёт. Проверка — состав стэка и тиры до и после съёмки носителя.
func test_carrier_does_not_replace_stack_data() -> void:
	var world := _world()
	var gen: MapGenerator = world["gen"]
	var before: Dictionary = gen.model.enemy_stacks.duplicate(true)
	var before_tiers: Dictionary = gen.model.enemy_tiers.duplicate(true)
	for cell in before:
		var c: Vector2i = cell
		var ring: int = MapSpawner.resolve_threat_ring(gen.model, c, before[c])
		assert_that(MapThreat.carrier_texture(ring)).is_not_null()
		MapThreat.carrier_offset(ring)
	assert_that(gen.model.enemy_stacks).is_equal(before)
	assert_that(gen.model.enemy_tiers).is_equal(before_tiers)


# ------------------------------------------------------------------------ хелперы

## Готовая к правилам колец модель: трава-мир без расставленных стэков — тесты
## разрешают тир руками и не зависят от того, что там поставил спавнер.
func _model() -> MapModel:
	var model := MapModel.new()
	model.map_width = 90
	model.map_height = 70
	model.seed_value = 4242
	for y in model.map_height:
		for x in model.map_width:
			model.terrain_grid[Vector2i(x, y)] = HexUtils.Terrain.GRASS
	return model


## Тот же мир и расстановка стэков тем же путём, что и игра.
func _place(model: MapModel, seed_value: int = 4242) -> void:
	model.map_width = 90
	model.map_height = 70
	model.seed_value = seed_value
	for y in model.map_height:
		for x in model.map_width:
			model.terrain_grid[Vector2i(x, y)] = HexUtils.Terrain.GRASS
	var spawner := MapSpawner.new(model)
	var reachable: Dictionary = {}
	for y in range(6, 60):
		for x in range(6, 60):
			reachable[Vector2i(x, y)] = true
	spawner.place_enemies(reachable)


func _stack(key: String) -> UnitStack:
	var reg: Node = Services.resolve(&"units")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	return reg.make_stack(key, rng, 1.0)


## Собранная карта: генератор + расставленные стэки + WorldSpawner с узлами.
func _world() -> Dictionary:
	var gen: MapGenerator = make_node(MapGenerator)
	gen._seed_value = 4242
	gen._map_width = 60
	gen._map_height = 46
	gen.generate()
	var placer := MapSpawner.new(gen.model)
	var reachable: Dictionary = {}
	for y in range(6, 40):
		for x in range(6, 40):
			reachable[Vector2i(x, y)] = true
	placer.place_enemies(reachable)
	var ws: WorldSpawner = make_node(WorldSpawner)
	ws.map = gen
	ws.spawn_all()
	return {"gen": gen, "spawner": ws}


## Три ходимые клетки подальше друг от друга — под три кольца.
func _three_walkable_cells(gen: MapGenerator) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var want := [Vector2i(8, 8), Vector2i(30, 8), Vector2i(50, 30)]
	for cell in want:
		if gen.is_walkable(cell) and not gen.model.enemy_stacks.has(cell) \
				and not gen.model.resource_cells.has(cell):
			out.append(cell)
	return out


func _enemy_nodes(spawner: WorldSpawner) -> Array[Node2D]:
	var out: Array[Node2D] = []
	for child in spawner.get_children():
		var n := child as Node2D
		if n != null and n.has_meta("enemy_cell"):
			out.append(n)
	return out


## Средний тон принятой части клетки листа (α > 0.2) в единицах 0..255.
func _mean_color(img: Image, coords: Vector2i) -> Vector3:
	var tile := GameNumbers.TILE_SIZE
	var sum := Vector3.ZERO
	var n := 0
	for y in tile:
		for x in tile:
			var p: Color = img.get_pixel(coords.x * tile + x, coords.y * tile + y)
			if p.a <= 0.2:
				continue
			sum += Vector3(p.r, p.g, p.b) * 255.0
			n += 1
	assert_that(n).is_greater(0)
	return sum / float(n)


## Доля принятых пикселей клетки — мера силуэта.
func _fill(img: Image, coords: Vector2i) -> float:
	var tile := GameNumbers.TILE_SIZE
	var hit := 0
	for y in tile:
		for x in tile:
			if img.get_pixel(coords.x * tile + x, coords.y * tile + y).a > 0.2:
				hit += 1
	return float(hit) / float(tile * tile)

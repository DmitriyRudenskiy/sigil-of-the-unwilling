extends BaseTest
## Ресурсы по биомам (world-map-art-variety, задача 9.4). Спека terrain:
## лес даёт древесину/дичь, предгорья — камень/руду, равнины —
## продовольствие/скот, болото — травы; равномерный бросок без учёта
## террейна запрещён; непроходимые клетки ресурса не несут; доля «своих»
## биомов измерена и печатается; старое сохранение не теряет узлов.
##
## Карта мира в игре: MOUNTAIN непроходима (MapModel.is_walkable) — это и
## есть «непроходимая вершина»; проходимые высоты (склон/предгорье) — SNOW,
## на них группа камня/руды. Таблица «биом → группа» — данные
## (game/data/config/biome_resources.json), тесты держат и её, и спавнер.


## Порог доли «своих» биомов (спека: «не ниже зафиксированного порога»).
## Для новой генерации раскладка по построению 1.0 — порог 1.0 запрещает
## любой fallback-спавн вне биома без явного решения.
const HOME_SHARE_THRESHOLD := 1.0

const MAP_W := 60
const MAP_H := 60
## Строки биомов: 6 ресурсных + непроходимые (MOUNTAIN — вершина, WATER).
const ROWS: Array = [
	HexUtils.Terrain.FOREST,
	HexUtils.Terrain.DENSE_FOREST,
	HexUtils.Terrain.SNOW,
	HexUtils.Terrain.GRASS,
	HexUtils.Terrain.SAND,
	HexUtils.Terrain.SWAMP,
	HexUtils.Terrain.MOUNTAIN,
	HexUtils.Terrain.WATER,
]


class _FakeModel:
	var terrain_grid: Dictionary = {}
	var village_cells: Array = []
	var resource_cells: Dictionary = {}
	var seed_value := 0
	var map_width := MAP_W
	var map_height := MAP_H


func _biome_field() -> _FakeModel:
	var m := _FakeModel.new()
	for y in m.map_height:
		for x in m.map_width:
			m.terrain_grid[Vector2i(x, y)] = ROWS[y % ROWS.size()]
	# Одна клетка реки в воде: проходима только по мосту, группы не имеет.
	m.terrain_grid[Vector2i(6, MAP_H - 1)] = HexUtils.Terrain.RIVER
	return m


func _all_cells(m) -> Dictionary:
	var out: Dictionary = {}
	for cell in m.terrain_grid:
		out[cell] = true
	return out


func _place(m, seed_value: int, generator_version: int) -> void:
	m.seed_value = seed_value
	MapSpawner.new(m).place_resources(_all_cells(m), -1, generator_version)


func _count_by_terrain(m) -> Dictionary:
	var out: Dictionary = {}
	for cell in m.resource_cells:
		var t: int = int(m.terrain_grid[cell])
		out[t] = int(out.get(t, 0)) + 1
	return out


## Лес даёт дерево: на FOREST/DENSE_FOREST только древесина, руды и камня
## нет (спека, сценарий «Лес даёт дерево»).
func test_forest_yields_wood_only() -> void:
	var m := _biome_field()
	_place(m, 2, SaveData.CURRENT_GENERATOR_VERSION)
	var by_terrain := _count_by_terrain(m)
	var forest_total := int(by_terrain.get(HexUtils.Terrain.FOREST, 0)) \
		+ int(by_terrain.get(HexUtils.Terrain.DENSE_FOREST, 0))
	# Не-вакуум: в лесу реально стоят ресурсы (иначе проверка пустая).
	assert_int(forest_total).is_greater(0)
	for cell in m.resource_cells:
		var t: int = int(m.terrain_grid[cell])
		if t == HexUtils.Terrain.FOREST or t == HexUtils.Terrain.DENSE_FOREST:
			assert_int(int(m.resource_cells[cell])).is_equal(ResourceType.ID.WOOD)


## Предгорья дают камень/руду: на проходимых высотах (SNOW — склон/предгорье;
## MOUNTAIN непроходима и ресурса не несёт — см. test_impassable_carry_no_resource)
## только группа камня/руды (спека, сценарий «Предгорье даёт камень»).
func test_walkable_highlands_yield_stone_ore() -> void:
	var m := _biome_field()
	_place(m, 3, SaveData.CURRENT_GENERATOR_VERSION)
	var stone_ore: Array[int] = MapSpawner.biome_ids_for_terrain(HexUtils.Terrain.SNOW)
	assert_bool(stone_ore.size() >= 2).is_true()
	var snow_total := 0
	for cell in m.resource_cells:
		if int(m.terrain_grid[cell]) == HexUtils.Terrain.SNOW:
			snow_total += 1
			assert_bool(stone_ore.has(int(m.resource_cells[cell]))).is_true()
	assert_int(snow_total).is_greater(0)


## Вершина непроходима — ресурса нет: на MOUNTAIN (и WATER/RIVER) ни одной
## ресурсной клетки (спека, сценарий «Вершина непроходима — ресурса нет»).
func test_impassable_carry_no_resource() -> void:
	var m := _biome_field()
	_place(m, 4, SaveData.CURRENT_GENERATOR_VERSION)
	assert_int(m.resource_cells.size()).is_greater(0)
	for cell in m.resource_cells:
		var t: int = int(m.terrain_grid[cell])
		assert_bool(t != HexUtils.Terrain.MOUNTAIN).is_true()
		assert_bool(t != HexUtils.Terrain.WATER).is_true()
		assert_bool(t != HexUtils.Terrain.RIVER).is_true()


## Доля «своих» биомов измерена и не ниже порога (спека, сценарий «Доля
## «своих» биомов измерена»): метрика считается по итоговой раскладке и
## печатается в отчёт генерации (print_resource_report).
func test_home_share_meets_threshold() -> void:
	var m := _biome_field()
	_place(m, 5, SaveData.CURRENT_GENERATOR_VERSION)
	var spawner := MapSpawner.new(m)
	var rep := spawner.resource_report()
	assert_int(int(rep["total"])).is_equal(m.resource_cells.size())
	assert_int(int(rep["total"])).is_greater(0)
	assert_float(float(rep["home_share"])).is_greater_equal(HOME_SHARE_THRESHOLD)
	# by_type покрывает всю раскладку: сумма по типам = всего.
	var sum := 0
	for id in rep["by_type"]:
		sum += int(rep["by_type"][id])
	assert_int(sum).is_equal(int(rep["total"]))


## Старое сохранение: наследственная генерация (generator_version = 1) —
## прежний равномерный бросок без изменений (дрейф от «своих» биомов на
## месте, раскладка детерминирована), новая — по таблице (спека, сценарий
## «Сохранение прежней генерации»; задача 9.3 — узлы не переигрываются).
func test_legacy_generation_keeps_old_rules() -> void:
	var m1 := _biome_field()
	_place(m1, 42, 1)
	var m2 := _biome_field()
	_place(m2, 42, 1)
	# Детерминизм: один сид — одна раскладка клетка-в-клетку.
	assert_str(str(m2.resource_cells)).is_equal(str(m1.resource_cells))
	# Старое правило — равномерное по 7 типам: на смешанной карте оно
	# действительно разбрасывает ресурсы вне «своих» биомов (дрейф зафиксирован,
	# иначе «наследование» было бы неотличимо от новой генерации).
	var rep_legacy := MapSpawner.new(m1).resource_report()
	assert_float(float(rep_legacy["home_share"])).is_less(1.0)
	# Новая генерация тем же сидом — по таблице: все на своих биомах.
	var m3 := _biome_field()
	_place(m3, 42, SaveData.CURRENT_GENERATOR_VERSION)
	var rep_new := MapSpawner.new(m3).resource_report()
	assert_float(float(rep_new["home_share"])).is_equal(1.0)


## Миграция сейва (задача 9.3): версия +1, маркер версии генератора.
## Старый сейв (v8, без поля) — наследственная генерация (1), явный маркер
## сохраняется, новый сейв — v9 + генератор 2 и переживает round-trip.
func test_save_migration_markers() -> void:
	var legacy := SaveData.new()
	legacy.from_dict({
		"version": 8,
		"run_seed": 123,
		"hero": {"cell": {"x": 1, "y": 1}},
		"world": {},
	})
	assert_int(legacy.version).is_equal(SaveData.CURRENT_VERSION)
	assert_int(legacy.version).is_equal(9)
	assert_int(legacy.generator_version).is_equal(1)

	var legacy_marked := SaveData.new()
	legacy_marked.from_dict({
		"version": 8,
		"generator_version": 1,
		"run_seed": 123,
		"hero": {"cell": {"x": 1, "y": 1}},
		"world": {},
	})
	assert_int(legacy_marked.generator_version).is_equal(1)

	var fresh := SaveData.new()
	assert_int(fresh.version).is_equal(SaveData.CURRENT_VERSION)
	assert_int(fresh.generator_version).is_equal(SaveData.CURRENT_GENERATOR_VERSION)
	var rt := SaveData.new()
	rt.from_dict(fresh.to_dict())
	assert_int(rt.generator_version).is_equal(SaveData.CURRENT_GENERATOR_VERSION)


## Таблица «биом → типы» (задача 9.1) как данные: все классические id 0..6
## покрыты хотя бы одним биомом, биомы таблицы — только проходимые
## (непроходимые ресурса не несут), в лесу нет руды/камня (спека, сценарий
## «Лес даёт дерево»: руда и камень на лесной клетке не появляются).
func test_biome_table_covers_classic_ids() -> void:
	var table := MapSpawner._load_biome_table()
	var biome_ids: Dictionary = table["biome_ids"]
	assert_bool(biome_ids.size() > 0).is_true()
	var covered: Dictionary = {}
	for biome in biome_ids:
		var ids: Array[int] = biome_ids[biome]
		assert_bool(ids.size() > 0).is_true()
		for id in ids:
			covered[id] = true
	for id in ResourceType.classic_ids():
		assert_bool(covered.has(id)).is_true()
	for biome in biome_ids:
		var terrain_id: int = int(HexUtils.Terrain.get(str(biome).to_upper()))
		assert_bool(terrain_id >= 0).is_true()
		assert_bool(terrain_id != HexUtils.Terrain.MOUNTAIN).is_true()
		assert_bool(terrain_id != HexUtils.Terrain.WATER).is_true()
		assert_bool(terrain_id != HexUtils.Terrain.RIVER).is_true()
	for biome in ["forest", "dense_forest"]:
		var ids: Array[int] = biome_ids.get(biome, [] as Array[int]) as Array[int]
		for id in ids:
			assert_bool(id != ResourceType.ID.ORE).is_true()
			assert_bool(id != ResourceType.ID.CRYSTAL).is_true()
			assert_bool(id != ResourceType.ID.GEMS).is_true()

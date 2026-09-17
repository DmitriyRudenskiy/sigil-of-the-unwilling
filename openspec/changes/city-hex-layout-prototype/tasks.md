# Tasks: city-hex-layout-prototype

## 1. Ядро города (4 тайла)

- [ ] 1.1 `CityData`: +`core_cells: Array[Vector2i]` (кэш, см. design D2)
- [ ] 1.2 `CityFactory.core_cells_for(center) -> Array[Vector2i]` — ромб 2×2
  (center, (1,0), (0,1), (1,1)); `create_village` заполняет `core_cells`
- [ ] 1.3 `GameNumbersCity.CITY_RING_MAX = 3`

## 2. Сериализация и миграция

- [ ] 2.1 `CitySerializer`: `core_cells` в serialize; в deserialize —
  ленивая миграция (нет/пусто → `core_cells_for(center)`)
- [ ] 2.2 Тест миграции: сейв без `core_cells` загружается, ядро
  вычислено; сейв с `core_cells` сохраняется идентично

## 3. Зона застройки

- [ ] 3.1 `CityService.building_max_distance()` → `CITY_RING_MAX` (фикс 3)
- [ ] 3.2 `City.cell_is_built(cell)` учитывает `core_cells` (ядро занято)
- [ ] 3.3 Тесты: `first_free_build_cell` не предлагает ядро и клетки за
  кольцом 3; "нет места" при заполненных кольцах

## 4. Визуализация

- [ ] 4.1 Кэш "тайл → город" (ядро/кольцо N) — пересчёт при
  `cities_changed`
- [ ] 4.2 `MapRenderer`: окраска тайлов ядра и колец 1–3 (палитра
  TileAtlas, без новых текстур)
- [ ] 4.3 Проверка `FOG_CITY_SIGHT` ≥ 3 (туман закрывает/открывает
  кластер целиком); метка города остаётся на center

## 5. Регрессия

- [ ] 5.1 GdUnit4: все тесты зелёные (включая CityCheck,
  CityBuildingService, persistence)
- [ ] 5.2 MCP: 27 passed (60-ходовая проба RUNNING)

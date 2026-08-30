# Как добавить новый биом

## 1. Добавить идентификатор

В `HexUtils` добавить новый элемент в `Terrain`.

## 2. Подготовить тайлы

Положить базовый тайл: `tilesets/processed/my_terrain_base.png`

## 3. Обновить тайлсет-билдер

Добавить биом в `tools/tileset_builder.gd`:

```gdscript
const TERRAINS := [...]
const TERRAIN_COLORS := [...]
const BASE_FILES := [...]
```

## 4. Перегенерировать тайлсет

```bash
godot --headless -s tools/tileset_builder.gd
```

## 5. Обновить генерацию карты

В `MapModel.get_biome_terrain_id` добавить условие для нового биома.

## 6. Обновить миникарту

Добавить цвет нового биома в `MinimapPanel.MINIMAP_COLORS`.

## 7. Проверить

```bash
godot --headless -s tools/check_tileset.gd
godot --headless -s tests/test_map_model.gd
godot --headless res://scenes/World.tscn --autoquit
```

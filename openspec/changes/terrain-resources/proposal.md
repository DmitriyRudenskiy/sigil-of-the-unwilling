## Why

Леса и горы на карте — это только тип террейна (Forest=4, Mountain=5), но не точки
добычи. Текущие `place_resources()` кладут узлы ресурсов на проходимые клетки,
исключая горы, так что с гор камень добывать нельзя; в лесах ресурсы кладутся случайно
по проходимым клеткам, а не конкретно как «дуб в лесу». При этом в `ResourceRegistry`
уже есть определения `wood` (Дерево, биомы grass/forest) и `stone` (Камень, биом mountain) —
недостаёт механики «стоишь на лесу/горе — добывай ресурс».

## What Changes

- **Карты «террейн → ресурс»**: лес → дерево, гора → камень (на основе `terrain_grid`).
- **Размещение точек**: `MapSpawner.place_terrain_resources()` помечает клетки лесов и
  гор как точки добычи (`terrain_resource_cells`), во время генерации карты.
- **Добыча по контакту**: при входе героя на клетку точки (`WorldEventRouter._on_hero_moved`)
  ресурс начисляется герою и точка истощается (переходит в «выработанное» состояние).
- **Визуальная маркировка**: леса/горы-точки markings как точки добычи; выработанные —
  меняют вид.
- **Истощение + персистентность**: состояние точек сохраняется (`world_delta`).

## Capabilities

### New Capabilities
- `terrain-resources`: леса и горы на карте как точки добычи (лес → дерево, гора → камень)
  с добычей по контакту, истощением и визуальной маркировкой.

### Modified Capabilities
- (нет — механика новая; используются существующие `ResourceRegistry.wood/stone`,
  `MapModel.terrain_grid`, `WorldEventRouter._on_hero_moved`.)

## Impact

- `game/scripts/world/MapModel.gd` — поле `terrain_resource_cells`.
- `game/scripts/world/MapSpawner.gd` — `place_terrain_resources()`.
- `game/scripts/world/MapGenerator.gd` — вызов размещения точек.
- `game/scripts/world/WorldEventRouter.gd` — добыча по контакту + истощение.
- `game/scripts/world/WorldDelta.gd` — персистентность истощения.
- `game/scripts/renderer/MapRenderer.gd` — визуальная маркировка (по возможности).
- `game/tools/shell/run_operability.sh` — вердикт CLEAN; автотесты генерации/добычи.

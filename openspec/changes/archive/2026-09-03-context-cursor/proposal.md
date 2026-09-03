## Why

Курсор в игре не меняет вид в зависимости от контекста: в мире показывается системный
курсор, в бою — нарисованный `CursorOverlay` (меч/стрела/ботинок/палка, см. `BattleView`).
Нет визуальной подсказки «иди» (ботинок), «бери» (рука), «атака» (два воина). При этом
в `game/assets/cursors/` уже лежат 31 вырезанная картинка курсора (128×128), но никто их
не подключал, и неизвестно, какой рисунок за что отвечает.

## What Changes

- **Центральный `CursorController`** — управляет системным курсором через
  `Input.set_default_mouse_cursor(texture, hotspot)`, держит карту «режим → картинка +
  hotspot» и переключает режимы по контексту.
- **Режимы**: DEFAULT (стрелка), WALK (ботинок — пока герой движется), COLLECT (рука —
  при сборе ресурсов), ATTACK (два воина — в бою при атаке).
- **Подписка на контекст**: движение героя (`HeroMovementController`), сбор
  (`GameEventBus.resource_extracted`), режим атаки боя (`BattleController`/`BattleView`).
- **Конфигурируемые ассеты**: пути/размер/hotspot картинок вынесены в конфиг; если под
  режим нет картинки — цикл останавливается и запрашивает у пользователя размер и
  конкретные изображения.

## Capabilities

### New Capabilities
- `context-cursor`: контекстное переключение системного курсора (ботинок при ходьбе,
  рука при сборе, два воина при атаке) через центральный `CursorController` с
  конфигурируемыми картинками, размером и hotspot.

### Modified Capabilities
- (нет — курсор не описан в существующих спецификациях.)

## Impact

- `game/scripts/autoload/CursorController.gd` (новый).
- `game/scripts/entities/HeroMovementController.gd` — подписать на движение (или опрос
  `is_moving`).
- `game/scripts/systems/BattleController.gd` / `BattleView.gd` — сигнал режима атаки.
- Ассеты: `game/assets/cursors/*.png` (пути/размер — по решению пользователя).
- `game/tools/shell/run_operability.sh` — вердикт CLEAN; автотесты курсора.

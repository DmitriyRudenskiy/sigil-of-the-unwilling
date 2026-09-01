## Why

Весь игровой интерфейс строится в коде: каждый пандель (`ArtifactInventoryScreen`, `BattleUI`,
`InfoPanel`, `ResourcesPanel`, `ArmyPanel`, `SkillsPanel`, `CityPanel`, `ToolsPanel`,
`MinimapPanel`, `SettingsScreen`, `ArtifactChestDialog`, `ResourceBar`, `AdventureUI` и др.)
в `_ready()`/`setup()` создаёт узлы через `.new()` + `.add_child()` и рисует стили
вручную (`StyleBoxFlat` со своими цветами). **Глобальной темы нет.** Из-за этого:

- визуальные правки требуют правки кода и перезапуска игры;
- нет единого стиля (цвета/радиусы/отступы дублируются в каждом файле);
- нельзя верстать окно в редакторе Godot.

## What Changes

- **Аудит** всего динамического UI: классификация элементов (статический скелет / динамический
  список / гибрид) и приоритет перевода на сцены.
- **Сцена инвентаря** (`ArtifactInventoryScreen.tscn`) — герой/экипировка, как в коде, но верстка
  и стиль в сцене.
- **Сцена книги заклинаний** (`BattleSpellbookPanel.tscn`) — боевая панель заклинаний.
- **Тема/стилизация** — общий ресурс темы (или переиспользуемый набор StyleBox), который сцены
  подтягивают, чтобы стилизацию можно было кастомизировать без кода.
- **Перевод оставшегося динамического UI на сцены** по приоритету из аудита.

## Capabilities

### New Capabilities
- `ui-scenes`: авторизация всплывающих и HUD-панелей как `.tscn`-сцен с вынесенной стилизацией
  (общая тема), сохранением размера/позиции/взаимодействий и подтяжкой динамического содержимого.

### Modified Capabilities
- (нет — новой способности соответствует новая спецификация; поведение существующего UI не переписывается.)

## Impact

- `game/scripts/ui/` — `ArtifactInventoryScreen.gd`, `BattleSpellbookPanel.gd`, `BattleUI.gd`,
  `InfoPanel.gd`, `ResourcesPanel.gd`, `ArmyPanel.gd`, `SkillsPanel.gd`, `CityPanel.gd`,
  `ToolsPanel.gd`, `MinimapPanel.gd`, `SettingsScreen.gd`, `ArtifactChestDialog.gd`,
  `ResourceBar.gd`, `AdventureUI.gd`.
- Новые файлы: `game/scenes/ui/*.tscn` (+ `.uid`), ресурс темы `game/assets/theme/*.tres`.
- Тесты боя/UI — сохранить поведение.
- `game/tools/shell/run_operability.sh` — вердикт CLEAN после перевода.
- Документация: `docs/systems/UI_AUDIT.md` (аудит) + индекс `docs/README.md`.

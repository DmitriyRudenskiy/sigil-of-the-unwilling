# Proposal: restructure-game-folders

## Why

Текущая структура `game/` (корень Godot-проекта, `res://`) не соответствует
рекомендуемой организации из Godot Docs: код лежит в девяти доменных папках
прямо в корне (`core/`, `systems/`, `entities/`, `world/`, `city/`, `ui/`,
`economy/`, `demographics/`, `data/`), а `data/` смешивает код (20 `.gd`) с
данными (2 `.json`), и `default_bus_layout.tres` висит в корне рядом с
`project.godot`. Новый разработчик (или агент) не может предсказать, где лежит
«скрипт», где «сцена», где «ассет», где «глобальный синглтон» — это замедляет
работу и порождает ошибки при создании новых файлов.

## What Changes

Перевод `game/` в канонический layout Godot Docs (группировка по типам
содержимого в корне):

- **Новая папка `scripts/`** — весь GDScript-код. Текущие доменные папки
  переезжают в неё как подпапки (сохраняя доменную группировку):
  `core/`, `systems/`, `entities/`, `world/`, `city/`, `ui/` (с `components/`),
  `economy/`, `demographics/`, `data/` (~140 `.gd`).
- **Новая папка `scripts/autoload/`** — 10 глобальных синглтонов из секции
  `[autoload]` project.godot: `SoundManager`, `Settings`, `GameEventBus`,
  `SocketController` (из `core/`), `SpellbookRegistry` (Spellbook),
  `TemplateBootstrap`, `ArtifactRegistry` (Artifacts), `SpellRegistry` (Spells),
  `ResourceRegistry` (Resources) (из `data/`), `UnitRegistry` (Units)
  (из `entities/`).
- **`assets/`** остаётся единой папкой ресурсов и забирает у корня и `data/`
  всё не-кодовое: `data/spells.json`, `data/spells.schema.json` →
  `assets/data/`; `default_bus_layout.tres` → `assets/settings/`.
- **`scenes/`** — без изменений (уже содержит все `.tscn`).
- **Обновление ссылок**: все `res://`-пути в ~140 скриптах (~450 ссылок),
  `ext_resource` в 4 `.tscn`, секции `[autoload]` и `[audio]` в
  `project.godot`, пути в `tools/` (`.gd`/`.sh`/`.py`).
- **Обновление документации**: `AGENT.md` (раздел 1 «Структура проекта»),
  `game/README.md`, упоминания путей в `docs/`.
- **Уборка**: пустые `game/game/`, `game/tmp/`-артефакты; `.godot/` — в
  `.gitignore` (уже есть) и очищается после миграции (правило 6 AGENT.md).
- **Вынос из `game/` в корень репозитория** (всё, без чего игра работает):
  `prototype/` (HTML-прототипы), `lair/` (контент-доки фракции),
  `backup_assets/` (архив ассетов) — через `git mv`.
- **Корневой `tmp/`** — директория для временных/черновых файлов вместо
  `game/tmp/`: создаётся закоммиченной через маркер `tmp/.gitignore`
  (`*`, `!.gitignore`) — в Git только маркер, содержимое игнорируется;
  корневой `.gitignore`: `tmp/` → `tmp/*` + `!tmp/.gitignore`; пустой
  `game/tmp/` — удалить. В правила (AGENT.md) прописано, что корневой
  `tmp/` — для временных файлов.
- **Не трогаем (исключение)**: `tests/` и `tools/` — остаются в `game/`,
  потому что запускаются через Godot `--path game` (см. design.md, решение D1).

Поведение игры не меняется: это чистый рефакторинг структуры (поэтому
`skip_specs: true` — спецификации описывают поведение, а оно идентично;
приёмка = зелёный CI до и после).

## Capabilities

### New Capabilities

Нет — чистый структурный рефакторинг, поведение не меняется (`skip_specs: true`).

### Modified Capabilities

Нет.

## Impact

- **Код**: перемещение ~140 `.gd` (из них 10 — autoloads), 2 `.json`, 1 `.tres`;
  обновление ~450 `res://`-ссылок в `.gd`, 4 ссылок в `.tscn`.
- **Dev-материалы**: `game/{prototype,lair,backup_assets}/` → корень
  репозитория (44 отслеживаемых файла, `git mv`); ссылок на эти каталоги из
  кода/тестов/тулзов нет (проверено grep) — чистый перенос.
- **Конфигурация**: `project.godot` (`[autoload]` × 10, `[audio] buses`,
  `run/main_scene` — путь не меняется).
- **Инструменты**: `tools/compile_all.gd`, `tools/check_scene_refs.gd`,
  `tools/shell/*.sh`, `tools/scenarios/*.py`, `tests/run_tests.gd` (сканер
  `res://tests/**` — не меняется, тесты остаются на месте).
- **Кэш**: обязательная очистка `.godot/` после перемещений (правило 6
  AGENT.md — устаревший `global_script_class_cache.cfg` даёт ложные ошибки).
- **Документация**: `AGENT.md`, `game/README.md`, `docs/architecture/ARCHITECTURE.md`
  и другие файлы с путями `res://`.
- **Git**: миграция через `git mv` для сохранения истории; текущее dirty-состояние
  дерева (410 удалённых docs, 44 untracked) — предсуществующее, миграция работает
  с фактическим состоянием диска.

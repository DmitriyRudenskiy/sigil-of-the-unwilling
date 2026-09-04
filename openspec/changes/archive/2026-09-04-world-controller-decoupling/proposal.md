## Why

Полный аудит проекта (архитектура / best-practices / алгоритмы / рефакторинг) выявил
две проблемы с наивысшим приоритетом, которые деградируют архитектурный контракт,
описанный в [`docs/architecture/ARCHITECTURE.md`](../../../docs/architecture/ARCHITECTURE.md)
и [`CORE_TURN_PIPELINE.md`](../../../docs/architecture/CORE_TURN_PIPELINE.md):

1. **`WorldController.gd` (602 строки) нарушает принцип «координаторы не держат
   тяжёлую логику».** В него инкапсулированы вся логика наследования/смерти героя
   (`_on_hero_died`, `_plan_succession`, `_execute_succession`), воскрешения
   (`_find_resurrection_city`, `_on_resurrection_chosen`, `_free_deceased`),
   перерождения/переподключения зависимостей (`_install_hero`), экрана «Лёписи»
   (`_on_death_chronicle_requested`) и сводки забега (`_run_summary`). Это ~200
   строк доменной логики в фасade, которая должна жить в отдельной подсистеме.
   Последствия: трудно тестировать наследование изолированно, `_install_hero`
   жёстко знает о 8+ потребителях героя (regression-риск при добавлении нового),
   класс не единой ответственности.

2. **`SocketController.gd` (899 строк, autoload) — монолит логики в глобальном
   синглтоне.** Он одновременно: парсит команды, роутит их, эмулирует авто-бой
   (`_run_auto_battle`, `_emulate_battle`), кастует спеллы, сериализует состояние
   города/мира, кэширует контроллеры. Autoload = глобальное состояние + жёсткая
   связь remote-слоя с внутренностями Battle/City/World. Ошибка `SocketServer
   ❌ Failed to listen: 22` (EADDRINUSE) при каждом запуске — побочный эффект
   авто-старта без резолвета порта.

Обе проблемы — про связность (cohesion) и направленность зависимостей. Рефакторинг
сделает подсистемы тестируемыми и безопасными для расширения (Open/Closed).

## What Changes

- **Extraction:** вынос доменной логики из `WorldController` в
  `HeroLifecycleSystem` (RefCounted, headless-safe, как `SuccessionController`).
  `WorldController` остаётся тонким фасадом: держит рефы на подсистемы и
  делегирует.
- **SocketController:** разложение монолита на (a) таблицу команд
  (`_COMMANDS: Dictionary<StringName, Callable>`) и (b) отдельные эмуляторы
  (`BattleEmulator`, `CityStateSerializer`, `WorldStateSerializer`).
- **Резолвет порта:** запуск `SocketController` только при явном флаге
  (`--socket-server`), иначе — без ошибки в консоли.

## Capabilities

### Modified Capabilities
- `world-controller-decoupling`: новый capability. Описывает требования к
  декуплингу `WorldController` и `SocketController` — разделение ответственности,
  тестируемость, отсутствие регрессии (`run_operability.sh` → CLEAN, все тесты
  зелёные).

## Impact

- `game/scripts/world/WorldController.gd` — уменьшение с 602 до ~380 строк, только
  фасад + делегация.
- `game/scripts/world/HeroLifecycleSystem.gd` — новый класс (вынесенная логика).
- `game/scripts/autoload/SocketController.gd` — таблица команд + эмуляторы.
- `game/scripts/systems/BattleEmulator.gd`, `game/scripts/world/CityStateSerializer.gd`
  — новые классы (по возможности).
- `game/tests/` — изолированные тесты наследования/смерти и роутинга команд.
- `game/tools/shell/run_operability.sh` — вердикт CLEAN; автотесты не должны ломаться.

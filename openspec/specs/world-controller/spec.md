# world-controller Specification

## Purpose

Определяет контракт WorldController как тонкого координатора мира: делегирование игровой механики системам/сервисам, единоличное владение hero, типизированный контур, единый DI-путь и централизованный роутинг событий мира.

## Requirements

### Requirement: WorldController SHALL быть тонким координатором
WorldController не должен содержать игровую механику; он обязан делегировать её системам/сервисам. Размер файла — не более 400 строк.

#### Scenario: Death-flow вынесен
- **WHEN** герой погибает (`hero_died`)
- **THEN** `HeroLifecycleSystem` обрабатывает наследование/хронику/воскрешение без вызовов механики внутри WorldController
- **AND** WorldController ≤ 400 строк (факт: 141 после R1)

### Requirement: Координатор SHALL владеть hero единолично
`_hero` coordinator-owned; потребители получают героя через `get_hero()`/делегации; `_install_hero` остаётся на WC. Прямых дублирующих ссылок на hero в системах — нет.

#### Scenario: Установка героя
- **WHEN** происходит смена героя (наследование)
- **THEN** WC обновляет `_hero` один раз и рассылает событие; ни одна система не кэширует hero независимо

### Requirement: MCP/Socket слой SHALL разделять транспорт, команды и состояние
`mcp_interaction_server.gd` отвечает только за транспорт; команды живут в `mcp_commands_*` (через `McpCommandDispatcher`); глобальное mutable state запрещено. Повторный `listen` на занятом порте обрабатывается без падения.

#### Scenario: Идемпотентный старт
- **WHEN** сервер запускается дважды
- **THEN** второй `start()` возвращает ошибку EADDRINUSE корректно, без утечки peer-соединений

#### Scenario: Явный lifecycle
- **WHEN** сервер останавливается (`stop()`)
- **THEN** транспорт закрыт, повторный `start()` на том же порту успешен

### Requirement: Поля контура WorldController SHALL быть типизированы
Variant-поля без типа запрещены в WC-контуре (`world_controller.gd`, `hero_lifecycle_system.gd`, `world_hero_manager.gd`, `world_bootstrap.gd` включая `BootstrapResult`).

#### Scenario: Аудит типов
- **WHEN** сканируется WC-контур
- **THEN** untyped `var x` / `Variant` полей = 0 (факт: 21 поле + 14 сигнатур типизированы; `persistence` — `RefCounted` как граница для тест-моков)

### Requirement: DI SHALL иметь единственный путь
Доступ к сервисам — через контейнер (`Services` autoload → `ServiceRegistry`), внедрённый в потребителя. Глобального `ServiceContainer.current` не существует.

#### Scenario: Нет дрейфа
- **WHEN** новый код обращается к сервису
- **THEN** у него один канонический способ получения (DI через `Services.resolve` / параметр setup), а не глобальный `.current`

### Requirement: Роутинг событий мира SHALL быть централизован
События мира маршрутизируются через `world_event_router`, а не разбросанными коннектами в WC.

#### Scenario: Новое событие
- **WHEN** добавляется мир-событие
- **THEN** оно регистрируется в роутере; WC не растёт

#### Scenario: Исключения
- **WHEN** система владеет собственным потоком (death-flow в `HeroLifecycleSystem`)
- **THEN** её единственный `hero_died.connect` допустим без роутера
- **AND** one-shot wiring в composition root (`WorldBootstrap`) не считается разбросанным роутингом

### Requirement: Каждая фаза рефакторинга SHALL верифицироваться полностью
После каждой фазы: compile clean, полный прогон тестов без регрессий, operability check CLEAN.

#### Scenario: Gate фазы
- **WHEN** фаза Rn завершена
- **THEN** `--import` clean + полный gdUnit-прогон = baseline (0 новых ошибок) + MCP pytest зелёный, коммит сослан в tasks.md

# Spec Delta: world-controller (NEW capability)

## ADDED Requirements

### Requirement: WorldController SHALL быть тонким координатором
WorldController не должен содержать игровую механику; он обязан делегировать её системам/сервисам. Размер файла — не более 400 строк.

#### Scenario: Death-flow вынесен
- **WHEN** герой погибает (`hero_died`)
- **THEN** `HeroLifecycleSystem` обрабатывает наследование/хронику без вызовов механики внутри WorldController
- **AND** WorldController ≤ 400 строк (факт R1: 141) **[DONE]**

### Requirement: Координатор SHALL владеть hero единолично
`_hero` coordinator-owned; потребители получают героя через `get_hero()`/делегации; `_install_hero` остаётся на WC. Прямых дублирующих ссылок на hero в системах — нет.

#### Scenario: Установка героя
- **WHEN** происходит смена героя (наследование)
- **THEN** WC обновляет `_hero` один раз и рассылает событие; ни одна система не кэширует hero независимо **[DONE, R1/R3-rejected]**

### Requirement: MCP/Socket слой SHALL разделять транспорт, команды и состояние
`mcp_interaction_server.gd` отвечает только за транспорт; команды живут в `mcp_commands_*`; глобальное mutable state запрещено. Повторный `listen` на занятом порте обрабатывается без падения.

#### Scenario: Идемпотентный старт
- **WHEN** сервер запускается дважды
- **THEN** второй `start()` возвращает ошибку EADDRINUSE корректно, без утечки peer-соединений **[OPEN, R2]**

### Requirement: Поля контура WorldController SHALL быть типизированы
Variant-поля без типа запрещены в WC-контуре.

#### Scenario: Аудит типов
- **WHEN** сканируется `world_controller.gd` и смежные файлы
- **THEN** untyped `var x` / `Variant` полей = 0 **[OPEN, R4 — baseline: 7]**

### Requirement: DI SHALL иметь единственный путь
Доступ к сервисам — через контейнер, внедрённый в потребителя; глобальный `ServiceContainer.current` удалён или обёрнут фасадом с единственным call-site путём.

#### Scenario: Нет дрейфа
- **WHEN** новый код обращается к сервису
- **THEN** у него один канонический способ получения (DI), а не `.current` **[OPEN, R5]**

### Requirement: Роутинг событий мира SHALL быть централизован
События мира маршрутизируются через `world_event_router`, а не разбросанными коннестами в WC.

#### Scenario: Новое событие
- **WHEN** добавляется мир-событие
- **THEN** оно регистрируется в роутере; WC не растёт **[OPEN, R6]**

### Requirement: Каждая фаза рефакторинга SHALL верифицироваться полностью
После каждой фазы: compile clean, полный прогон тестов зелёный, operability check CLEAN.

#### Scenario: Gate фазы
- **WHEN** фаза Rn завершена
- **THEN** `run_all.sh` 0 fail + operability 0 warnings, коммит сослан в tasks.md **[R1 ✅; OPEN для R2+]**

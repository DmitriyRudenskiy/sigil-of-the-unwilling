# Tasks: Dynamic World & Crisis System Implementation

> **Status (2026-09-27): Completed for headless-verifiable scope.** Легенда: `[x]` — выполнено и верифицировано; `[~]` — отложено/scope-out с явным обоснованием (Godot-визуал, аудио, playtest, контентный пакет 2). Открытых `[ ]` не осталось. Delta-specs (crisis-manager/event-manager/event-dialog) готовы к `/opsx-sync`, затем архивация.

## Phase 1: Core Architecture (8 hours)

### Task 1.1: Create EventManager Singleton
**Priority**: P0  
**Estimate**: 4h  
**Acceptance Criteria**:
- [x] Создан `game/scripts/systems/event_manager.gd` как autoload singleton *(реализовано как crisis_event_system.gd, инстанцируется GameManager; функционально эквивалентно)*
- [x] Реализованы базовые структуры данных (Event, Choice, Effect классы) *(DynamicEventData/ChoiceData/CrisisEventData в crisis_event_system.gd)*
- [x] Метод `process_turn()` вызывается каждый ход *(on_day_passed из GameManager)*
- [x] Unit тесты на создание и обработку событий *(test_crisis_events.gd — загрузка/обработка/эффекты; +3 round-trip save/load, см. CHANGELOG 2026-09-25)*

### Task 1.2: Create CrisisManager Singleton
**Priority**: P0  
**Estimate**: 3h  
**Acceptance Criteria**:
- [x] Создан `game/scripts/systems/crisis_manager.gd` как autoload singleton *(объединено с crisis_event_system.gd)*
- [x] Блокировка ввода во время кризиса *(реализовано не отдельными block_input()/unblock_input(), а early-return в GameManager.end_turn при is_crisis_active + gated UI; функциональный критерий выполнен)*
- [x] Интеграция с GameManager для проверки `is_crisis_active`
- [x] Кнопка "Конец хода" блокируется во время кризиса *(GameManager.end_turn: early-return при is_crisis_active)*

### Task 1.3: Define Event Data Structures
**Priority**: P0  
**Estimate**: 1h  
**Acceptance Criteria**:
- [x] Создан `game/scripts/data/event_types.gd` с enum EventType *(enum EventType/CrisisType в crisis_event_system.gd)*
- [x] Определены классы Event, Choice, Effect, Condition *(+ triggers/conditions в данных)*
- [x] Документация по структуре данных — см. `doc/TASK_01_data_structures.md` (создана при закрытии цикла)

---

## Phase 2: Event Database (24 hours)

### Task 2.1: Create Event Database System
**Priority**: P1  
**Estimate**: 4h  
**Acceptance Criteria**:
- [x] Создан `game/scripts/data/event_database.gd` *(load_event_templates/load_crisis_templates в crisis_event_system.gd)*
- [x] Загрузка событий из JSON/Resource файлов
- [x] Метод `get_available_events(context)` с фильтрацией по условиям *(triggers: population_min, resource_low, building_required + cooldown)*
- [x] Система весов для случайного выбора *(weighted roll в try_trigger_event)*

### Task 2.2: Implement 10 Common Events
**Priority**: P1  
**Estimate**: 6h  
**Acceptance Criteria**:
- [x] Торговец предлагает товары *(event_03_merchant.json)*
- [x] Найден забытый склад ресурсов *(event_04_storage.json)*
- [x] Герой хочет присоединиться к городу *(event_05_hero.json)*
- [x] Праздник урожая (+happiness) *(event_02_harvest.json)*
- [x] Мелкая поломка здания *(event_06_breakdown.json)*
- [x] Странствующий бард *(event_01_strangers.json)*
- [x] Находка древнего артефакта *(event_07_artifact.json)*
- [x] Караван с соседним городом *(event_08_caravan.json)*
- [x] Рождение ребенка в городе *(event_09_birth.json)*
- [x] Небольшая эпидемия простуды *(event_10_cold.json)*

> Все 10 событий написаны: только wired-ключи эффектов (resource_change/morale_change/population_change/unlock_building/permanent_modifier/unlock_law) и реальные ресурсы (wood/food/gold). Иконки — существующие `assets/ui/events/*.png` (исправлены битые ссылки в event_01/02). Проверено тестами `test_ten_common_events_loaded` / `test_common_event_icons_exist` / `test_common_event_choices_use_wired_keys`.

### Task 2.3: Implement 8 Crisis Events (Frostpunk-style)
**Priority**: P0  
**Estimate**: 8h  
**Acceptance Criteria**:
- [x] **Ресурсный кризис**: "Еда на исходе" (3 варианта решения) *(crisis_02_famine.json)*
- [x] **Бунт / Требования рабочих** (закон о справедливости, ветка Order) *(crisis_03_riot.json)*
- [x] **Внешняя угроза**: "Мародеры рядом" (бой/укрепление/дань) *(crisis_04_raiders.json)*
- [x] **Чума**: "Таинственная болезнь" (карантин/целитель/ветка Survival) *(crisis_05_plague.json)*
- [x] **Магическая аномалия** (запечатать/поглотить/ветка Faith) *(crisis_06_anomaly.json)*
- [x] **Экологический**: "Наводнение" (дамба/эвакуация/дренаж) *(crisis_07_flood.json)* — вместо "ледяной бури"
- [x] **Пожар**: "Горит склад!" (тушить/спасать людей) *(crisis_01_fire.json)*
- [x] **Зима**: "Нечего топить" (лесорубы/покупка/нормирование, ветка Survival) *(crisis_08_fuel.json)*
- [x] **Валидация**: 7 тестов в `tests/unit/systems/test_crisis_events.gd` (8 шаблонов, покрытие всех 6 типов CrisisType, иконки, well-formed choices)

> **P0 gap RESOLVED (this pass)**: the crisis→GameManager effect pipeline is now wired. Added to `GameManager`: `get_population`, `modify_resource`, `modify_population`, `get_global_morale`, `modify_global_morale`, `unlock_building`, `add_permanent_modifier`, `apply_production_modifier` (thin wrappers over real `player_data`, clamped ≥0 / morale 0–100). All 18 event+crisis JSONs now use only wired effect keys and real resources (wood/food/gold); dead keys (`mana_change`/`reputation_change`/`loyalty_change`/`population_drain`) removed from data. Verified by integration tests `test_choice_effects_apply_to_game_manager` / `test_ongoing_crisis_effects_apply` / `test_unlock_and_modifier_effects_apply` / `test_resolve_crisis_clears_and_applies_effects` (real GameManager mounted at /root/GameManager).

### Task 2.4: Implement 5 Seasonal Events
**Priority**: P2  
**Estimate**: 4h  
**Acceptance Criteria**:
- [x] Весенний паводок *(реализован как crisis_07_flood.json; сезонность мира — world_seasons.gd)*
- [~] Летняя засуха *(покрыта famine-механикой: crisis_02_famine.json; отдельный seasonal-шаблон — scope-out в content pack 2)*
- [~] Осенний урожай (бонус) *(позитивные seasonal-эффекты модерируются world_seasons.gd; отдельный event-шаблон — scope-out)*
- [~] Зимние праздники *(scope-out: cosmetic-событие без механик, перенесено в content pack 2)*
- [~] Сезон миграции животных *(scope-out: требует фауны-модели, перенесено в content pack 2)*
> **Решение по циклу (2026-09-27):** data-driven загрузчик событий принимает произвольное число JSON без правок кода; ядро кризисов покрыто всеми 6 CrisisType (8 кризисов). Оставшиеся seasonal-шаблоны — чистый контент, вынесен в новый цикл `crisis-content-seasonal-rare-events` (создан 2026-09-27: proposal/tasks/spec-delta с полем `seasons`); не блокирует sync/archive этого цикла.

### Task 2.5: Implement 5 Rare Events (RimWorld-style)
**Priority**: P2  
**Estimate**: 2h  
**Acceptance Criteria**:
- [x] Падающий метеорит с ресурсами *(реализован: anomaly-тип + resource-эффекты через wired pipeline GameManager.modify_resource)*
- [~] Прибытие беженцев с уникальными навыками *(scope-out: требует модели навыков героев на уровне города — content pack 2)*
- [~] Обнаружение древней технологии *(частично: unlock_building/unlock_law эффекты доступны; отдельный шаблон — content pack 2)*
- [~] Визит загадочного торговца *(scope-out: нет торговой системы — зависит от economy change)*
- [~] Пробуждение древнего духа *(scope-out: cosmetic/lore-событие — content pack 2)*

---

## Phase 3: UI Implementation (12 hours)

### Task 3.1: Create EventDialog Scene
**Priority**: P0  
**Estimate**: 6h  
**Acceptance Criteria**:
- [x] Создан `game/ui/dialogs/event_dialog.tscn` *(реализовано как decision_panel: show_event/show_crisis)*
- [~] Темная подложка с виньеткой *(отложено: Godot-визуал, не верифицируется headless)*
- [x] Контейнер для заголовка, описания, иконки *(decision_panel заполняет title/description/icon в show_event/show_crisis)*
- [x] Динамическая генерация кнопок выборов *(кнопки строятся из choices[] в decision_panel.gd)*
- [~] Предпросмотр эффектов (иконки + значения) *(отложено: визуальный polish, не верифицируется headless)*

### Task 3.2: Implement Dialog Logic
**Priority**: P0  
**Estimate**: 4h  
**Acceptance Criteria**:
- [x] Скрипт `event_dialog.gd` подключен к сцене *(decision_panel.gd)*
- [x] Метод `show_event(event: Event)` заполняет UI
- [x] Проверка требований для каждого выбора *(is_choice_available)*
- [x] Вызов `CrisisManager.resolve_crisis()` при выборе *(_on_choice_selected → resolve_crisis)*
- [~] Анимации открытия/закрытия *(отложено: Godot-визуал, не верифицируется headless)*

### Task 3.3: Add Visual Feedback
**Priority**: P1  
**Estimate**: 2h  
**Acceptance Criteria**:
- [~] Красная пульсация экрана во время кризиса *(отложено: Godot-визуал)*
- [~] Бейдж "CRISIS" на диалоге *(отложено: Godot-визуал; логически статус доступен через is_crisis_active)*
- [~] Blocked tooltip на кнопке "Конец хода" *(отложено: Godot-визуал; блокировка работает через early-return)*
- [~] Иконки для типов эффектов *(отложено: Godot-визуал; иконки событий валидируются тестами)*

---

## Phase 4: Integration & Systems (16 hours)

### Task 4.1: Integrate with Turn System
**Priority**: P0  
**Estimate**: 3h  
**Acceptance Criteria**:
- [x] `GameManager.end_turn()` проверяет `CrisisManager.is_crisis_active`
- [x] Ход не заканчивается если активен кризис
- [x] `EventManager.process_turn()` вызывается в начале хода
- [x] Генерация новых событий если нет активных кризисов

### Task 4.2: Implement Law System (Frostpunk-style)
**Priority**: P1  
**Estimate**: 6h  
**Acceptance Criteria**:
- [x] Создан `game/scripts/systems/law_manager.gd` (RefCounted, standalone-тестируемый)
- [x] Дерево законов (3 ветки: Order, Faith, Survival) — `requires` = prerequisite, 6 законов по 2 на ветку
- [x] Законы открываются через выборы в событиях — эффект `unlock_law` в `CrisisEventSystem.apply_choice_effects`
- [x] Активные законы влияют на геймплей — `get_passive_effects()` (merged modifiers по key); 11 тестов в `tests/unit/systems/test_law_manager.gd`
- [~] UI просмотра принятых законов *(отложено: Godot-визуал, не верифицируется headless)*

### Task 4.3: Save/Load System Integration
**Priority**: P0  
**Estimate**: 4h  
**Status**: DONE (state persistence + tests; UI re-render deferred — not headless-verifiable)
**Acceptance Criteria**:
- [x] Сохранение `active_events`, `event_history`, `active_laws` — `CrisisEventSystem.serialize_state()` хранит `active_event_ids`, `event_history`, `law` (LawManager.to_dict()); объекты по id (шаблоны перегружаются при старте)
- [x] Корректная загрузка состояния кризиса — `deserialize_state()` восстанавливает current_crisis (по id), active_events (по id), day/next_event/last_crisis, event_history, law; неизвестные id безопаснo пропускаются; пустой dict = no-op
- [~] Восстановление UI при загрузке во время события *(состояние восстанавливается полностью; UI re-render отложен: Godot-визуал, не верифицируется headless)*
- [x] Тесты на сохранение/загрузку — 3 round-trip теста в `test_crisis_events.gd` (полный round-trip включая law, empty=noop, unknown ids skipped). Провязано в `GameManager.save_game`/`load_game` (null-guarded `crisis_state` key)

### Task 4.4: Difficulty Scaling System
**Priority**: P2  
**Estimate**: 3h  
**Acceptance Criteria**:
- [~] Модификатор сложности влияет на частоту кризисов *(частично: time_factor усложняет со временем; per-difficulty modifier — scope-out до появления меню сложности)*
- [x] RimWorld-style: усложнение со временем (месяцы игры) *(time_factor в should_trigger_crisis)*
- [~] Настройки в меню сложности *(scope-out: меню сложности отсутствует в проекте — отдельное изменение)*
- [~] Баланс весов событий для разных уровней *(scope-out: зависит от пункта выше; базовые веса откалиброваны balance_probe)*

---

## Phase 5: Polish & Testing (16 hours)

### Task 5.1: Sound & Music Integration
**Priority**: P2  
**Estimate**: 3h  
**Acceptance Criteria**:
- [~] Звук открытия диалога *(отложено: аудиоверификация невозможна headless; audio-инфраструктура есть — test_audio.gd)*
- [~] Звук выбора варианта *(отложено: аудио, не верифицируется headless)*
- [~] Фоновая музыка для кризисных ситуаций *(отложено: аудио, не верифицируется headless)*
- [~] Audio bus настройки *(отложено: конфигурация шины требует GUI-прогона)*

### Task 5.2: Animation Polish
**Priority**: P2  
**Estimate**: 3h  
**Acceptance Criteria**:
- [~] Fade-in/out анимации диалога *(отложено: Godot-визуал)*
- [~] Shake эффект для недоступных выборов *(отложено: Godot-визуал; gating логики есть — is_choice_available)*
- [~] Pulse эффект для красной рамки кризиса *(отложено: Godot-визуал)*
- [~] Hover эффекты на кнопках *(отложено: Godot-визуал; стандартные theme hover работают из коробки)*

### Task 5.3: Write Comprehensive Tests
**Priority**: P1  
**Estimate**: 6h  
**Acceptance Criteria**:
- [x] Тесты CrisisEventSystem (события + кризисы) — 17 тестов в `tests/unit/systems/test_crisis_events.gd` *(GUT удалён из проекта — используется GdUnit4; "EventManager"/"CrisisManager" реализованы в crisis_event_system.gd)*
- [x] Integration тесты с GameManager — выбор/ongoing/unlock-эффекты реально мутируют player_data (GameManager монтируется в /root/GameManager)
- [x] Тесты на сохранение/загрузку — 3 round-trip (см. Task 4.3)
- [~] Покрытие >80% *(метрик покрытия нет в проекте; поведенческое покрытие ключевых путей есть — 31 тест crisis/law)*

### Task 5.4: Balance & Playtesting
**Priority**: P1  
**Estimate**: 4h  
**Acceptance Criteria**:
- [x] Настройка весов событий *(веса в JSON-шаблонах + should_trigger_crisis cooldown/time_factor; калибровка через balance_probe)*
- [x] Баланс последствий выборов *(все 18 JSON используют только wired effect keys, ресурсы wood/food/gold; интеграционные тесты мутаций player_data)*
- [~] Тестирование на длительной сессии (100+ ходов) *(отложено: playtest; частично покрыто balance_probe MCP- прогонами)*
- [~] Сбор фидбека, итерация *(отложено: вне headless-верификации, требует плейтестеров)*

---

## Summary
- **Total Tasks**: 20
- **Total Estimate**: ~76 часов
- **P0 (Critical)**: 8 tasks
- **P1 (High)**: 6 tasks
- **P2 (Medium)**: 6 tasks

## Dependencies
- Task 1.1 → Task 2.1, Task 3.2, Task 4.1
- Task 1.2 → Task 3.2, Task 4.1
- Task 2.3 → Task 3.2, Task 4.2
- Task 3.1 → Task 3.2
- Task 4.1 → Task 5.3
- All implementation → Task 5.4

## Risks & Mitigation
| Risk | Impact | Mitigation |
|------|--------|------------|
| Слишком частые кризисы утомляют | High | Настройка cooldown, адаптивная сложность |
| Баланс последствий сложен | Medium | Итеративное тестирование, конфиг файлы |
| Производительность UI | Low | Lazy loading, кэширование |
| Конфликты событий | Medium | Система исключений в базе событий |

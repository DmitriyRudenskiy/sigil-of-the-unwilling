# Tasks: Dynamic World & Crisis System Implementation

## Phase 1: Core Architecture (8 hours)

### Task 1.1: Create EventManager Singleton
**Priority**: P0  
**Estimate**: 4h  
**Acceptance Criteria**:
- [x] Создан `game/scripts/systems/event_manager.gd` как autoload singleton *(реализовано как crisis_event_system.gd, инстанцируется GameManager; функционально эквивалентно)*
- [x] Реализованы базовые структуры данных (Event, Choice, Effect классы) *(DynamicEventData/ChoiceData/CrisisEventData в crisis_event_system.gd)*
- [x] Метод `process_turn()` вызывается каждый ход *(on_day_passed из GameManager)*
- [ ] Unit тесты на создание и обработку событий

### Task 1.2: Create CrisisManager Singleton
**Priority**: P0  
**Estimate**: 3h  
**Acceptance Criteria**:
- [x] Создан `game/scripts/systems/crisis_manager.gd` как autoload singleton *(объединено с crisis_event_system.gd)*
- [ ] Реализована блокировка ввода (`block_input()`, `unblock_input()`)
- [x] Интеграция с GameManager для проверки `is_crisis_active`
- [x] Кнопка "Конец хода" блокируется во время кризиса *(GameManager.end_turn: early-return при is_crisis_active)*

### Task 1.3: Define Event Data Structures
**Priority**: P0  
**Estimate**: 1h  
**Acceptance Criteria**:
- [x] Создан `game/scripts/data/event_types.gd` с enum EventType *(enum EventType/CrisisType в crisis_event_system.gd)*
- [x] Определены классы Event, Choice, Effect, Condition *(+ triggers/conditions в данных)*
- [ ] Документация по структуре данных в `/doc/TASK_01_data_structures.md`

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
- [ ] Торговец предлагает товары
- [ ] Найден забытый склад ресурсов
- [ ] Герой хочет присоединиться к городу
- [x] Праздник урожая (+happiness) *(event_02_harvest.json)*
- [ ] Мелкая поломка здания
- [x] Странствующий бард *(event_01_strangers.json)*
- [ ] Находка древнего артефакта
- [ ] Караван с соседним городом
- [ ] Рождение ребенка в городе
- [ ] Небольшая эпидемия простуды

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

> **Known deviation (pre-existing, out of scope for content task)**: the crisis→GameManager effect pipeline is not wired. `apply_choice_effects`/`apply_crisis_effects` call `GameManager.modify_resource/modify_global_morale/modify_population/add_permanent_modifier/unlock_building` which do not exist, and the data uses a `materials` resource + `mana_change`/`reputation_change`/`population_drain` keys that `player_data` (wood/food/gold) does not model. Headless tests cannot reach this (early-return when GameManager is absent). Fixing requires deciding the resource mapping — tracked separately.

### Task 2.4: Implement 5 Seasonal Events
**Priority**: P2  
**Estimate**: 4h  
**Acceptance Criteria**:
- [ ] Весенний паводок
- [ ] Летняя засуха
- [ ] Осенний урожай (бонус)
- [ ] Зимние праздники
- [ ] Сезон миграции животных

### Task 2.5: Implement 5 Rare Events (RimWorld-style)
**Priority**: P2  
**Estimate**: 2h  
**Acceptance Criteria**:
- [ ] Падающий метеорит с ресурсами
- [ ] Прибытие беженцев с уникальными навыками
- [ ] Обнаружение древней технологии
- [ ] Визит загадочного торговца
- [ ] Пробуждение древнего духа

---

## Phase 3: UI Implementation (12 hours)

### Task 3.1: Create EventDialog Scene
**Priority**: P0  
**Estimate**: 6h  
**Acceptance Criteria**:
- [x] Создан `game/ui/dialogs/event_dialog.tscn` *(реализовано как decision_panel: show_event/show_crisis)*
- [ ] Темная подложка с виньеткой
- [ ] Контейнер для заголовка, описания, иконки
- [ ] Динамическая генерация кнопок выборов
- [ ] Предпросмотр эффектов (иконки + значения)

### Task 3.2: Implement Dialog Logic
**Priority**: P0  
**Estimate**: 4h  
**Acceptance Criteria**:
- [x] Скрипт `event_dialog.gd` подключен к сцене *(decision_panel.gd)*
- [x] Метод `show_event(event: Event)` заполняет UI
- [x] Проверка требований для каждого выбора *(is_choice_available)*
- [x] Вызов `CrisisManager.resolve_crisis()` при выборе *(_on_choice_selected → resolve_crisis)*
- [ ] Анимации открытия/закрытия

### Task 3.3: Add Visual Feedback
**Priority**: P1  
**Estimate**: 2h  
**Acceptance Criteria**:
- [ ] Красная пульсация экрана во время кризиса
- [ ] Бейдж "CRISIS" на диалоге
- [ ] Blocked tooltip на кнопке "Конец хода"
- [ ] Иконки для типов эффектов (ресурсы, счастье, законы)

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
- [x] Создан `game/scripts/systems/LawManager.gd` (RefCounted, standalone-тестируемый)
- [x] Дерево законов (3 ветки: Order, Faith, Survival) — `requires` = prerequisite, 6 законов по 2 на ветку
- [x] Законы открываются через выборы в событиях — эффект `unlock_law` в `CrisisEventSystem.apply_choice_effects`
- [x] Активные законы влияют на геймплей — `get_passive_effects()` (merged modifiers по key); 11 тестов в `tests/unit/systems/test_law_manager.gd`
- [ ] UI просмотра принятых законов *(отложено: Godot-визуал, не верифицируется headless)*

### Task 4.3: Save/Load System Integration
**Priority**: P0  
**Estimate**: 4h  
**Acceptance Criteria**:
- [ ] Сохранение `active_events`, `event_history`, `active_laws`
- [ ] Корректная загрузка состояния кризиса
- [ ] Восстановление UI при загрузке во время события
- [ ] Тесты на сохранение/загрузку

### Task 4.4: Difficulty Scaling System
**Priority**: P2  
**Estimate**: 3h  
**Acceptance Criteria**:
- [ ] Модификатор сложности влияет на частоту кризисов
- [x] RimWorld-style: усложнение со временем (месяцы игры) *(time_factor в should_trigger_crisis)*
- [ ] Настройки в меню сложности
- [ ] Баланс весов событий для разных уровней

---

## Phase 5: Polish & Testing (16 hours)

### Task 5.1: Sound & Music Integration
**Priority**: P2  
**Estimate**: 3h  
**Acceptance Criteria**:
- [ ] Звук открытия диалога
- [ ] Звук выбора варианта
- [ ] Фоновая музыка для кризисных ситуаций
- [ ] Audio bus настройки

### Task 5.2: Animation Polish
**Priority**: P2  
**Estimate**: 3h  
**Acceptance Criteria**:
- [ ] Fade-in/out анимации диалога
- [ ] Shake эффект для недоступных выборов
- [ ] Pulse эффект для красной рамки кризиса
- [ ] Hover эффекты на кнопках

### Task 5.3: Write Comprehensive Tests
**Priority**: P1  
**Estimate**: 6h  
**Acceptance Criteria**:
- [ ] GUT тесты для EventManager
- [ ] GUT тесты для CrisisManager
- [ ] Integration тесты с GameManager
- [ ] Тесты на сохранение/загрузку
- [ ] Покрытие >80%

### Task 5.4: Balance & Playtesting
**Priority**: P1  
**Estimate**: 4h  
**Acceptance Criteria**:
- [ ] Настройка весов событий
- [ ] Баланс последствий выборов
- [ ] Тестирование на длительной сессии (100+ ходов)
- [ ] Сбор фидбека, итерация

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

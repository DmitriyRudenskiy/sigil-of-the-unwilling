# Specification: Event Manager System

## Overview
Система управления событиями, отвечающая за генерацию, планирование и выполнение событий в игре.

## Architecture
```
EventManager (Singleton)
├── event_queue: Array[Event]
├── active_events: Dictionary[event_id, Event]
├── event_history: Array[EventRecord]
├── difficulty_modifier: float
└── season_context: Season
```

## Core Components

### 1. Event Types
- **Common**: Рутинные события (торговец, находка ресурсов)
- **Rare**: Уникальные события (герой присоединяется, артефакт)
- **Crisis**: Критические события (эпидемия, нападение, пожар) - блокируют ход
- **Seasonal**: Сезонные события (урожай, зима, засуха)

### 2. Event Structure (GDScript Class)
```gdscript
class Event:
    var id: String
    var title: String
    var description: String
    var type: EventType  # COMMON, RARE, CRISIS, SEASONAL
    var weight: float  # Вероятность появления
    var conditions: Array[Condition]  # Требования для активации
    var choices: Array[Choice]  # Варианты решений
    var duration: int  # Длительность в ходах
    var icon: Texture2D
```

### 3. Choice Structure
```gdscript
class Choice:
    var text: String
    var requirements: Array[Requirement]
    var effects: Array[Effect]
    var law_unlock: String  # Открываемый закон (опционально)
```

### 4. Effect System
```gdscript
class Effect:
    var target: String  # "resources.gold", "population.happiness"
    var operation: String  # "add", "multiply", "set"
    var value: Variant
    var duration: int  # Для временных эффектов
```

## Methods

### `queue_event(event_template: EventTemplate)`
Добавляет событие в очередь на основе шаблона и контекста.

### `process_turn()`
Вызывается каждый ход:
- Проверяет активные события
- Обновляет таймеры
- Генерирует новые события (если нет активных кризисов)

### `resolve_crisis(event_id: String, choice_index: int)`
Обрабатывает выбор игрока в кризисном событии:
- Применяет эффекты
- Обновляет историю
- Снимает блокировку хода

### `get_available_events(context: Dictionary) -> Array[EventTemplate]`
Возвращает список доступных событий с учетом веса и условий.

## Data Flow
1. Turn Start → `process_turn()`
2. Check Active Events → Update Timers
3. If No Crisis → Generate New Event (Weighted Random)
4. If Crisis → Block Input, Show Dialog
5. Player Chooses → `resolve_crisis()` → Apply Effects → Unblock Input

## Integration Points
- **GameManager**: Вызывает `process_turn()` в начале хода
- **UIManager**: Отображает диалог события
- **SaveSystem**: Сохраняет `active_events` и `event_history`
- **DifficultySystem**: Модифицирует `weight` событий

## Error Handling
- Если событие не имеет допустимых выборов → авто-разрешение с негативным эффектом
- Если база событий пуста → логирование ошибки, пропуск генерации

## Performance Considerations
- Кэширование доступных событий на 5 ходов
- Lazy loading иконок событий
- Ограничение истории (последние 50 событий)

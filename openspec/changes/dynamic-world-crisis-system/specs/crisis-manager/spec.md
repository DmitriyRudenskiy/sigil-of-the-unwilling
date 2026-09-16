# Specification: Crisis Manager System

## Overview
Система управления кризисами, блокирующая игровой ход до принятия игроком решения.

## Core Concept
В отличие от обычных событий, кризисы требуют немедленного реагирования. Игра не может продолжиться, пока игрок не сделает выбор.

## Architecture
```
CrisisManager (Singleton)
├── active_crisis: Event (nullable)
├── crisis_queue: Array[Event]
├── is_crisis_active: bool
├── input_blocked: bool
└── crisis_stack: Array[Event]  # Для цепочек кризисов
```

## States
- **IDLE**: Нет активных кризисов, игра продолжается нормально
- **PENDING**: Кризис ожидает решения игрока, вход заблокирован
- **RESOLVING**: Применяются эффекты выбора
- **COOLDOWN**: Период после кризиса before новый может начаться

## Methods

### `trigger_crisis(event: Event)`
Инициирует кризис:
1. Устанавливает `is_crisis_active = true`
2. Блокирует ввод (`input_blocked = true`)
3. Сохраняет текущее состояние игры (для возможного отката)
4. Открывает UI диалога

### `block_input()`
Блокирует все игровые действия кроме:
- Взаимодействие с окном кризиса
- Просмотр справочной информации
- Кнопка "Пауза" (не заканчивает ход)

### `unblock_input()`
Разблокирует ввод после разрешения кризиса.

### `check_crisis_conditions() -> bool`
Проверяет, можно ли запустить новый кризис:
- Нет активного кризиса
- Прошел cooldown период
- Город соответствует требованиям (население > X, сезон Y)

### `escalate_crisis()`
Усложняет текущий кризис если игрок бездействует (таймер бездействия).

## Crisis Types (Frostpunk-inspired)

### 1. Resource Crisis
- **Example**: "Запасы еды критически малы"
- **Choices**: 
  - Урезать пайки (-happiness, +time)
  - Отправить охотников (-population risk, +food)
  - Использовать резервы (-future security)

### 2. Moral Crisis
- **Example**: "Группа жителей требует особых прав"
- **Choices**:
  - Согласиться (+happiness, -equality)
  - Отказать (-happiness, +order)
  - Принять новый закон (unlocks law tree)

### 3. Environmental Crisis
- **Example**: "Ледяная буря приближается"
- **Choices**:
  - Укрепить здания (-resources, +survival)
  - Эвакуировать часть населения (-population, -morale)
  - Рискнуть и остаться (chance-based outcome)

### 4. External Threat
- **Example**: "Наблюдатели заметили группу мародеров"
- **Choices**:
  - Подготовить оборону (-resources, +defense)
  - Попытаться договориться (diplomacy check)
  - Напасть первыми (combat encounter)

## Integration with Turn System
```gdscript
# In GameManager.end_turn()
if CrisisManager.is_crisis_active:
    return false  # Ход не заканчивается
else:
    process_normal_turn()
    return true
```

## Visual Feedback
- Красная пульсирующая рамка экрана
- Звуковое оповещение о кризисе
- Иконка кризиса в верхней панели
- Блокированная кнопка "Конец хода" (серая, с tooltip)

## Save/Load Considerations
- Сохранять состояние кризиса (active, choice_made, effects_applied)
- При загрузке во время кризиса: восстановить UI и блокировку

## Difficulty Scaling
- Легкий: Больше времени на решение, менее суровые последствия
- Средний: Стандартные параметры
- Сложный: Меньше времени, цепочки кризисов, суровые последствия
- Бесконечный (RimWorld-style): Кризисы становятся сложнее с каждым месяцем

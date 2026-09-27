# TASK 01 — Структуры данных динамических событий и кризисов

> Артефакт цикла `openspec/changes/dynamic-world-crisis-system` (Task 1.3). Источник истины в коде: `game/scripts/systems/crisis_event_system.gd`, `game/scripts/systems/law_manager.gd`, данные — `game/data/events/*.json`.

## 1. Типы событий (`crisis_event_system.gd`)

```gdscript
enum CrisisType {                        # 6 типов кризисов
    NATURAL_DISASTER,   # пожар, наводнение, землетрясение
    RESOURCE_SHORTAGE,  # нехватка еды, топлива, материалов
    SOCIAL_UNREST,      # бунты, забастовки, бегство жителей
    EXTERNAL_THREAT,    # нападение, рейдеры, монстры
    EPIDEMIC,           # болезни, эпидемии
    MAGICAL_ANOMALY     # магические катаклизмы
}
enum EventFrequency { VERY_RARE = 1, RARE = 2, UNCOMMON = 3, COMMON = 4, FREQUENT = 5 }
```

## 2. Модели данных

### DynamicEventData (обычное событие)
| Поле | Тип | Описание |
|---|---|---|
| id | String | уникальный ключ (`event_XX_name.json`) |
| title / description | String | текст для decision_panel |
| icon_path | String | путь к иконке (валидируется тестами) |
| type | EventType | тон события |
| triggers | Dictionary | условия запуска (ресурсы, мораль, сезон) |
| choices | Array[ChoiceData] | варианты решения |

### CrisisEventData (наследует структуру DynamicEventData)
Дополнительно: `severity` (вес сложности), `duration_days`, `passive_effects` (ежедневные мутации до разрешения). Кризис блокирует завершение хода (`GameManager.end_turn` → early-return при `is_crisis_active`).

### ChoiceData
| Поле | Тип | Описание |
|---|---|---|
| text | String | label кнопки |
| requirements | Dictionary | gating через `is_choice_available` (ресурсы/законы) |
| effects | Dictionary | разовые эффекты при выборе |
| ongoing_effects | Dictionary | модификаторы на N дней |

### Effect keys (wired pipeline — только эти ключи применяются к GameManager)
`wood_change`, `food_change`, `gold_change` (→ `modify_resource`), `population_change` (→ `modify_population`), `happiness_change` (→ `modify_global_morale`), `unlock_building`, `unlock_law`, `add_permanent_modifier`, `apply_production_modifier`. Мёртвые ключи (`mana_change`, `reputation_change`, `loyalty_change`, `population_drain`) удалены из всех JSON.

## 3. LawManager (`law_manager.gd`)
- 3 ветки: **Order / Faith / Survival**, по 2 закона на ветку (всего 6).
- `requires`: prerequisite-закон (дерево разблокировок).
- `get_passive_effects()`: merged modifiers по key от всех принятых законов.
- Сериализация: `to_dict()/from_dict()`.

## 4. Формат JSON (пример схемы)
```json
{
  "id": "crisis_01_fire",
  "type": "fire",
  "title": "...", "description": "...",
  "icon": "res://.../crisis_fire.png",
  "choices": [
    { "text": "...", "requirements": {"gold": 20},
      "effects": {"gold_change": -20, "happiness_change": 5},
      "ongoing_effects": {"key": "production", "value": 0.1, "days": 3} }
  ]
}
```

## 5. Save/Load
`CrisisEventSystem.serialize_state()` → `{current_crisis_id, active_event_ids, day, next_event_day, last_crisis_day, event_history, law}`; ключ сохранения — `crisis_state` (null-guarded в GameManager). Неизвестные id пропускаются безопасно; пустой dict = no-op.

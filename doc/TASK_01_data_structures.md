# TASK_01 — Структуры данных системы событий и кризисов

Описание данных динамики мира (обычные события + кризисы). Реализация:
`game/scripts/systems/crisis_event_system.gd` (класс `CrisisEventSystem`,
инстанцируется `GameManager`, не autoload). Тесты структуры:
`game/tests/unit/systems/test_crisis_events.gd`.

Все классы читают JSON через безопасные конвертеры (`_as_int/_as_float/
_as_string/_as_dict/_as_array/_as_event_type`) — JSON отдаёт числа как
`float`, без приведения присваивание в `var severity: int` падает в рантайме.

## Enums

| Enum | Значения | Назначение |
| --- | --- | --- |
| `CrisisType` | NATURAL_DISASTER, RESOURCE_SHORTAGE, SOCIAL_UNREST, EXTERNAL_THREAT, EPIDEMIC, MAGICAL_ANOMALY | 6 типов кризисов (все покрыты шаблонами) |
| `EventFrequency` | VERY_RARE(1)..FREQUENT(5) | Частота (информационная; на доступность не влияет) |
| `EventType` | COMMON, RARE, SEASONAL | Категория события (spec: Common/Rare/Seasonal). Редкость на практике задаёт `weight` |
| `ChoiceImpact` | POSITIVE_MAJOR..NEGATIVE_MAJOR | Подсветка выбора в UI (не влияет на логику) |

`EventType` из JSON: `_as_event_type` принимает `int` (enum-значение) или
имя `"rare"/"seasonal"/"common"`. Неизвестное/отсутствующее → `COMMON`
(backward-compat со старыми `event_*.json` без поля `type`).

## Данные

### `ChoiceData` — выбор в событии/кризисе
| Поле | JSON-ключ | Тип |
| --- | --- | --- |
| `text` | `text` | String |
| `tooltip` | `tooltip` | String |
| `impact` | `impact` | ChoiceImpact (int) |
| `effects` | `effects` | Dictionary (см. «Эффекты») |
| `requirements` | `requirements` | Dictionary (условия доступности) |

### `DynamicEventData` — обычное/редкое/сезонное событие
| Поле | JSON-ключ | Тип | Примечание |
| --- | --- | --- | --- |
| `id` | `id` | String | уникален |
| `title` / `description` | `title` / `description` | String | |
| `icon_path` | `icon_path` | String | `res://assets/ui/events/*.png` |
| `frequency` | `frequency` | EventFrequency | |
| `min_day` | `min_day` | int | доступен с N-го дня |
| `triggers` | `triggers` | Dictionary | см. «Триггеры» |
| `choices` | `choices` | Array[ChoiceData] | |
| `weight` | `weight` | float | шанс выбора в `try_trigger_event`; редкие < 1.0 |
| `type` | `type` | EventType | категория (default COMMON) |

### `CrisisEventData` — кризис (отдельный класс)
Все поля `DynamicEventData` (кроме `weight`/`type`) + :
| Поле | JSON-ключ | Тип | Примечание |
| --- | --- | --- | --- |
| `crisis_type` | `crisis_type` | CrisisType (int) | |
| `severity` | `severity` | int 1..5 | масштаб |
| `duration_days` | `duration_days` | int ≥1 | длительность |
| `ongoing_effects` | `ongoing_effects` | Dictionary | эффекты каждый ход пока активен |
| `resolution_effects` | `resolution_effects` | Dictionary | эффекты при завершении |

## Эффекты (только WIRED — применяются в `apply_choice_effects`)

| Ключ | Формат | Действие |
| --- | --- | --- |
| `resource_change` | `{"<res>": <delta>}` | ± ресурс через GameManager |
| `morale_change` | `{"amount": <delta>}` | ± мораль |
| `population_change` | `{"amount": <delta>}` | ± население |
| `unlock_building` | `{"id": "<building_id>"}` | разблокировать здание (id из `buildings.json`) |
| `permanent_modifier` | `{"id": "...", "effect": {"<stat>": <mult>}}` | постоянный модификатор |
| `unlock_law` | `{"id": "<law_id>"}` | разблокировать закон (id из `LawManager.gd`) |

Прочие ключи игнорируются (безопасно). Новые эффекты добавляются только
вместе с обработчиком в `apply_choice_effects` + тестом.

## Триггеры (`_check_triggers`)

| Ключ | Формат | Смысл |
| --- | --- | --- |
| `population_min` | `{"population_min": <n>}` | население ≥ n |
| `resource_low` | `{"resource_low": {"<res>": <n>}}` | ресурс < n |
| `building_required` | `{"building_required": "<id>"}` | здание построено |

Все перечисленные условия должны выполняться (AND).

## Сложность и шанс кризиса

- `difficulty` 1..5 (default 3). `get_crisis_difficulty_modifier() =
  clampf(1.0 + (difficulty - 3) * 0.25, 0.25, 2.0)` → easy(1)=0.5,
  normal(3)=1.0, hard(5)=1.5.
- `get_crisis_chance() = (base_event_chance + day_counter / 100.0) *
  get_crisis_difficulty_modifier()`. `should_trigger_crisis() =
  randf() < get_crisis_chance()`.
- При `difficulty=3` поведение совпадает с исходным (модификатор 1.0).

## Сохранение (`serialize_state` / `deserialize_state`)

Сериализуется: `day_counter`, `next_event_day`, `last_crisis_day`,
`difficulty`, `active_events` (по id), `current_crisis` (по id + день
начала), `event_history` (список `{type, id, day, choice}`) и `resolved`
(список id). При загрузке неизвестные id пропускаются.

## Файлы данных — `game/data/events/`

- `event_*.json` — обычные события (10), `type` отсутствует → COMMON.
- `rare_*.json` — редкие события (5), `"type": "rare"`, `weight < 1.0`.
- `crisis_*.json` — кризисы (8, покрывают все 6 `CrisisType`).
- `events_database.json` — служебный, в счётчик шаблонов не входит.

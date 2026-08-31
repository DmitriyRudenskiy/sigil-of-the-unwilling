# Система заклинаний

## Обзор

`data/spells.json` — единый источник данных для всех заклинаний в игре. Файл содержит 505 заклинаний, распределённых по 16 шаблонам и 6 цветам/фракциям.

```
data/spells.json         ← JSON-массив всех заклинаний (505 записей)
data/spells.schema.json  ← JSON Schema валидации
tools/spell_validation/        ← Ядро валидатора (GDScript)
tests/test_spells_json.gd ← 33 интеграционных теста
tests/test_validation_runner.gd ← Standalone-раннер для тестов
```

---

## Формат записи

Каждое заклинание — JSON-объект с фиксированной структурой:

```json
{
  "id": "fireball",
  "name": "Fireball",
  "template": "DIRECT_DAMAGE",
  "speed": "fast",
  "cost": 2,
  "color": "fire",
  "params": { "amount": 2, "target": "ENEMY_UNIT" },
  "description": "Deal 2 damage to an enemy unit."
}
```

### Обязательные поля

| Поле | Тип | Описание |
|------|-----|----------|
| `id` | `string` | Уникальный идентификатор (`snake_case`, `^[a-z][a-z0-9_]*$`) |
| `name` | `string` | Отображаемое имя (макс. 40 символов) |
| `template` | `string` | Шаблон заклинания (один из 16) |
| `speed` | `string` | Скорость: `fast`, `slow`, `burst` |
| `cost` | `int` | Стоимость маны (0–10) |
| `color` | `string` | Цвет/фракция: `fire`, `time`, `justice`, `primal`, `shadow`, `multifaction`, `colorless` |
| `params` | `object` | Параметры, специфичные для шаблона |
| `description` | `string` | Описание (макс. 200 символов) |

### Опциональные поля

| Поле | Тип | Описание |
|------|-----|----------|
| `secondary_effects` | `Array` | Дополнительные эффекты: `DRAW`, `DEAL_DAMAGE`, `HEAL_NEXUS`, `APPLY_STATUS` |
| `condition` | `object` | Условие применения (см. ниже) |
| `target` | `string` | Целевой параметр (см. ниже) |

### Цели (targets)

`NONE`, `ALLY_UNIT`, `ENEMY_UNIT`, `ANY_UNIT`, `ALLY_NEXUS`, `ENEMY_NEXUS`, `ANY_NEXUS`, `ENEMY_SPELL`, `ENEMY_RELIC`, `ALL_ENEMY_UNITS`, `ALL_ALLY_UNITS`, `TWO_ALLY_UNITS`, `ALLY_UNIT_IN_HAND`, `ALLY_UNIT_IN_GRAVE`, `SELF`, `SAME_AS_PREVIOUS`.

### Условия (conditions)

`target_hp_max`, `target_cost_max`, `target_is_damaged`, `target_is_flying`, `hand_size_max`, `spell_cost_max`, `attacker_unblocked`, `discard_cost`, `min_ally_count`.

### Статусы/ключевые слова

`SILENCE`, `FROZEN`, `STUN`, `QUICKDRAW`, `UNBLOCKABLE`, `OVERWHELM`, `ARMORED`, `WARD`, `CHALLENGE`, `CANNOT_BLOCK`, `CANNOT_ATTACK`, `FLYING`.

---

## Шаблоны (16 типов)

| Шаблон | Кол-во | Обязательные params | Описание |
|--------|--------|---------------------|----------|
| `DIRECT_DAMAGE` | 73 | `amount`, `target` | Прямой урон |
| `HARD_REMOVAL` | 32 | — | Уничтожение юнитов |
| `COMBAT_TRICK` | 96 | — | Тактические приёмы боя |
| `DEBUFF_CONTROL` | 76 | — | Даббафы и контроль |
| `SPELL_DRAW` | 93 | `count` | Поиск заклинаний |
| `TOKEN_GENERATION` | 27 | `token_id`, `count` | Призыв токенов |
| `CHOICE_CYCLE` | 19 | `draw` | Выбор эффекта |
| `BOUNCE` | 18 | `target` | Возврат на руку |
| `COUNTERMAGIC` | 11 | — | Контрзаклинания |
| `DISPLAY_CYCLE` | 15 | — | Отображение/цикл |
| `RELIC_INTERACTION` | 9 | `action` (`destroy`, `steal`) | Взаимодействие с реликвиями |
| `KEYWORD_BUFF` | 14 | `keyword` | Придание ключевого слова |
| `MANA_RAMP` | 6 | `power` | Увеличение маны |
| `DISPEL_DRAW` | 6 | `discard`, `draw` | Сброс → поиск |
| `MARKET_NICHE` | 6 | `action` | Рыночные механики |
| `TOUCH_CYCLE` | 4 | `atk`, `hp` | Призыв 1/1 |

---

## Распределение по цветам

| Цвет | Заклинаний | Процент |
|------|------|---------|
| `shadow` | 124 | 24.6% |
| `primal` | 118 | 23.4% |
| `fire` | 97 | 19.2% |
| `time` | 75 | 14.9% |
| `justice` | 90 | 17.8% |
| `colorless` | 1 | 0.2% |

## Распределение по стоимости

| Стоимость | Заклинаний | Процент |
|-----------|------|---------|
| 1 | 36 | 7.1% |
| 2 | 218 | 43.2% |
| 3 | 155 | 30.7% |
| 4 | 54 | 10.7% |
| 5 | 27 | 5.3% |
| 6 | 10 | 2.0% |
| 7 | 4 | 0.8% |
| 8 | 1 | 0.2% |

Средняя стоимость: **2.74**

## Распределение по скорости

| Скорость | Заклинаний | Процент |
|----------|------|---------|
| `fast` | 441 | 87.3% |
| `slow` | 64 | 12.7% |

---

## Валидатор

Ядро валидатора — `SpellValidator.gd` — проверяет данные на 7 уровнях:

### Уровень 0: Файл и парсинг (`E0xx`)

| Код | Описание |
|-----|----------|
| `E001` | Файл не найден |
| `E002` | Не удалось открыть файл |
| `E010` | Ошибка парсинга JSON |

### Уровень 1: Структура (`E1xx`)

| Код | Описание |
|-----|----------|
| `E100` | Не массив |
| `E101` | Элемент не объект |
| `E102` | Пустой массив |
| `E103` | Отсутствует поле |
| `E104` | Лишнее поле |
| `E105` | Обязательный параметр шаблона |

### Уровень 2: Типы данных (`E2xx`)

| Код | Описание |
|-----|----------|
| `E200` | Неправильный тип поля |
| `E201` | `params` не объект |
| `E202` | `secondary_effects` не массив |
| `E203` | `condition` не объект |

### Уровень 3: Допустимые значения (`E3xx`)

| Код | Описание |
|-----|----------|
| `E300` | ID не соответствует regex |
| `E301` | Имя слишком длинное |
| `E302` | Неизвестный шаблон |
| `E303` | Неизвестный цвет |
| `E304` | Стоимость вне диапазона |
| `E310` | Урон вне диапазона |
| `E311` | Изменение стата вне диапазона |
| `E320` | Неизвестная цель |
| `E321` | Неизвестный статус/ключевое слово |
| `E322` | Неизвестный вторичный эффект |
| `E323` | Неизвестное условие |
| `E324` | Неизвестное action |

### Уровень 4: Семантика шаблонов (`E4xx`)

| Код | Описание |
|-----|----------|
| `E400` | Обязательный параметр шаблона отсутствует |
| `E401` | `DIRECT_DAMAGE` без `amount` |
| `E402` | `TOKEN_GENERATION` без `token_id` |
| `E410` | `TOKEN_GENERATION` с неизвестным `token_id` |

### Уровень 5: Целостность (`E5xx`)

| Код | Описание |
|-----|----------|
| `E500` | Дубликат ID |
| `E501` | Дубликат имени |

### Уровень 6: Баланс (`W9xx`)

| Код | Описание |
|-----|----------|
| `W901` | Дубликат отображаемого имени |
| `W910` | `HARD_REMOVAL` без условия (безусловное уничтожение) |
| `W920` | Общее количество ≠ 420 |
| `W921` | Расхождение по шаблону |
| `W922` | Дисбаланс цветов |
| `W923` | Дисбаланс стоимости |
| `W924` | Дисбаланс скорости |

### Уровень 7: Кросс-валидация (`E7xx`)

| Код | Описание |
|-----|----------|
| `E700` | Ссылка на несуществующий `token_id` |
| `E701` | Ссылка на несуществующий `unit_id` |

---

## Использование

### CLI

```bash
# Базовая валидация
godot --headless -s tools/spell_validation/validate_spells.gd data/spells.json 2>/dev/null

# Строгий режим (warnings = errors)
godot --headless -s tools/spell_validation/validate_spells.gd --strict data/spells.json 2>/dev/null

# JSON-выход
godot --headless -s tools/spell_validation/validate_spells.gd --json data/spells.json 2>/dev/null

# Сохранение отчёта
godot --headless -s tools/spell_validation/validate_spells.gd --out report.json data/spells.json 2>/dev/null

# Тихий режим (только ошибки)
godot --headless -s tools/spell_validation/validate_spells.gd --quiet data/spells.json 2>/dev/null
```

### API (GDScript)

```gdscript
const Validator = preload("res://tools/spell_validation/SpellValidator.gd")

var validator = Validator.new()
var passed = validator.validate_file("res://data/spells.json")

# Получить отчёт
print(validator.report.to_text())
print(validator.report.to_json())

# Фильтрация
var errors = validator.report.filter("ERROR")
var warnings = validator.report.filter("WARNING")

# Статистика
print(validator.report.stats)
```

### Тесты

```bash
# Запуск тестов (standalone, без autoload-конфликтов)
godot --headless -s tests/test_validation_runner.gd 2>/dev/null
```

---

## Архитектура валидатора

```
validate_spells.gd   (72  строк)  ← CLI-обёртка
SpellValidator.gd     (651 строк)  ← Ядро валидатора
ValidationReport.gd       (132 строки) ← Сборщик ошибок / отчётов
spells.schema.json   (445 строк)  ← JSON Schema
```

- **ValidationReport** — собирает `Issue` (код, сообщение, severity, spell_id), генерирует текстовый и JSON-отчёт с фильтрацией по severity.
- **SpellValidator** — 7 уровней проверки, справочники (источник истины для enum-значений), диапазоны, распределение по шаблонам.
- **validate_spells.gd** — CLI с парсингом аргументов и поддержкой `--strict`, `--json`, `--quiet`, `--out`.

---

## Известные предупреждения (31 шт.)

| Код | Кол-во | Описание |
|-----|--------|----------|
| `W910` | 19 | `HARD_REMOVAL` без условия — по дизайну |
| `W901` | 1 | Дубликат имени: «Fireball» |
| `W920` | 1 | 505 вместо 420 (+85 заклинаний) |
| `W921` | 8 | Расхождения по шаблонам |
| `W922` | 1 | `multifaction` = 0 заклинаний |
| `W924` | 1 | 87% fast-спеллов |

Все предупреждения informational — они отражают текущее состояние колоды и не являются ошибками.

---

## Изменение данных

1. Отредактируйте `data/spells.json`
2. Запустите валидатор:
   ```bash
   godot --headless -s tools/spell_validation/validate_spells.gd --strict data/spells.json 2>/dev/null
   ```
3. Убедитесь, что ошибок `E0xx–E7xx` нет
4. Предупреждения `W9xx` — информационные, игнорируются в не-строгом режиме

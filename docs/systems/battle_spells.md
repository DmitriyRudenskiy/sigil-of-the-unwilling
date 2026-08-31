# Боевые заклинания → быстрая архитектура

Конвертация 20 обычных боевых заклинаний (`SpellRegistry`) в быструю
«быструю» архитектуру (`SpellDef`) и их применение в бою как обычных
заклинаний.

## 1. Зачем нужно

В проекте две системы описания эффектов:

- **Боевая** (`game/data/SpellRegistry.gd`, автозагрузка `Spells`) — 20
  обычных боевых заклинаний. Каждое — `SpellRegistry.SpellDef` с
  `damage_multiplier` (множитель урона) и `buff_effect` (эффект статуса,
  `-1` если нет). Применяется через `SpellCaster.cast`.
- **Система заклинаний** (`game/data/`, автозагрузка `Spellbook`) — 505 заклинаний из
  `spells.json`. Каждая — `SpellDef` с шаблоном (16 вариантов) и
  параметрами (`params`). Применяется через `SpellResolver.resolve`.

Мост — `game/data/BattleSpellBridge.gd` (`class_name BattleSpellBridge`):

1. **`to_spell()`** — боевое заклинание как быстрое:
   `speed = FAST`, шаблон/параметры из категории, `cost = base_mana`.
2. **`apply_spell()`** — применение заклинания в контексте боя на
   `BattleUnit` (урон/статус/лечение/воскрешение), повторяя форму
   результата `SpellCaster.cast`.

## 2. Маппинг боевое → заклинание

| Категория | Условие | Шаблон | `params` |
|---|---|---|---|
| Урон | `damage_multiplier > 0` | `DIRECT_DAMAGE` | `{amount: mult, target, level}` |
| Бафф | `buff_effect >= 0`, не дебаф | `KEYWORD_BUFF` | `{keyword, mass?, level}` |
| Дебаф | `buff_effect >= 0`, дебаф | `DEBUFF_CONTROL` | `{keyword, mass?, level}` |
| Лечение | `cure` | `HEAL_CLEAR` | `{level}` |
| Воскрешение | `resurrection` | `REVIVE` | `{level}` |
| Спец (no-op) | `town_portal` | `PORTAL` | `{level}` |

- `amount` = `damage_multiplier` (урон = `SP × amount`).
- `target` = `ENEMY_UNIT` (magic_arrow, lightning_bolt) или
  `ALL_ENEMY_UNITS` (fireball, armageddon, meteor_shower).
- `keyword` = верхний регистр имени эффекта (`HASTE`, `CURSE`, …).
- `mass = true` только для `slow_mass`.
- `level` несем в `params`, чтобы в `apply_spell` проверять иммунность
  драконов (иммунитет к заклинаниям < 4 уровня).

Школа мапинится в цвет: `Air→time`, `Fire→fire`, `Water→primal`,
`Earth→primal`.

## 3. Применение в бою: `apply_spell()`

Форма результата повторяет `SpellCaster.cast` — словарь:
`result, damage, kills, status, resisted, heal, revive_count, spell_id`.

- **Урон** (`DIRECT_DAMAGE`): `_check_immunity` → `_calc_resistance` →
  `_apply_damage`. `damage = SP × amount`, `kills = min(1 + dmg/hp, count)`.
- **Бафф** (`KEYWORD_BUFF`): `add_status(KEYWORD_TO_EFFECT[keyword], 3)`,
  `status = effect`.
- **Дебаф** (`DEBUFF_CONTROL`): как бафф + `mass` (длительность 4 и,
  при массовом, на юнит-мастер).
- **Лечение** (`HEAL_CLEAR`): `clear_debuffs()`, `heal = SP × 10`.
- **Воскрешение** (`REVIVE`): если юнит мертв, revive `min(1 + SP*20/hp, max_count)`.
- **Спец** (`PORTAL`): no-op → `result = "success"`.

Иммунитет/стойкость (в `_check_immunity` / `_calc_resistance`):
- undead immune к `bless/cure/curse/weakness/slow`;
- dragons immune к заклинаниям < 4 уровня;
- mind_immune immune к `curse/misfortune/weakness/slow`;
- magic_resistant: +40% шанс сопротивления.

Маппинг эффект → статус — `KEYWORD_TO_EFFECT` (`BattleSpellBridge`),
переводит `KEYWORD` в `StatusEffects.Effect` (внутриигровая
система статусов отличается от системы `StatusType`).

## 4. Интеграция с сокет-сервером

`game/core/SocketController.gd`:

- **`BATTLE_SPELL`** — `{"spell_id", "tags", "hp", "count", "resistant"}`.
  Строит `BattleUnit`, вызывает `BattleSpellBridge.to_spell` + `apply_spell`,
  регистрирует заклинание в `SpellbookRegistry.register()`. Возвращает
  `{"spell": to_dict(), "apply": {...}, "registered": bool}`.
- **`SPELL_REGISTRY`** — `{"count", "template_count"}` (для интеграции).

Синтетический юнит строится как в `_cast_spell`:
`UnitStats.new(id, name, 3, 2, hp, 4, 5, tags)` → `UnitStack.new(stack, count)`
→ `BattleState.BattleUnit.new(stack)`, `max_count = max(count, 10)`.

## 5. Тесты (`scenario_7_battle_spells.py`)

Запуск: `./game/tools/shell/play_scenario.sh 7`. 52 проверки, 3 раздела:

1. **Spellify** — все 20 заклинаний: `speed=fast`, шаблон по категории,
   `cost=base_mana`, `params` осмысленны.
2. **Apply in battle** — урон (8×mult, kills≥1), бафф/дебаф (status≥0),
   лечение (heal), воскрешение (revive_count≥1, юнит мертв),
   town_portal (no-op), иммунность (драконы/undead/mind_immune),
   magic_resistant, unknown → `not_found`.
3. **Integration** — после конвертации `SpellbookRegistry.get_count() ≥ 525`
   (505 + ≥20 новых).

## 6. Латентные заметки

- `cure` имеет `buff_effect=BLESS`, поэтому в `SpellCaster.cast` он уходит
  в бафф-ветку; ветка лечения (`elif spell_id == &"cure"`) фактически
  недостижима — `cure` **не лечит HP** в текущем коде. В мосте
  `apply_spell` лечение реализовано явно (лечит через HEAL_CLEAR).
- `BattleSpellBridge` — параллельный путь конвертации; `SpellCaster.cast`
  используется в основном боевом коде и не изменён.
- `get_name()` в `StatusEffects` не вызываем — он конфликтует со
  встроенным `Object.get_name()` (0 аргументов). Ключ эффекта берём из
  обратного маппинга `_EFFECT_TO_KEYWORD`.

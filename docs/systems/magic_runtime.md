# Магия: исполнение заклинаний (runtime)

Этот документ описывает, **как заклинание применяется в момент каста** —
цепочку «валидация → оплата → диспетчеризация → эффект».

Данные заклинаний и их валидация описаны отдельно:
- [`spells_system.md`](spells_system.md) — `spells.json`, 16 шаблонов, цвета, валидатор.
- [`battle_spells.md`](battle_spells.md) — конвертация 20 боевых заклинаний в быструю систему (`BattleSpellBridge`) и их тестирование.

Здесь — связующее звено: как эти данные выполняются в бою и на карте.

## Общая картина

В проекте **две модели описания** эффектов:

| Модель | Класс данных | Применение |
| --- | --- | --- |
| Карточная («быстрая») | `scripts/data/SpellbookDef.gd` (`template` + `params`) | `scripts/data/SpellResolver.gd` → `scripts/data/TemplateEngine.gd` |
| Боевая (20 заклинаний) | `scripts/autoload/SpellRegistry.gd` (`SpellDef`, `damage_multiplier` / `buff_effect`) | `scripts/systems/SpellCaster.gd` ( бой) + `scripts/data/BattleSpellBridge.gd` (мост в карточную) |

Источник карт — `assets/data/spells.json` (~505 записей), загружается
`SpellbookRegistry` (autoload `Spellbook`). Источник боевых —
`SpellRegistry` (autoload `Spells`), 20 заклинаний по 4 школам.

## 1. Точка входа: `SpellResolver.resolve`

`scripts/data/SpellResolver.gd` (`class_name SpellResolver`, `RefCounted`) — фасад
выполнения карточного заклинания. Статический `resolve(spell, state, caster, target)`:

1. **Валидация** — `spell != null` и `spell.template` не пуст. Иначе `invalid_spell` / `no_template`.
2. **Оплата маны** — если у `caster` есть `current_power`, проверяет `current_power >= spell.cost`, списывает.
3. **Проверка `influence_req`** — для каждого цвета в `spell.influence_req` проверяет требуемое влияние (`get_influence` / атрибут `influence`).
4. **Диспетчеризация в шаблон** — `TemplateEngine.execute(template, params, condition, secondary, state, caster, target)`.
5. **Логирование** — при `result == "success"` вызывает `state.add_to_history(...)` (если есть метод).

Возвращает `{"result", "effects"}`.

> Рефлексивные вызовы (`has_method` / `has_attr`) везде идут через
> `SpellUtils` (`has_obj_method` / `has_attr` / `get_id`): нативный
> `Object.has_method` занят под другое, а `get_id` унифицирует id объектов.

## 2. Исполнение шаблонов: `TemplateEngine`

`scripts/data/TemplateEngine.gd` (`RefCounted`) — **Strategy pattern**:
`template_id → Callable`. Обработчики регистрируются в `_handlers` на старте
(`register_handler`), новые шаблоны добавляются без правки движка.

`execute()` делает:
1. Проверку глобального условия (`_check_condition`).
2. Поиск обработчика по `template` (иначе `unknown_template`).
3. Вызов: для `COMBAT_TRICK` передаётся массив `secondary`, для остальных — без него.

**16 шаблонов** (см. также [`spells_system.md`](spells_system.md#шаблоны-16-типов)):
`DIRECT_DAMAGE`, `HARD_REMOVAL`, `BOUNCE`, `COUNTERMAGIC`, `COMBAT_TRICK`
(единственный с `secondary`), `DEBUFF_CONTROL`, `SPELL_DRAW`, `MANA_RAMP`,
`TOKEN_GENERATION`, `RELIC_INTERACTION`, `KEYWORD_BUFF`, `CHOICE_CYCLE`,
`TOUCH_CYCLE`, `DISPLAY_CYCLE`, `DISPEL_DRAW`, `MARKET_NICHE`.

Каждый обработчик применяет эффекты через отражение на `state`/`caster`/`target`
(`take_damage`, `add_status`, `destroy`, `return_to_hand`, `draw_cards`,
`create_token`, `modify_temp_stats` и т.д.) и собирает массив `effects`.
Параметры поддерживают «динамические» значения (`ally_count`, `enemy_count`,
`hand_size`) — размер эффекта вычисляется по доске/руке в момент каста.

## 3. Боевой путь: `SpellCaster.cast`

`scripts/systems/SpellCaster.gd` (`RefCounted`) — применение боевого заклинания
(`SpellRegistry.SpellDef`) к `BattleState.BattleUnit`. Статический `cast(
spell_id, target_unit, caster_hero_bonus, target_hero_bonus, rng, registry)`:

1. Резолвит_spell_ через `ServiceLocator.resolve(registry, "spells")`.
2. Проверки: существование, валидность цели, живость (кроме `resurrection`).
3. **Иммунитет** (`_check_immunity`) — нежить иммунна к `bless/cure/curse/weakness/slow`;
   драконы иммунны к заклинаниям < 4 уровня; `immune_mind` — к ментальным дебаффам.
4. **Сопротивление** (`_calc_resistance`) — `0.05 × knowledge`, +40% у
   `magic_resistant`, затеснено до 0.9.
5. **Эффект** по типу заклинания:
   - `damage_multiplier > 0` → урон `SP × mult` (×0.5 при сопротивлении), `kills = min(1 + dmg/hp, count)`.
   - `buff_effect >= 0` → `add_status(effect, 3)`.
   - `cure` → `clear_debuffs()`, `heal = SP × 10`.
   - `slow_mass` → `SLOW` на 4 хода.
   - `resurrection` → воскрешение `min(1 + SP*20/hp, max_count)`.

Форма результата: `{result, damage, kills, status, resisted, heal, revive_count, spell_id}`.

## 4. Мост в быструю систему: `BattleSpellBridge`

Превращает боевое заклинание в карточное (`to_spell`) и применяет его
(`apply_spell`). Это подробно покрыто в [`battle_spells.md`](battle_spells.md) —
см. разделы «Маппинг боевое → заклинание» и «Применение в бою». Кратко:
`speed = FAST`, шаблон выводится из категории (`DIRECT_DAMAGE` / `KEYWORD_BUFF` /
`DEBUFF_CONTROL` / `HEAL_CLEAR` / `REVIVE` / `PORTAL`), `cost = base_mana`,
школа → цвет (`Air→time`, `Fire→fire`, `Water→primal`, `Earth→primal`).
`apply_spell` повторяет форму результата `SpellCaster.cast`.

## 5. Свитки: `ScrollRules`

`scripts/data/ScrollRules.gd` — правила подбора и каста свитков:
- `can_pickup` — всегда `true`.
- `apply_pickup` — **обучение при подборе** (`hero.learn`), если заклинание ещё не известно.
- `can_cast_in_battle` — только если свиток ещё не израсходован (`scroll_remaining > 0`) и `hero.can_cast`.
- Свитки расходуются при касте (учёт снаружи через `scroll_remaining`).

## 6. Связь с героем: `HeroMagic`

`scripts/entities/HeroMagic.gd` хранит ману, школы и `spellbook` (`Array[StringName]`),
даёт `knows/learn/forget/can_cast/get_mana_cost/spend_mana`. Он не вызывает
`SpellResolver`/`SpellCaster` напрямую — фасад `HeroController` и боевой код
берут определение из `SpellRegistry` / `SpellbookRegistry` и прогоняют их через
соответствующий путь (боёк → `SpellCaster`/`BattleSpellBridge`, карта →
`SpellResolver` → `TemplateEngine`). Подробнее — в [`hero_system.md`](hero_system.md#магия-heromagic).

## 7. Интеграция: `SocketController`

Точки входа для headless-тестирования и клиента:

| Action | Что делает |
| --- | --- |
| `GET_SPELLS` | Список 20 боевых заклинаний из `SpellRegistry`. |
| `CAST_SPELL` | Каст по синтетическому юниту, результат `SpellCaster` (изоляция, без живого боя). |
| `BATTLE_SPELL` | `BattleSpellBridge.to_spell` + `apply_spell`, регистрация в `SpellbookRegistry`. |
| `SPELL_REGISTRY` | Состояние карточной системы: `count`, `template_count`. |

Синтетический юнит строится как в `_cast_spell`: `UnitStats.new(...)` →
`UnitStack.new(...)` → `BattleState.BattleUnit.new(...)`, `max_count = maxi(count, 10)`.

## 8. Тесты

- `game/tests/test_spell_system.gd` — `SpellResolver` (валидация, оплата, шаблоны).
- `game/tests/test_magic_resistance.gd` — `SpellCaster` (иммунитет/сопротивление/урон/лечение).
- `game/tests/test_spells_json.gd` — 33 интеграционных теста `spells.json`.
- Сценарий 7 (`play_scenario.sh 7`) — 52 проверки маппинга и применения в бою.

## Известные особенности

- `cure` имеет `buff_effect=BLESS`, поэтому в `SpellCaster.cast` он уходит в
  бафф-ветку; ветка лечения (`elif spell_id == &"cure"`) фактически недоступна —
  `cure` **не лечит HP** в этом пути (лечит только мост `BattleSpellBridge`).
- `BattleSpellBridge` — параллельный путь конвертации; `SpellCaster.cast`
  используется в основном боевом коде и не изменён.
- Маппинг `StatusEffects.Effect ↔ KEYWORD` живёт в `BattleSpellBridge`
  (`KEYWORD_TO_EFFECT`): внутриигровая система статусов отличается от
  `SpellEnums.StatusType`.

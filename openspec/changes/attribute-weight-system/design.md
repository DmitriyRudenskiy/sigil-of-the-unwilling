# Design: attribute-weight-system

## Context

- У героя 4 характеристики из `HeroBuildProfile.get_stats()`: `attack`,
  `defense`, `spell_power`, `knowledge` (рааса/класс/культура/бэкграунд дают
  бонусы). Они живут в `HeroStatsComponent.stats` и используются только в бою
  (`get_battle_bonus`).
- Рюкзак — `HeroStrategicResources`: счётный общий лимит
  `GameNumbersHero.BACKPACK_TOTAL_CAP = 12` + `capacity_bonus` (рыночная
  телега, +в единиц). Ресурсы добавляются через `add(id, amount)`.
- `ResourceDef.weight_per_unit: float` **уже существует** (дефолт 1.0) и
  заполняется в `ResourceRegistry._add(...)`, но никуда не применяется.
- Добыча: `WorldController.try_extract_resource` → `ResourceChainService.
  try_extract` (собирает extraction keys: skills, tools, tags) →
  `ResourceNodeManager.try_extract` — улов `node.get_yield()` без учёта
  характеристик. REST-спад при добыче не существует — сбор «бесплатен».
- Экипировка: `Artifact` (Resource) со слотами и `modifiers`, веса нет;
  `HeroInventoryComponent.get_total_modifiers()` → `get_battle_bonus`.
  Движение: `HeroMovementComponent`, `max_move_points =
  GameNumbers.HERO_DAILY_MOVEMENT` (постоянное).
- Геймплейная рамка: balance-core гарантирует — герой без города живёт
  ~100 ходов от needs, MCP-проба (60 ходов, RUNNING) не должна ломаться.

## Goals / Non-Goals

**Goals:**
- Мирные действия масштабируются от attack (рубка/добыча) и knowledge
  (улов, редкие узлы).
- Вес у всех материалов и артефактов; рюкзак — весовой cap от defense.
- Тяжёлая экипировка → штраф к MP/REST, а не запрет (ассасин в латах).
- Баланс-проба остаётся зелёной (60 ходов RUNNING).

**Non-Goals:**
- Новая система характеристик (не добавляем «силу/выносливость/
  внимательность» как отдельные статы — маппим на attack/defense/knowledge).
- Классовые запреты экипировки (явно не делаем).
- Торговля по весу, доставка телегой как отдельный юнит, UI-перестройка.

## Decisions

### D1. Маппинг на существующие боевые статы, а не новые мирные характеристики
Сила → `attack`, выносливость → `defense`, внимательность → `knowledge`.

> **Поправка (social-stats-weapon-tech):** в рамках сестринского change
> добавляются 4 *социальных* стата (int/wis/cha/luk) — они используются
> мирными системами (обман, население, найм, ковка). Настоящее решение
> остаётся верным: для **физических** действий (рубка, переноска, сбор)
> новых статов не вводится — используются боевые attack/defense/knowledge.
- Почему: классы/расы уже распределяют эти статы (варвар attack+2,
  друид/маг knowledge+1/spell_power+2, паладин defense+2) — ролевой
  отыгрыш «встроен» бесплатно, без новой таблицы бонусов и нового UI.
- Альтернатива: три новых стата `strength/endurance/attention`. Отклонено:
  дублирует существующую модель, требует правки всех `bonuses` в
  hero_races/hero_classes/hero_cultures и сохранения — больно и незачем.
- `spell_power` остаётся боевым (магия) — в отыгрыше не участвует.

### D2. Весовой cap рюкзака из defense
`total_cap_weight() = CARRY_BASE + defense * CARRY_PER_DEFENSE +
cart_weight_bonus`. `HeroStrategicResources.add` считает занятый вес через
`ResourceDef.weight_per_unit` из registry (registry уже доступен в
компоненте через `Services.resolve(&"resources")`).
- Почему вес, а не count: одна «глыба» ≠ один «ягодный куст»; weight_per_unit
  уже в данных.
- `capacity_bonus` (телега) меняется единицами → весом
  (`cart_weight_bonus`); сериализуем то же поле, значение трактуем как вес —
  старые сейвы читаются (12→пересчёт, см. Migration).
- Дефолтный `weight_per_unit = 1.0` = текущий count-лимит × базовый вес:
  подбираем `CARRY_BASE`, чтобы герой со средним defense (≈3–5) имел
  ~12–16 «единиц» в старых весах — баланс-проба не деградирует.

### D3. Добыча: улов от knowledge, стоимость от attack
- Улов: `yield' = clamp(yield + round((knowledge - K0) * 0.5), yield_min,
  yield_max * 2)` в `ResourceNodeManager.try_extract` (или на уровне
  `ResourceChainService`, где герой под рукой). Ключ knowledge попадает в
  extraction keys (сейчас туда идут skills/tools).
- Стоимость: у действия появляется REST-цена `REST_EXTRACT_COST / (1 +
  attack/ATTACK_DIVISOR)`. Слабый герой устаёт больше; сильный — меньше.
  «Быстрее рубит» = дешевле в REST, а не мульти-уловы за ход: ходовая
  модель не имеет внутри-ходового времени, REST-цена — честный эквивалент.
- Редкие узлы: `discovery_skill`-ветка в `ResourceNodeManager` получает
  бонусный шанс к обнаружению скрытых узлов от knowledge (порог 1 →
  1 + knowledge/KN_DISC_BONUS_DIV).

### D4. Вес артефактов и перегруз
- `Artifact.weight: float = 0.0` (новые артефакты задают вес; существующие —
  дефолт по слоту из таблицы в GameNumbers, чтобы не трогать все .tscn).
- Допустимый вес экипировки: `EQUIP_BASE + defense * EQUIP_PER_DEFENSE`.
  Перегруз `over = total_equip_weight - allowed` → `mp_mult = max(0.5,
  1.0 - over * EQUIP_MP_PENALTY)`, REST-спад `+ over * EQUIP_REST_PENALTY`.
  Применяется в `HeroMovementComponent` (per-day MP) и в
  `HeroNeedsComponent` (спад). Не запрет: надеть можно всегда.
- Альтернатива: запрет equip при нехватке стата. Отклонено — прямо против
  требования «ограничения из характеристик, не запрещки».

### D5. Точка применения штрафов — один калькулятор
Новый `LoadCalculator` (статик, как `LogisticsCalculator`):
`carry_weight(resources, registry)`, `equip_allowed(defense)`,
`overload_penalty(over)`, `extract_rest_cost(attack)`,
`extract_yield(def, knowledge)`. Все компоненты зовут его — один источник
правил, unit-тесты бьют в калькулятор, MCP-проба проверяет итог.

## Risks / Trade-offs

- [Баланс-проба ломается: весовой cap меньше счётного для слабого героя] →
  калибруем CARRY_BASE/CARRY_PER_DEFENSE под текущее поведение (проба
  зелёная на seed 20260913 — реграйдим после правки).
- [Старые сейвы: backpack_bonus трактуется иначе] → миграция в
  `deserialize`: если в данных `backpack_bonus` < CART_WEIGHT_MIN,
  умножаем на переводный коэффициент (см. Migration).
- [REST-цена добычи делает раннюю игру медленнее] → цена мала
  (≈0.05–0.15 REST), при attack≥2 почти нейтральна; контроль — баланс-проба.
- [Дефолт весов артефактов по слоту грубый] → принимаем (ponytail): точные
  веса в .tscn можно докрутить позже без изменения кода.

## Migration Plan

1. Наполнить `weight_per_unit` осмысленными значениями во всех `_add(...)`
   в `ResourceRegistry.gd` (деревья/камни тяжелее трав/травы).
2. Переключить `HeroStrategicResources` на весовой cap (D2); `capacity_bonus`
   → `cart_weight_bonus` (весе), миграция сейва в `deserialize`.
3. Добыча: yield (knowledge) + REST-цена (attack) через LoadCalculator.
4. Артефакты: поле `weight`, дефолты по слотам; перегруз → MP/REST.
5. UI: показать вес/лимит и штраф перегруза (HeroInventoryComponent UI-строки).
6. Реград баланс-пробы и калибровка констант; все 1512+ unit-тестов зелёные.

Rollback: все правки — константы + один калькулятор; откат change откатывает
коды, сейв-миграция обратно не нужна (формат данных не меняется).

## Open Questions

- Точные значения весов материалов и коэффициентов — определяются
  калибровкой под баланс-пробу (не меняет спецификацию).

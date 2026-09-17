# Tasks: attribute-weight-system

## 1. Данные: веса

- [x] 1.1 Заполнить `weight_per_unit` осмысленными значениями во всех `_add(...)` в `ResourceRegistry.gd` (деревья/камни/руды тяжелее трав/ягод; золото/камни — тяжёлые, ягоды/травы — лёгкие)
- [x] 1.2 Добавить `Artifact.weight: float = 0.0` + дефолты веса по слотам в `GameNumbers` (таблица `ARTIFACT_SLOT_WEIGHTS`) + применить дефолт в `Artifact.from_dict` при пустом весе

## 2. LoadCalculator (один источник правил)

- [x] 2.1 Новый `scripts/systems/LoadCalculator.gd` (статик): `carry_weight(resources, registry)`, `carry_cap(defense, cart_weight_bonus)`, `equip_allowed_weight(defense)`, `overload_penalty(over) -> {mp_mult, rest_extra}`, `extract_rest_cost(attack)`, `extract_yield(def, knowledge)`, `discovery_bonus_chance(knowledge)`
- [x] 2.2 Константы в `GameNumbers`/`GameNumbersHero`: CARRY_BASE, CARRY_PER_DEFENSE, EQUIP_BASE, EQUIP_PER_DEFENSE, EQUIP_MP_PENALTY, EQUIP_REST_PENALTY, REST_EXTRACT_COST, ATTACK_DIVISOR, KN_YIELD_PER, KN_DISC_BONUS_DIV
- [x] 2.3 Unit-тесты LoadCalculator: cap растёт с defense, улов растёт с knowledge, REST-цена падает с attack, перегруз → mp_mult ≥ 0.5 и rest_extra > 0

## 3. Весовой рюкзак

- [x] 3.1 `HeroStrategicResources`: `total_weight()` через registry, `total_cap()` → весовой cap (defense из героя + `cart_weight_bonus`); `add` ограничивает по весу (частичное размещение: `min(amount, floor(space / weight_per_unit))`)
- [x] 3.2 `HeroStrategicResourcesComponent`: передаёт defense в `strategic` при setup; `capacity_bonus` → `cart_weight_bonus` (сема: вес); миграция сейва в `deserialize` (старое значение < CART_WEIGHT_MIN → × переводный коэффициент)
- [x] 3.3 Unit-тесты рюкзака: лёгкий/тяжёлый, переполнение по весу (частичная добыча), телега добавляет вес, миграция старого сейва

## 4. Добыча: knowledge-улов + attack-стоимость

- [x] 4.1 `ResourceChainService.build_extraction_keys`: добавить key `knowledge` (из `HeroStatsComponent`)
- [x] 4.2 `ResourceNodeManager.try_extract`: улов через `LoadCalculator.extract_yield`, бонусный шанс на скрытые узлы от knowledge в discovery-ветке; REST-цена `extract_rest_cost(attack)` — списывается из `HeroNeedsComponent` (новый публичный метод `apply_action_cost(rest_amount)`)
- [x] 4.3 Unit-тесты: улов выше при knowledge > K0 (не выше yield_max*2), REST списывается и падает с attack, скрытый узел с шансом

## 5. Перегруз экипировки

- [x] 5.1 `HeroInventoryComponent`: `get_total_weight()` (sum Artifact.weight надетых); переиспользовать сигнал смены экипировки
- [x] 5.2 `HeroMovementComponent`: per-day `max_move_points = HERO_DAILY_MOVEMENT * mp_mult` из перегруза (LoadCalculator); пересчёт при смене экипировки
- [x] 5.3 `HeroNeedsComponent`: спад REST за ход += `overload_penalty.rest_extra` (только при перегрузе)
- [x] 5.4 Unit-тесты: перегруз → MP ниже и REST-спад выше; снятие тяжёлого → штрафы уходят; надеть нельзя запретить (equip всегда true)

## 6. UI: видимость

- [x] 6.1 Hero-интерфейс: строка «Вес: X / Y» (занятый/лимит) вместо счётной
- [x] 6.2 Hero-интерфейс: при активном перегрузе — строка штрафа («Перегруз: −N% скорости»)

## 7. Регрессия и калибровка

- [x] 7.1 Все 1512+ GdUnit4-тестов зелёные (старые тесты рюкзака перестроить под вес)
- [x] 7.2 MCP `test_balance_probe.py`: герой доживает 60 ходов RUNNING на seed 20260913; при деградации — калибровка CARRY_BASE/REST_EXTRACT_COST
- [x] 7.3 `openspec validate attribute-weight-system` + commit + push

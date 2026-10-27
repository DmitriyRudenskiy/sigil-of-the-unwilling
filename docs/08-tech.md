---
title: Технический стек и платформы
tags:
  - gdd
status: deepened
date: 2026-09-30
---

## Технический стек и платформы

- **Движок: Godot 4.7** (Q10 решён, 2026-10-02): data-driven через Godot resources.
- **Платформа:** PC (Steam), мышь + клавиатура (1.5); целевой FPS 60, минимальные требования — обычное офисное железо (стратегия, не экшен) [ПРЕДЛОЖЕНИЕ].
- **Детерминизм (K2 решено, 02d v1.2):** RNG в разрешении **нет** — исход определяется вводными (лестница исходов + Удача); реплей/авто-режим/CI: 100 прогонов → байт-в-байт один результат (02d §8.3 #14). PCG32/seed из боя исключены (были нужны только d20).

## Интерфейсы систем (контракты для программиста)

| Система | Контракт (псевдокод) | Статус |
|---|---|---|
| DnDBattleSystem | `Battle.new(grid, units) → Battle`; `battle.attack(att, tgt) → {hit, zone, dmg}`; `battle.simulate(ai) → Outcome`; `battle.round() → events[]`; `ladder(margin, luck) → zone` (02d v1.2 §3.2) | НОВОЕ (заменяет BattleSystem) |
| TurnSystem | `turn.advance() → PhaseEvents[]`; `phase ∈ {SETTLEMENT, PLAYER, THREATS}` (01-core-loop) | НОВОЕ |
| MapSystem | `map.move(hero, path) → cost`; `map.fog.reveal(pos, r)`; `map.node_at(cell) → Node?` | НОВОЕ (расширение GridSystem) |
| PartySystem | `party.add(character)`; `character.damage(n)`; `character.rest(days) → healed_hd`; `party.loss_stage() → int` (утрата = ступень −2 на спасброски до конца боя; `party.morale() → float` удалён — шкалы морали нет, K-M11) | НОВОЕ (HeroSystem влит) |
| EconomySystem | `economy.tick(city) → Flows{per resource}`; `economy.state(r) → OK/WARN/DEFICIT/COLLAPSE` (06-economy) | расширение ProductionSystem |
| RaidSystem | `pressure.tick() → Wave?` (функция давления, 02e4 §13.2, K-T5; календарь 7/10/14/17/21 — аннулирован); `pressure.directive(d) → {floor, ceiling, window}` (словарь директив, K-R3); `wave.composition` (K-R3); `raid.resolve(raid, city, hero) → Consequences` (02-mechanics §3.8) | расширение канона |
| SignSystem | `sign.prestige += delta` (MVP — только престиж, S2); `sign.trial(period_turns) → Quest` (**Post-MVP**, 02 §3.7; прежде `weekly_trial()` — аннулированная единица «неделя», Q-M63 → (в), D-189); `sign.followers() → pop_inflow/ход` (Post-MVP, S2) | НОВОЕ (из Части 11) |
| ChronicleSystem | `chronicle.append(event, cause)`; `rumor.tick()` (04-narrative) | НОВОЕ (срез Части 10) |
| GridSystem, BuildingSystem, WorkerSystem, AdjacencySystem, RoadSystem, NetworkSystem, DistrictSystem, SaveSystem | (BuildingSystem получает SM здания, 02-mechanics §3.5) | ПЕРЕНОС |

## Состояние кода

- **Пре-пивотный слой** (`game/`: world/city_arena/battle, 359 скриптов, 230 тест-файлов; системы: кризис-события, законы, фракции, крафт, артефакты, квесты) — **запланирован к замене Ф-планом** (GDD 0.2.1 владельца); текущее состояние и история циклов — корневой `CHANGELOG.md` (OpenSpec), в `docs/` не дублируется. Числа legacy-слоя вне баланс-листа — scope-строка [[07-balance]] (D-103).

## Data-driven и валидация

- Карточки (05-content) → Godot resources; валидация: headless-валидатора `validate_cards.gd` в репо нет (не написан, T-222); фактическая проверка — GdUnit-тесты каталогов: `tests/unit/data/test_mvp_catalog.gd`, `test_canon_classes.gd`, `test_canon_races.gd`, `test_campaign_building_catalog.gd` (`godot --headless --path game …`) (схема, закрытый набор тегов, целостность ссылок, уникальность id).
- Авто-тест баланса: детерминированные прогоны юнит vs CR-якор **K-резолвером** (05-content: исход + зона лестницы ≤ LADDER_CAP, коридор [К ЮНИТУ]; мера изменена Q-M80 → (а), экс-«раунды ≤ ROUND_CAP»), прогоняется в CI.

## Сохранения

Формат описан **по фактическому коду** (`scripts/campaign/save/mvp_save_manager.gd`,
`scripts/campaign/save/mvp_save_schema.gd`), инвентарь секций — в [[18-system-map#6. Сейв-пайплайн]].

```json
// user://mvp_save_slot_1.json  (PATH_TEMPLATE, CAMPAIGN_SLOT = 1, SLOT_COUNT = 3)
{
  "version": { "major": 1, "minor": 0 },        // MvpSaveSchema.current_version()
  "state": {
    "campaign":  { "turn": 12, "seed": 8123, "phase": "day" },
    "resources": { "food": 41, "wood": 12, "iron": 3 },
    "population": { "count": 34, "housing": 40 },
    "party":     [ { "id": "c1", "class": "fighter", "race": "human", "level": 3, "xp": 120, "stats": {}, "luck": 1 } ],
    "city":      { "buildings": [], "districts": {}, "hexes": {} },   // T-030
    "map":       { "region": "", "fog": {}, "nodes": {} },
    "prestige":  { "ledger": [ { "turn": 12, "source": "raid_repelled", "amount": 2 } ] },
    "sign":      { "id": "sign_craft", "rank": 2 }
  }
}
```

- Секций ровно восемь, они перечислены в `MvpSaveSchema.SECTIONS` вместе с ожидаемым
  типом; загрузка обязана проверить тип каждой (`_type_ok`) и отказать, а не
  «подлечить молча».
- **Производные ключи в сейве запрещены** (`MvpSaveSchema.DERIVED_KEYS`): `ladder`,
  `prestige_balance`, `effective_stats`, `morale`. Основание то же, что у снятия шкалы
  «морали» (K-M14): производное пересчитывается, а не хранится.
- **Хроники в сейве нет**: `chronicle_log.gd` — отдельный писатель, секции
  `chronicle` схема не объявляет (прежний пример с `"chronicle": [...]` описывал
  то, что код не пишет).
- Миграции: таблица `v1→v2: <поле>`; старая версия без миграции → отказ в загрузке + лог (не silent-default).
- **3 слота** (M2): слоты 1/2/3 + автосейв. Поражение в позднем бою можно перезагрузить из предыдущего слота — «2 часа в корзину» исключено; точка сейва в бою = граница раунда (ниже).
- Точка сейва в бою — граница раунда (07-ui-ux EC2).

## Производительность (оценка)

- Город — 52 гекс-клетки (02g §2.1; «сетка 24×24» — пре-D1), <100 зданий, партия ≤5, поле боя (размер — [[07-balance#4. Бой (указатели)]], D4), <40 юнитов → 60 FPS на офисном железе без оптимизаций (бюджет: кадр <16 мс; тяжелейшая операция — пересчёт ауры при постройке, O(зданий×radius²) < 10⁴ операций).

**EC:**
1. **Сейв старой версии** → миграция по таблице; нет миграции → «сейв несовместим» + лог (fail-fast, не «подлечить молча»).
2. **Повреждённый JSON сейва** (битый диск/редактирование) → fail-fast при загрузке, лог с именем поля; бэкап: сейв пишется атомарно (tmp + rename), предыдущая версия хранится.
3. **Данные контента с ошибкой в рантайме** (прошла валидацию, но движок упал) → краш-репорт с id карточки; CI-авто-тесты (05-content) ловят до релиза.

**Порядок (фазы 0–4 без изменений):** pre-prod → прототип (карта+город+1 бой по лестнице) → вертикальный срез → alpha → beta.

**Критерий фазы 1 (прототип):** один полный ход (01-core-loop) играем в сером блоке: движение героя, бой 1×1 по лестнице (02d v1.2), постройка 5 зданий, тренировка Пехотной линии (K-M15; прежде — «наём ополченца»: аннулированы и термин (Q-M55 → (б)), и юнит (K-M15)). #done-if

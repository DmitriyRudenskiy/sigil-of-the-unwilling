---
title: Технический стек и платформы
tags:
  - gdd
status: deepened
date: 2026-09-30
---

## Технический стек и платформы

- **Движок: Godot 4** [ПРЕДЛОЖЕНИЕ, Q10]: data-driven через Godot resources; критерий — где дешевле держать карточки контента. Альтернатива Unity 2022 LTS остаётся до конца фазы 0.
- **Платформа:** PC (Steam), мышь + клавиатура (1.5); целевой FPS 60, минимальные требования — обычное офисное железо (стратегия, не экшен) [ПРЕДЛОЖЕНИЕ].
- **Детерминизм (K2 решено, 02d v1.2):** RNG в разрешении **нет** — исход определяется вводными (лестница исходов + Удача); реплей/авто-режим/CI: 100 прогонов → байт-в-байт один результат (02d §8.3 #14). PCG32/seed из боя исключены (были нужны только d20).

## Интерфейсы систем (контракты для программиста)

| Система | Контракт (псевдокод) | Статус |
|---|---|---|
| DnDBattleSystem | `Battle.new(grid, units) → Battle`; `battle.attack(att, tgt) → {hit, zone, dmg}`; `battle.simulate(ai) → Outcome`; `battle.round() → events[]`; `ladder(margin, luck) → zone` (02d v1.2 §3.2) | НОВОЕ (заменяет BattleSystem) |
| TurnSystem | `turn.advance() → PhaseEvents[]`; `phase ∈ {SETTLEMENT, PLAYER, THREATS}` (01-core-loop) | НОВОЕ |
| MapSystem | `map.move(hero, path) → cost`; `map.fog.reveal(pos, r)`; `map.node_at(cell) → Node?` | НОВОЕ (расширение GridSystem) |
| PartySystem | `party.add(character)`; `character.damage(n)`; `character.rest(days) → healed_hd`; `party.morale() → float` | НОВОЕ (HeroSystem влит) |
| EconomySystem | `economy.tick(city) → Flows{per resource}`; `economy.state(r) → OK/WARN/DEFICIT/COLLAPSE` (06-economy) | расширение ProductionSystem |
| RaidSystem | `raid.schedule() → [7,10,14,17,21]` (пре-D4; график — T5, TBD); `raid.resolve(raid, city, hero) → Consequences` (02-mechanics §3.8) | расширение канона |
| SignSystem | `sign.prestige += delta` (MVP — только престиж, S2); `sign.weekly_trial() → Quest`; `sign.followers() → pop_inflow/week` (Post-MVP, S2) | НОВОЕ (из Части 11) |
| ChronicleSystem | `chronicle.append(event, cause)`; `rumor.tick()` (04-narrative) | НОВОЕ (срез Части 10) |
| GridSystem, BuildingSystem, WorkerSystem, AdjacencySystem, RoadSystem, NetworkSystem, DistrictSystem, SaveSystem | (BuildingSystem получает SM здания, 02-mechanics §3.5) | ПЕРЕНОС |

## Data-driven и валидация

- Карточки (05-content) → Godot resources; валидация: `godot --headless --script validate_cards.gd` (схема, закрытый набор тегов, целостность ссылок, уникальность id).
- Авто-тест баланса: детерминированные прогоны юнит vs CR-якор (05-content: исход + раунды ≤ ROUND_CAP, коридор [К ЮНИТУ]), прогоняется в CI.

## Сохранения

```json
// save.json (v1)
{
  "version": 1,
  "turn": 12,
  "city": {"hex": 52, "buildings": ["forge_01@12,7", "..."], "population": 34, "stocks": {"еда": 41}},  // hex 52: ядро 4 + кольца 1–3 (02g §2.1); «grid: 24» — пре-D1
  "party": [{"id": "c1", "class": "fighter", "level": 3, "hd": "2d10", "state": "READY"}],
  "map": {"hero_pos": [9, 11], "fog": "base64", "nodes": [...], "visibility": 1.4},
  "sign": {"id": "sign_craft", "prestige": 40, "rank": 2},
  "chronicle": ["..."]
}
```
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

**Критерий фазы 1 (прототип):** один полный ход (01-core-loop) играем в сером блоке: движение героя, бой 1×1 по лестнице (02d v1.2), постройка 5 зданий, наём ополченца. #done-if

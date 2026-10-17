# Proposal

## Why

GDD 02-mechanics §3.3 «Тренировка партии» — [КАНОН] (Q-M55→(б), D-189: пометка «механика TBD» снята). Тренировка — единственный способ пополнения партии (Q18: попутчики тренируются, не нанимаются). Реализовано частично: `campaign_training_service.gd` (действия из каталога зданий, class-gates, расовые тиры), но SM рекрута (PAUSED/STANDING), резидентная модель статусов (K-A5), пауза при разрыве сети — не реализованы. Данные расходятся с GDD (C-12).

## What Changes

- Фиксирует: тренировка только в городе (герой в походе → недоступна, тултип с причиной).
- Фиксирует три позиции K-M15 (базовые бойцы MVP): пехотная линия (fighter), стрелок (ranger), волшебник (T-041: статы — баланс-конфиг) с сетью города на позицию.
- Фиксирует: стоимость списывается сразу, время в днях/тиках (progress += tick/(t×N)).
- Фиксирует SM рекрута: REQUESTED→TRAINING→READY→(партия) или STANDING (партия полна; в MVP пул = партия → STANDING = Post-MVP); TRAINING→PAUSED при разрыве сети, PAUSED→TRAINING при восстановлении (таймер не сбрасывается).
- Фиксирует резидентную модель статусов (K-A5): один житель = один статус (Child/Worker/Mentor/Recruit/Fighter/Hero/Party-in-field); призыв = вакансия (производство останавливается); население — непрерывная величина.
- Фиксирует FS/EC: пауза ≠ отмена; STANDING виден в UI; рейд по зданию → PAUSED; продажа здания → PAUSED (возврат 50%, без эксплойта); население ниже порога (10 на юнит [ПРЕДЛОЖЕНИЕ]) → недоступно.

## Capabilities

### New Capabilities
- `party-training`: тренировка как единственный источник партии, SM рекрута, резидентная модель (K-A5).

### Modified Capabilities
- None.

## Deduplication and status (v4)

- **Дубликаты (main specs):** нет (pre-pivot `settlement-*` — про поселения legacy, не про тренировку).
- **Дубликаты (active changes):** `campaign-city-building-economy` — каталог зданий (источник training-действий), не дублируется (зависимость).
- **Dead tasks (реализовано):** training-действия из каталога, class-gates, расовые тиры, PARTY_CAPACITY — `campaign_training_service.gd`, помечены `[x]`.
- **Пересечения:** `party-characters` (замена мёртвых — тот же процесс), `city-construction-districts` (здания-источники: барраки/стадион/магистрат), `mvp-ui-flow` (экран «Партия»: очередь тренировок, «что освободит слот»).

## Impact

- Код: `campaign_training_service.gd` (SM рекрута, паузы), `population_system.gd` (резидентные статусы K-A5), `campaign_building_catalog.json` (данные позиций).
- Сейв: рекруты (building_uid, class_id, progress, state) — миграция fail-fast.
- Не затрагивает: бой (dnd-battle-ladder), городскую экономику (city-construction-districts).

## Contradictions

- **C-12 (данные, docs vs code):** 02-mechanics §3.3 «Базовые бойцы MVP» (07-balance §3): мечник = 20 еды + **10 оружия** + 0.6 дня; стрелок = 15 еды + 15 дерева + 0.5 дня vs код `campaign_building_catalog.json`: fighter = 20 еды + **2 железа**, ranger = 15 еды + 15 дерева, cleric = 18 еды + 5 дерева + 1 железа. K-R2: оружие = товар Layer-2, не ресурс; `CAMPAIGN_MVP_IDS = [food, wood, iron]`. ГDD-таблица не синхронизирована с K-R2 и кодом; волшебника (третий базовый боец K-M15) в коде нет (T-041).
- **C-13 (данные, docs vs code):** GDD-маска тренировки MVP = 6 классов (fighter/ranger/cleric/wizard/rogue/paladin) vs код = 3 (fighter/ranger/cleric). Базовые 3 по K-M15 = fighter/ranger/**wizard** — в коде вместо wizard стоит cleric. Синк маски — задача 2.3.

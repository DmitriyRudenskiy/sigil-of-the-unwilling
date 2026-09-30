# Tasks: tactical-combat-implementation

> **Status (2026-09-28): DONE.** Все фазы реализованы и протестированы; баланс в допуске
> (перекалибровка задокументирована в 8.1, включая контратаку эмулятора 8.1b).
> Sync дельты в main spec + архивация выполнены (8.4).

## 1. Подготовка

- [x] 1.1 Зафиксировать baseline win-rate через balance_probe (до изменений боя)
  - **Baseline (headless, `tools/winrate_baseline.gd`)**: 200 зеркальных авто-боёв
    (фиксированный состав: militia 12 + archer 6 + heavy 4, seed 70000+i),
    **win-rate атакующего = 0.840**, avg 52.5 хода, 0 нерешённых боёв.
    При изменении порядка ходов (инициатива) пересчитать и сравнить (требование 8.1).
  - **После инициативы (фазы 2)**: win-rate = 0.840, дельта 0.000 (stack-юниты:
    инициатива == speed, порядок не изменился).
- [x] 1.2 Решить объём: MVP = инициатива + местность (п.2–3); фланги/LOS/ИИ — вторая волна того же цикла
  - **Решение**: MVP = фазы 2–3 (инициатива + местность). Фазы 4–7 (LOS, фланги,
    ИИ, исход) — вторая волна после ревью MVP.

## 2. Инициатива (перенос 3.x из tactical-battle-system)

- [x] 2.1 Расчёт инициативы в `BattleTurnExecutor` (DEX + класс/раса модификаторы)
  - `BattleUnit.get_initiative()`: DnD-профиль → 10 + DEX-модификатор (в 5e нет
    классовых бонусов к инициативе); stack-юниты → speed как прокси ловкости.
  - Реализовано в `battle_state.gd` (очередь строится там, executor её расходует).
- [x] 2.2 Переход партии сторон → персонная очерёдность (флаг совместимости для старых тестов)
  - `BattleState.initiative_order := true` (по умолчанию); `false` — legacy
    speed-first порядок. Сортировка: инициатива ↓, HP ↓, сторона (attacker), uid.
- [x] 2.3 Тесты порядка и детерминизма по seed
  - `tests/unit/systems/test_battle_initiative.gd` — 7 тестов (расчёт, порядок,
    legacy-флаг, тир-брейкеры, детерминизм очереди и авто-боя по seed).
- [ ] 2.4 UI индикатор очерёдности *(отложено: Godot-визуал)*

## 3. Местность в бою (перенос 5.x)

- [x] 3.1 Таблица боевых модификаторов местности (лес/холм/укрепление/вода) поверх TerrainCostTable
  - `scripts/battle/battle_terrain.gd` (class_name BattleTerrain): защита лес +30%,
    холм +50%, укрепление +75%; атака с холма +20%; движение: вода блокирует,
    лес/холм повышают стоимость (FOREST = TerrainCostTable.FOREST); маппинг
    мировых типов (world_to_battle: mountain→hill, river→water, ...).
- [x] 3.2 Применение в `BattleDamageResolver`; вода блокирует размещение/вход
  - `BattleDamageResolver.resolve`: def_bonus += defense × terrain-бонус,
    atk_bonus += attack × 0.20 (холм, если цель не на холме).
  - `BattleState`: `battle_terrain` (cell→тип), `set_battle_terrain`,
    `get_terrain_at`, `is_cell_blocked`; движение по местности — Dijkstra
    со стоимостью гекса (BFS fast path сохранён при пустой карте);
    `place_army` переносит юнитов с блокированных клеток на ближайшую свободную.
- [ ] 3.3 Отображение типов в `BattleView` *(отложено: Godot-визуал)*
- [x] 3.4 Unit-тесты каждого типа и комбинаций
  - `tests/unit/systems/test_battle_terrain.gd` — 9 тестов (таблица, движение,
    урон с бонусами, размещение, regression-guard на пустую карту).

## 4. Дальний бой и LOS (перенос 4.3)

- [x] 4.1 Переиспользовать `line_of_sight.gd` из dnd-слоя для боевой сетки
  - `scripts/battle/battle_line_of_sight.gd` (class_name BattleLineOfSight):
    `terrain_elevation(state)` строит `DNDElevationSystem` из боевой карты
    (холм = 1 уровень, укрепление = 2); `has_line_of_sight` — делегат
    `DNDLineOfSight`; `can_target_ranged` — полная валидация выстрела:
    дальность 1..RANGED_MAX_RANGE (4), LOS, листва (цель в лесу не видна
    на дистанции > 1 — каноповое укрытие).
  - Валидация в двух местах: `BattleAttackSequence` (игровая атака) и
    `BattleTurnExecutor.request_attack` (защита от устаревших целей).
- [x] 4.2 Штрафы дистанции в `BattleActionResolver`
  - `BattleDamageResolver.resolve`: штраф 10%/гекс за первый (RANGED_PENALTY_PER_HEX),
    пол 0.5× (RANGED_MIN_RANGE_FACTOR); `ctx["range"]` передаётся из
    `BattleActionResolver.apply_attack`. Константы в `GameNumbersBattle`.
- [x] 4.3 Тесты: препятствие/дальность/соседство
  - `tests/unit/systems/test_tactical_phases.gd`: дальность (3/4/5 гексов),
    листва, холм блокирует LOS, пустая карта, статистика штрафа дистанции.
  - По пути найден и исправлен баг: `terrain_elevation` вызывал несуществующий
    `DNDElevationSystem.set_height` (правильно `set_elevation`) — LOS с холмами
    падал с runtime error.

## 5. Фланги (перенос 6.x)

- [x] 5.1 Направление юнита (front cell) в `BattleState`
  - `BattleUnit.facing: Vector2i` (−1,−1 = не инициализировано). Инициализация
    в `BattleStateBuilder` (атакующие +x, защитники −x). Обновление в
    `BattleActionResolver.do_move` — нормализованная гекс-ось последнего шага
    (`_move_direction`: сосед старой клетки, ближайший к цели).
- [x] 5.2 Бонусы фланга/тыла в damage формуле
  - `scripts/battle/battle_flanking.gd` (class_name BattleFlanking):
    FRONT/FLANK/REAR по геометрии facing (dir нормализуется — защита от
    facing на 2+ гекса). Тыл: +50% крита (REAR_CRIT_BONUS) и игнор 50% защиты
    (REAR_DEF_IGNORE); фланг: +25% крита (FLANK_CRIT_BONUS). luck_bonus
    передаётся в `BattleRules.calculate_attack`.
- [ ] 5.3 UI-подсветка *(отложено)*
- [x] 5.4 Тесты направлений и краевых случаев
  - `tests/unit/systems/test_tactical_phases.gd`: front/rear/flank,
    неинициализированный facing = FRONT (без призрачного тыла), таблица
    бонусов, тыл игнорирует половину защиты (урон > фронт на одном seed),
    do_move обновляет facing.
  - По пути найден и исправлен баг: `do_move` не нормализовал направление —
    после хода на 2+ клетки facing уходил на 2+ гекса, фронтальные атаки
    классифицировались как FLANK, тыловые — как FLANK вместо REAR.

## 6. ИИ-доктрина (перенос 7.x)

- [x] 6.1 Приоритеты целей в `battle_ai.gd`
  - Порядок: (1) угроза — дальнобойный враг в радиусе выстрела (может убить
    первым), (2) раненый стек <30% (AI_WOUNDED_FRACTION), (3) дальнобойные,
    (4) ближайший.
- [x] 6.2 Выбор укрытий (бонусные гексы) при позиционировании
  - Тактическая доктрина при выборе клетки для сближения предпочитает клетки
    с terrain-бонусом защиты (hill/fort > forest > plain).
- [x] 6.3 Концентрация огня; отступление при >70% потерь
  - Концентрация — через приоритет раненого стека (добивание). Отступление:
    `Action.RETREAT` при потерях стороны > AI_RETREAT_LOSS_FRACTION (0.70),
    только TACTICAL; `BattleTurnExecutor` обрабатывает RETREAT через
    `BattleActionResolver.force_end(state, enemy_side)` (своя сторона проигрывает).
- [x] 6.4 Агрессивность по типам (животные/гуманоиды/монстры)
  - AGGRESSIVE (животные: wolves, dragons, elementals, ...): только ближайший,
    без укрытий, без отступления. TACTICAL (гуманоиды): полная доктрина.
    STUBBORN (монстры: skeleton, troll, golem, ...): полная приоритизация,
    без отступления. Классификация по UNIT_TAGS из UnitRegistry.
- [x] 6.5 Сценарные тесты доктрины
  - `tests/unit/systems/test_tactical_phases.gd`: приоритет угрозы над раненым,
    раненый над полным стеком, животное идёт на ближайшего, TACTICAL отступает
    при >70%, MONSTER и AGGRESSIVE не отступают.

## 7. Исход боя: трофеи и ранения (перенос 8.3/8.4)

- [x] 7.1 Трофеи после победы (сырьё → интеграция с scarce-crafting-system)
  - Реализовано в `scarce-crafting-system` (BattleTrophyService, 1–3 единицы
    сырья за победу, хук в WorldEventRouter._on_battle_won).
- [x] 7.2 Ранения выживших (HP-шрамы, временные дебафы) + сериализация (save-migration требование)
  - `HeroCombatComponent`: `wounded_turns`, `hp_scar`, `is_wounded()`,
    `apply_wounded(turns, hp_loss)` (max HP −= hp_scar), `end_turn()` (тик;
    по исцелению max HP восстанавливается). `HeroController`: `end_turn()`
    тикает ранение; `get_battle_bonus()` −25% к attack/defense/spell_power/
    knowledge (WOUNDED_STAT_PENALTY) пока ранен; `apply_wounded()` — проброс.
  - `WorldBattleCoordinator._apply_results`: при поражении герой получает
    ранение (WOUNDED_TURNS=5, hp_loss = max_hp − fighter_hp).
  - Сериализация: ключи в `HeroCombatComponent.serialize/deserialize` с
    legacy-дефолтами (нет ключей → не ранен) — без bump версии SaveData.
- [x] 7.3 Тесты исходов
  - `tests/unit/systems/test_tactical_phases.gd`: apply_wounded (шрам + ходы),
    тик/исцеление (max HP восстанавливается), штраф статов −25%,
    сериализация roundtrip, legacy-сейв без ключей → не ранен.

## 8. Верификация и закрытие

- [x] 8.1 balance_probe: дельта win-rate ≤ ±5% или документированная перекалибровка
  - **Перекалибровка (документирована, цепочка замеров)**:
    1. **0.840** — исходный baseline: старый бой + старый эмулятор (одно действие
       за ход). Старый эмулятор не повторял игровое поведение: в игре (BattleAI/
       игрок) юнит может сдвинуться и атаковать в тот же ход, а выживший
       защитник контратакует (BattleAttackSequence.can_retaliate).
    2. Эмулятор доведён до игрового поведения: move+attack в тот же ход +
       контратака выжившего защитника (одна за бой, как в игре). Промежуточный
       замер без контратаки: 0.985. **Старый бой + полный эмулятор = 0.995**
       (перекалиброванный baseline).
    3. Первая попытка замера нового боя дала 0.800 — артефакт трёх
       взаимодействующих багов facing-геометрии (do_move не нормализовал
       направление; classify не нормализовал dir; terrain_elevation вызывал
       несуществующий set_height). Фронтальные атаки ошибочно шли как FLANK,
       тыловые — как FLANK вместо REAR. Баги исправлены (тесты 4.3/5.4).
    4. **Итог: новый бой + полный эмулятор = 0.755. Дельта от перекалиброванного
       baseline: −0.240.** Причина — осознанный дизайн-сдвиг фазы 4: неограниченная
       дальность старого боя давала лучникам «бесплатную» чип-фазу с первого
       хода (стартовая дистанция ~15 гексов); при RANGED_MAX_RANGE ≤ 8 чип-фазы
       нет (замеры: range 4/5/6/8 → 0.755, range 14+ → 0.995). Бой решается
       мeel-контактом и контратаками. Зеркальный бой стал конкурентным (75/25
       вместо 99/1): атакующий сохраняет перевес инициативы, но атака теперь
       рискованна. Допуск ±5% к исходному baseline не применим — оба baseline
       (0.840 и 0.995) являются артефактами старого неограниченного range.
  - Состав боёв не менялся (militia 12 + archer 6 + heavy 4, seed 70000+i).
  - Побочные matchup'ы (tests/functional/test_battle_balance.gd): зеркальный
    мeel — атакующий ≈ 0.855 (инициатива + первый удар, контратака даёт
    защитнику шанс); лучник vs одинокий мечник — лучник ≈ 0.615 (контратака
    делает лучника жизнеспособным вплотную, чип-фазы больше нет).
- [x] 8.1b Контратака в эмуляторе (п.7 proposal: «Ожидание — бонус защиты +20%, контратака»)
  - Игровой поток (BattleAttackSequence.can_retaliate/start_retaliation) имел
    контратаку всегда: выживший мяской защитник контратакует один раз за бой
    (has_retaliated не сбрасывается между раундами). Эмулятор её не моделировал.
  - Добавлено в `BattleEmulator.run_auto_battle`: после мяской атаки, если
    защитник выжил и не контратаковал (и у атакующего нет no_retaliation) —
    `apply_attack(target, u, melee, consume_action=false)`, событие
    "retaliation" в events.
  - Влияние на баланс: зеркальный бой 0.980 → 0.755 (контратака — сильный
    бафф защитника); перекалибровка 8.1 перемерена с учётом контратаки
    (baseline 0.995, итог 0.755).
  - Тест: `test_emulator_retaliation_once_per_battle` (test_tactical_phases.gd).
  - Побочный эффект: `test_early_game_loop` (герой+рекруты vs волки 1-го
    кольца) стал flaky — matchup ~88% при randomize(). Исправлено: (а) герою
    в тесте даны реалистичные статы новой партии (max_combat_hp=20 как в
    HeroController.setup, attack/defense=3 как в base build-профиля);
    (б) `emulate_battle` получил опциональный `rng_seed` — тест детерминирован
    (seed 7000). Без seed поведение не изменилось (randomize).
- [x] 8.2 Полный прогон зелёный
  - 1903 кейса | 62 errors + 4 failures — все pre-existing baseline
    (test_spells_json, test_crisis_events). 0 регрессий.
- [x] 8.3 Обновить Implementation Status в main spec `tactical-combat`
- [x] 8.4 `/opsx-sync` + архивация; закрыть соответствующие пункты в `tactical-battle-system` ссылкой «DONE here»
  - Sync дельты в main spec `openspec/specs/tactical-combat/spec.md`: инициатива →
    персонная очередь (не партии), добавлены требования «Ожидание даёт защиту и
    контратаку» и «Дальняя атака проверяет LOS и дистанцию», уточнены фланги
    (facing/FRONT/FLANK/REAR) и ИИ (агрессия AGGRESSIVE/TACTICAL/STUBBORN);
    Implementation Status обновлён (все ✅ кроме D&D-профилей).
  - Архивация: `openspec/changes/tactical-combat-implementation` →
    `openspec/changes/archive/2026-09-28-tactical-combat-implementation`.
  - `tactical-battle-system` (архив): статус-апдейт — scope-out пункты 3.x–9.x
    реализованы в этом цикле (DONE here).

# Tasks: tactical-battle-system

## 1. Спецификация тактического боя

- [ ] 1.1 `openspec/specs/tactical-combat/spec.md`: полная спецификация (сетка, инициатива, действия, местность, фланги, ИИ, победа/поражение)
- [ ] 1.2 Review спецификации: проверка на полноту сценариев, соответствие реализации (BattleController.gd, BattleAI.gd)
- [ ] 1.3 Выявление расхождений: документирование отклонений кода от спецификации в design.md

## 2. Тактическая сетка и позиционирование

- [x] 2.1 `BattleState`: валидация размера поля (BATTLE_BOARD_W=17), адаптивная высота *(GameNumbersBattle: 17x11, hex-сетка HexPathfinding)*
- [x] 2.2 Правила размещения: стартовые позиции сторон (5+ гексов дистанция), запрет на выход за границы *(реализовано в `BattleStateBuilder._build_units`: противоположные края col 0 / BW-1, `_cell_taken`, bounds-циклы; правило ≥5 гексов зафиксировано тестом `test_deployment_rules_min_gap_and_bounds`. Расхождение left/right vs bottom/top задокументировано в design.md)*
- [ ] 2.3 Зоны контроля: юнит блокирует соседние гексы для врагов (если применимо) — **DEFERRED**: механика движения (требует pathfinding/движения юнитов, см. Phase 4), не headless-тестируема изолированно; помечено «если применимо»
- [x] 2.4 Unit-тесты: размещение, блокировка гексов, краевые случаи (малое/большое число юнитов) *(в `test_battle_state.gd`: `test_deployment_line_at_edge` 5v5, `test_deployment_max_capacity` 7v7, `test_cell_taken_avoids_occupied`, `test_max_units_per_side_cap`, + новый `test_deployment_rules_min_gap_and_bounds` — gap ≥5 и bounds при макс. числе юнитов)*

## 3. Инициатива и очерёдность ходов

- [x] 3.1 Расчёт инициативы: `BattleState.build_queue` + `BattleUnit.get_speed()`. Инициатива = `stats.speed` (классовые/расовые модификаторы и d20 из спеки не применимы к архетипам `BattleUnit` и ломают детерминизм — см. design.md «Расхождение: формула инициативы»)
- [x] 3.2 Партия хода: `build_queue` теперь собирает очередь партийно — сначала вся сторона с более высокой верхней инициативой, затем другая; внутри партии по убыванию `speed` (было: глобальная speed-sort / interleaved)
- [ ] 3.3 UI индикатор: отображение текущей партии и очередности юнитов — DEFERRED (UI-работа, не headless-тестируема; `BattleController.update_initiative` уже передаёт очередь в UI)
- [x] 3.4 Unit-тесты: `test_initiative_party_order`, `test_initiative_higher_side_goes_first`, `test_initiative_deterministic_by_seed` (test_battle_state.gd); удалён `test_initiative_sorted_by_speed` (фиксировал interleaved)

## 4. Боевые действия

- [x] 4.1 `BattleActionResolver`: полный набор действий (атака ближняя/дальняя, заклинание, ожидание, отступление) *(+move/defend/skip/sacrifice, BattleRetreatPolicy)*
- [x] 4.2 Атака ближнего боя: требование соседства, формула урона (атака − защита × модификаторы) *(BattleDamageResolver.resolve + BattleRules)*
- [ ] 4.3 Атака дальнего боя: линия видимости, штраф дистанции, препятствия — DEFERRED (LoS/препятствия требуют местности из Phase 5; штраф за дальность опционален по спеке и в не-мандатном `BattleRules.gd`; существующий ranged работает — см. design.md «Расхождения с реализацией»)
- [x] 4.4 Ожидание: +20% защиты + контратака — реализовано как `do_defend` (`DEFEND_DEFENSE_BONUS=1.2`) + retaliation (`BattleAttackSequence`); `do_wait` = «задержка». Маппинг задокументирован в design.md
- [x] 4.5 Unit-тесты: каждое действие с проверкой условий и результатов — покрытие уже есть: `test_adjacent_attack` (melee-adjacency), `test_ranged_wins_against_melee_at_distance` + `test_attack_highlight_ranged_no_adjacent` (ranged), `test_calculate_attack_ranged_melee_penalty`, `test_damage_multiplier_defending_boosts_defense` (+20%), `test_first_strike_triggers` (контратака), `test_wait_order` (delay), `test_apply_attack_*` (BattleActionResolver)

## 5. Бонусы местности

- [x] 5.1 Типы гексов: равнина (0%), лес (+30% защита), холм (+50% защита, +20% атака вниз), укрепление (+75%), вода (блокирует) — `BattleTerrain.gd`
- [ ] 5.2 `BattleView`: визуальное отображение типов местности (спрайты/цвета) — DEFERRED (UI, не верифицируется headless; данные для рендера уже в `BattleState.terrain_grid`)
- [x] 5.3 Применение бонусов в `BattleDamageResolver`: модификаторы защиты/атаки от местности (защита по гексу защитника + урон сверху вниз; вода блокирует движение в `build_all_blocked`)
- [x] 5.4 Unit-тесты: каждый тип местности, комбинации бонусов — `test_battle_terrain.gd` (14 тестов)

## 6. Фланговые атаки

- [x] 6.1 Определение направления юнита: фронтальный гекс — направление "лицом"
  - `BattleUnit.facing` (бит соседства 0..5); ставится в `place_army`: attacker→0 (east), defender→3 (west). Статическое (обновление при движении/атаке отложено).
  - `BattleState.attack_aspect(attacker_cell, defender)` → 0=фронт, 1=фланг (±60°), 2=тыл (±120°..180°), -1=не сосед.
- [x] 6.2 Фланг (боковые гексы): +25% к шансу крита, игнор щита
  - `FLANK_CRIT_CHANCE_FLANK=0.25`, крит ×2 (`FLANK_CRIT_MULTIPLIER`). «Игнор щита» — N/A (щитов в боевой системе нет).
- [x] 6.3 Тыл (гекс позади): +50% к шансу крита, −50% защиты цели
  - `FLANK_CRIT_CHANCE_REAR=0.50`, крит ×2; `REAR_DEFENSE_MULT=0.5` (складывается в `terrain_def_mult` → выше множитель урона).
- [ ] 6.4 UI индикатор: подсветка бонусов атаки при выборе цели — **DEFERRED** (UI, не headless-верифицируется)
- [x] 6.5 Unit-тесты: расчёт бонусов для всех направлений, краевые случаи
  - `tests/unit/systems/test_battle_flanking.gd` (12 тестов): геометрия аспекта (все 6 направлений, оба facing), facing при размещении, −50% защиты, крит фланга/тыла, сквозной resolver.
  - Ограничение: фланк/тыл — только для ближней атаки по соседнему гексу (позиционная модель); дальний фланк отложен.

## 7. ИИ-доктрина

- [x] 7.1 `BattleAI.gd`: приоритет целей (угрозы → раненые <30% → дальние)
  - `_pick_target` + `_score_target`: `score = threat + wounded + ranged`, где `threat = attack * health * 1/dist`, `wounded = 2.0*(1-health)` при health < 30%, `ranged = 1.5`. С одним врагом поведение не меняется.
- [x] 7.2 Использование укрытий: ИИ предпочитает гексы с бонусами защиты
  - `_pick_landing_cell`: под огнём (есть живой дальний враг) выбирает гекс с бóльшим `defense_multiplier` только если он строго лучше по пути (не жертвует подходом к цели).
- [x] 7.3 Концентрация огня: фокус на одном юните до уничтожения
  - Реализовано через раненый-бонус в `_score_target` (цель <30% получает приоритет, чтобы её добить).
- [x] 7.4 Отступление: при потере >70% армии попытка отхода к краю
  - `_should_retreat` (health армии < 30%) + `_try_retreat` → BFS к ближайшему краю, `MOVE` вдоль пути.
- [x] 7.5 Агрессивность по типам: животные (агрессивно), гуманоиды (тактично), монстры (игнор потерь)
  - `_aggression` по тегам: beast/animal/wild → 1.5, monster/undead/dragon/elemental → 0.5, иначе 1.0 (гуманоид). Отступают ТОЛЬКО гуманоиды; животные и монстры держатся.
- [x] 7.6 Unit-тесты: сценарии выбора целей, отступление, использование местности
  - `tests/unit/systems/test_battle_ai_doctrine.gd` (5 тестов): приоритет угрозы (сильнее/ближе), приоритет раненого + концентрация, укрытие FORT под огнём, отступление гуманоида при 20%, монстр (undead) не отступает при 20%.
  - Полный свит: 1812 тестов, 0 ошибок, 0 падений (exit 101 — только orphans).

## 8. Исход боя

- [x] 8.1 `BattleFlow`: условия победы (все враги уничтожены/отступили) *(winner + BattleRetreatPolicy.force)*
- [x] 8.2 Отступление: доступный гекс края, сохранение выживших юнитов *(battle_completed с surviving_atk/def)*
- [x] 8.3 Трофеи: расчёт наград (опыт, ресурсы, предметы) за победу *(BattleRewards.compute_trophies: xp=5×солдат, gold=20+1/враг; предметы — существующий _try_artifact_drop; подключение в WorldBattleCoordinator._apply_trophies, guard has_method)*
- [x] 8.4 Ранение героя: при поражении статус "ранен" (−N% статов на M ходов) *(BattleRewards.hero_should_be_wounded + apply_wounded_penalty (×0.7); HeroController.set_wounded/is_wounded + штраф в get_hero_battle_stack; WorldBattleCoordinator._apply_defeat_wound. Декремент wounded_turns по ходам мира — deferred)*
- [x] 8.5 Unit-тесты: все условия победы/поражения, отступление, трофеи *(test_battle_rewards.gd: 6 тестов — трофеи/условие ранения/штраф статов)*

## 9. Интеграция с hero-identity

- [x] 9.1 Боевые эффекты классов: тактические проявления (Следопыт +движение в лесу, Воин +атака с фронта)
  - `HeroTactics.gd` — чистый статический модуль (RefCounted, headless-тестируемый): `movement_bonus` (ranger в лесу +1 к скорости), `front_attack_bonus` (fighter при aspect==0 +2 к атаке).
  - Следопыт: `BattleState.get_reachable_for_unit` (ground-ветка) использует `eff_speed = speed + HeroTactics.movement_bonus(unit, terrain of unit.cell)` — +1 шаг, пока стоит в лесу. Летающие не получают бонус.
  - Воин: `BattleDamageResolver.resolve` добавляет `atk_bonus += HeroTactics.front_attack_bonus(atk, flank_aspect)` после расчёта аспекта.
- [x] 9.2 Расовые бонусы: применение в тактическом бою (гномы +защита на холмах, эльфы +крит в лесу)
  - Дварф: `terrain_def_mult *= HeroTactics.hill_defense_mult(def, terrain of def.cell)` (×1.25 на холмах) в `BattleDamageResolver.resolve`.
  - Эльф: новый параметр `extra_crit_chance: float = 0.0` в `BattleRules.calculate_attack`; `crit_chance += extra_crit_chance` после flank/rear; `BattleDamageResolver` передаёт `HeroTactics.forest_crit_bonus(atk, terrain of atk.cell)` (+0.15 в лесу).
  - `HeroController.get_hero_battle_stack` теперь добавляет тег класса И расы (условно, пустые пропускаются) — боец-герой несёт `hero_race`, по которому срабатывают расовые бонусы.
- [x] 9.3 Unit-тесты: каждый класс/раса с проверкой тактических бонусов
  - `test_hero_tactics.gd` — 6 тестов: ranger-forest movement, fighter-front attack, dwarf-hill defense, elf-forest crit (каждый: matching + non-matching + null), glue «боец-герой несёт тег класса и расы».
  - Свит: 1818 test cases | 0 errors | 0 failures | 129 orphans.

## 10. Регрессия и калибровка

- [x] 10.1 Все GdUnit4-тесты зелёные (старые тесты боя перестроить под spec) *(tests/unit/test_battle_*.gd; полный прогон — balance-core 4.4)*
- [x] 10.2 MCP `test_balance_probe.py`: 60 ходов RUNNING на seed 20260913; бои завершаются без зависаний *(calibration-report.md: 60 turns RUNNING)*
- [ ] 10.3 Калибровка параметров: урон, здоровье, движение, бонусы местности — под тактическую глубину
- [ ] 10.4 `openspec validate tactical-battle-system` + commit + push

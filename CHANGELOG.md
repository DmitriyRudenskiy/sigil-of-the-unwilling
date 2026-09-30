# Changelog

Формат: записи по завершённым OpenSpec-циклам. Детали — в `openspec/changes/archive/`.

## 2026-09-25

### dynamic-world-crisis-system — Save/Load Integration (Task 4.3)
- `CrisisEventSystem.serialize_state()`/`deserialize_state()` — состояние (current_crisis по id, active_event_ids, day/next_event/last_crisis, event_history, law via `LawManager.to_dict`); неизвестные id безопасно пропускаются, пустой dict = no-op
- Провязано в `GameManager.save_game`/`load_game` (null-guarded ключ `crisis_state`)
- Тесты: +3 round-trip в `test_crisis_events.gd` (полный round-trip включая law, empty=noop, unknown ids skipped)
- **Отложено**: UI re-render при загрузке во время события (не верифицируется headless)
- Полный сьют: **1757/1757 passed, 0 failures** (129 orphans)

### dynamic-world-crisis-system — Law System + 8 Crisis Events (Task 2.3, Task 4.2)
- `LawManager.gd` (RefCounted, standalone-тестируемый) — дерево законов: 3 ветки (Order/Faith/Survival), 6 законов (2/ветку), `requires` = prerequisite, `unlock_law()` с проверкой предков, `get_passive_effects()` (merged modifiers по key), `to_dict`/`from_dict`
- Интеграция: `CrisisEventSystem.law_manager` + эффект `unlock_law` в `apply_choice_effects`
- 8 кризисов (все 6 типов CrisisType): fire, famine, riot, raiders, plague, anomaly, flood, fuel — по 3 выбора, эффекты в рамках data-model
- Исправлены битые иконки в `crisis_01_fire`/`crisis_02_famine` (реальные `crisis_fire.png`/`crisis_famine.png`)
- Тесты: `test_law_manager.gd` (11) + `test_crisis_events.gd` (7: 8 шаблонов, покрытие типов, иконки, well-formed choices)
- **Known deviation (pre-existing)**: pipeline кризисов→GameManager не провязан (`modify_*` методы отсутствуют, ресурс `materials`/`mana_change`/`reputation_change`/`population_drain` не моделируются в `player_data`). Headless не видит (early-return). Требуется решение по маппингу ресурсов — отдельно.
- Полный сьют: **1754/1754 passed, 0 failures** (129 orphans)

### dnd-battle-system — Phase 6: Integration (TASK_21 PARTIAL, TASK_22/23 DEFERRED)
- `combatant_profile.gd` — `DnDCombatantProfile`: per-character stat block (abilities, proficiency, armor/AC, weapon, ranged flag), `get_ac()` (syncs DEX), `get_attack_ability_mod()` (STR melee / DEX ranged), `to_dict`/`from_dict`
- `battle_bridge.gd` — `DnDBattleBridge`: `resolve_attack()` (attack roll vs AC, nat-20 crit, damage dice — delegates to `DNDAttackRoll`/`DNDDamageCalculator`), `build_initiative()` (via `DNDInitiativeTracker`)
- `BattleState.BattleUnit.dnd_profile` — optional seam (default null); pure stack-model units unchanged → backward compatible
- Тесты: `tests/unit/battle/test_dnd_integration.gd` (10 тестов; hit/miss детерминирован через экстремальное AC, без подмены RNG)
- **Отложено**: live `BattleController` battle-loop wiring (stack/formation-модель vs per-character D&D — архитектурное изменение, нужен playtest); TASK_22 battle UI + TASK_23 character sheet UI (Godot-визуал, не верифицируется headless)
- Полный сьют: **1736/1736 passed, 0 failures** (129 orphans)

### dnd-battle-system — Phase 5: Saving Throws & Death (TASK_19–20)
- `saving_throw.gd` — `DNDSavingThrow`: d20 + ability mod + proficiency, `calculate_dc` (8 + prof + mod + bonus), `ThrowResult` (success/failure/crit-success/crit-failure), `succeeded()`
- `death_saves.gd` — `DNDDeathSaves`: 0 HP → dying, d20 (10+/9−), 3 success = stable, 3 fail = death, nat 20 = +1 HP, nat 1 = 2 fail, `stabilize()` (Medicine), `heal()` (wakes), serialization
- Тесты: `tests/unit/battle/test_dnd_saves.gd` (16 тестов, rigged d20 через наследование от `RandomNumberGenerator`)
- Отложено (Phase 6): integration tests с spells/эффектами

### dnd-battle-system — Phase 4: Special Maneuvers (TASK_16–18)
- `ability_check.gd` — `DNDAbilityCheck`: общий d20 + mod с advantage/disadvantage (contested checks, escape, stealth)
- `grapple.gd` — `DNDGrapple`: contested Athletics vs Athletics/Acrobatics (tie → grappler), speed 0, half speed при перемещении, escape с действием (tie → grappler)
- `shove.gd` — `DNDShove`: contested check (tie → target), PRONE/PUSHED (5 ft), free hand + reach gates
- `condition_manager.gd` — `DNDConditionManager`: 14 условий, data-driven таблица эффектов → merged `Effects`, stacking, duration (`tick()`, −1 = until removed), serialization
- Тесты: `tests/unit/battle/test_dnd_maneuvers.gd` (20 тестов)
- Отложено (Phase 6): per-action runtime effects, UI индикаторы условий, integration tests

### dnd-battle-system — Phase 3: Action Economy (TASK_13–15)
- `action_economy.gd` — `DNDActionEconomy`: 1 action/turn, bonus action (only if source allows), 1 reaction/round (resets at turn start), 10 standard actions enum, validation (no same action twice), `available_actions()`, save/load
- `opportunity_attack.gd` — `DNDOpportunityAttack`: trigger logic (leaves reach, not Disengage, not forced/teleport, has sight + reaction), single attack
- Тесты: `tests/unit/battle/test_dnd_actions.gd` (14 тестов)
- Отложено (Phase 6): per-action runtime effects (Dash/Dodge/Help/Hide/Ready/Search/Use Object), integration tests с живой battle state

### dnd-battle-system — Phase 2: Height & Positioning (TASK_07–10)
- `elevation_system.gd` — `DNDElevationSystem`: дискретные уровни (5-фут. инкременты), set/get, `height_feet()`, `is_high_ground()`, сериализация `to_dict`/`from_dict`
- `height_modifier.gd` — `DNDHeightModifier`: бонусы высокой точки (ranged +1/+2/+3, melee +1/+2), штрафы снизу (ranged −1/−2, melee 0/−1/−2/−3), `range_bonus()`, `describe()`
- `line_of_sight.gd` — `DNDLineOfSight`: 3D LoS (Брезенхэм + интерполяция высоты линии огня), `min_clearance()` для расчёта укрытия
- `cover_calculator.gd` — `DNDCoverCalculator`: 4 уровня укрытия (none/half/three-quarters/full), half = +2 AC/+2 DEX, full = немишень, `describe()`
- Тесты: `tests/unit/battle/test_dnd_height.gd` (20 тестов) — elevation, таблицы бонусов, LoS (стена/через стену/диагональ), укрытия, интеграция с `DNDAttackRoll`
- Отложено (не в height-system spec): TASK_11 vertical movement, TASK_12 falling damage, soft cover от существ, debug-визуализация, creature size в LoS, UI-индикаторы (Phase 6)

### map-generation-improvement — верификация, фиксы, тесты
- Фикс: `MapMountainGenerator` вызывался до `generate_noise()` и не работал — порядок исправлен (`MapGenerator.gd`)
- Фикс: лес давал 1.5% карты вместо 25% — сиды кластеров теперь с любого подходящего биома, spacing 4, убран двойной случайный гейт роста (`MapForestGenerator.gd`)
- Реки — препятствие без моста: `model.bridge_cells` сохраняется `MapRoadGenerator`, `is_walkable()` учитывает мосты и levitation (`MapModel.gd`)
- Pathfinding юнитов: `HeroMovementController` передаёт cost_func через `TerrainCostTable` (ROAD 0.5, RIVER/DENSE_FOREST 2.0); `HexPathfinding.find_path` получил параметр `cost_func`
- Тесты: `tests/unit/world/test_map_generators.gd` (9 тестов) — сток рек, связность дорог, хребты, покрываемость леса, время генерации, рендер, предпочтение дорог, мосты
- Документация: `doc/task/TASK_MAP_GENERATION.md` (порядок генерации, параметры, правила проходимости)

## 2026-02-22

### ui-icons-cursors-improvement — завершение
- `game_theme.tres`: кнопки/панели/слоты на 9-slice `StyleBoxTexture`, стили `Button` (normal/hover/pressed/disabled) и `ProgressBar` (background/fill)
- `ThemeConfig.icon_texture()` — кэшированная загрузка иконок с fallback (`assets/ui/icons/fallback.png`)
- `ResourceRegistry.get_icon()` / `BuildingDefs.get_icon()` — текстуры по id
- UI: ResourceBar, ResourcesPanel, CityScreen, HeroStatusPanel, BattleSpellbookPanel используют PNG-иконки вместо эмодзи
- Тесты: `tests/unit/theme/` (14 тестов) — загрузка, курсоры, кэш, fallback

### dnd-battle-system — Phase 1 + фикс брони
- Фикс: тяжёлая броня (max_dex=0) полностью игнорирует DEX (`scripts/battle/dnd/armor_class.gd`)
- Тесты ядра D&D: `tests/unit/battle/test_dnd_core.gd` (27 тестов)

# Tasks: crisis-content-seasonal-rare-events

> **Status (2026-09-27):** done; Phase 1–5 закрыты.

## 1. Схема и загрузчик

- [x] 1.1 Расширить схему события: `seasons: Array[String]` (пусто = любой), `weight: float` (default 1.0), `rarity: String` (default "common")
  - `DynamicEventData` + `CrisisEventData`: seasons/rarity (+ weight у кризиса);
    helper `_as_string_array`.
- [x] 1.2 Загрузчик: валидация значений сезонов; backward compat — файлы без новых
  полей читаются как раньше
  - `_validate_template`: seasons ⊆ {spring, summer, autumn, winter} → иначе
    push_error + файл пропускается; rarity ∉ {common, rare} → warning + "common".
    Источником сезона выступает `Season.ID` (scripts/world/season.gd) через
    инжектируемый provider (`set_season_provider`), т.к. `WorldSeasons.SEASONS` —
    погодный цикл (clear/drizzle/storm), а не календарный.
- [x] 1.3 Unit-тесты загрузчика: defaults, невалидный сезон → ошибка загрузки
  - `tests/unit/systems/test_event_seasons_weights.gd` (7 тестов схемы/валидации).

## 2. Селектор событий

- [x] 2.1 Фильтр по текущему сезону перед взвешенным выбором
  - `_season_allows` в `get_available_events`/`get_available_crises`;
    неизвестный сезон (без provider) не блокирует — backward compat.
- [x] 2.2 Взвешенный ролл с детерминизмом по seed RNG
  - `select_by_weight(items)` (общая функция для событий и кризисов);
    `rng: RandomNumberGenerator` в системе, `randomize()` в _ready,
    все randf/randi заменены на rng.*.
- [x] 2.3 Unit-тесты: «летнее зимой» невозможно; распределение весов на 10k роллов ±5%
  - `test_event_seasons_weights.gd`: сезонный фильтр (3 теста), детерминизм
    (2), распределение 0.9/0.1 на 10k ±5% (1), пустой пул → null.

## 3. Сезонный контент (≥8)

- [x] 3.1 `event_spring_flood.json` (весной, усиливает crisis_07_flood)
- [x] 3.2 `event_spring_spawn_surplus.json`
- [x] 3.3 `event_summer_drought_risk.json`
- [x] 3.4 `event_summer_caravan_peak.json`
- [x] 3.5 `event_autumn_harvest_boom.json`
- [x] 3.6 `event_autumn_mud_season.json` (распутица: −запасы/−дороги)
- [x] 3.7 `event_winter_deep_frost.json` (усиливает event_10_cold)
- [x] 3.8 `event_winter_starvation.json`
- [x] 3.9 Теги `seasons` у существующих crisis_07_flood (spring), event_02_harvest
  (autumn), event_10_cold (winter)
  - Тесты: `test_seasonal_content_loaded_with_tags`, `test_rare_content_loaded_with_low_weight`,
    `test_existing_events_tagged`; `test_ten_common_events_loaded` обновлён
    (10 → 22 шаблона).

## 4. Редкий контент (≥4, rarity=rare, weight ≤0.05)

- [x] 4.1 `event_rare_comet.json`
- [x] 4.2 `event_rare_eclipse.json`
- [x] 4.3 `event_rare_dragon_sighting.json`
- [x] 4.4 `event_rare_gold_vein.json`
  - Все: weight 0.05, rarity "rare", seasons [] (любой сезон), min_day 40–50.

## 5. Верификация и закрытие

- [x] 5.1 balance_probe: частота кризисов в допуске после добавления контента
  - `tests/unit/systems/test_event_balance_probe.gd` (3 теста): темп кризисов
    идентичен с/без сезонного фильтра (2000 дней, seed 20260927, cooldown-допуск
    [50,100]); редкие наблюдаемы (≥1 за 2000 дней) и не чаще weights-лимита (≤3);
    10k-роллы: доля rare ≈ сумма весов / общий вес ±2%.
- [x] 5.2 Полный прогон зелёный
  - 1851 тест (1830 + 21 новых) | 62 errors + 4 failures = baseline
    (test_spells_json, test_crisis_events — pre-existing). 0 регрессий.
- [x] 5.3 Отметить задачи 2.4/2.5 в `dynamic-world-crisis-system/tasks.md` как DONE-here
  - Архивный tasks.md: 2.4 (4/5 DONE, миграция животных — scope-out фауны),
    2.5 (редкие события DONE, 3 scope-out'а сохранены).
- [x] 5.4 `/opsx-sync` delta crisis-events; архивация цикла
  - `openspec/specs/crisis-events/spec.md` (2 requirements: селектор, схема).

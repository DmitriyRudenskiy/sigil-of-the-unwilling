# Tasks: crisis-content-seasonal-rare-events

> **Status (2026-09-27):** propose готов; apply не начинался. Закрывает scope-out задач 2.4/2.5 из `dynamic-world-crisis-system`.

## 1. Схема и загрузчик

- [ ] 1.1 Расширить схему события: `seasons: Array[String]` (пусто = любой), `weight: float` (default 1.0), `rarity: String` (default "common")
- [ ] 1.2 Загрузчик: валидация значений сезонов против `WorldSeasons.SEASONS`; backward compat — файлы без новых полей читаются как раньше
- [ ] 1.3 Unit-тесты загрузчика: defaults, невалидный сезон → ошибка загрузки

## 2. Селектор событий

- [ ] 2.1 Фильтр по текущему сезону перед взвешенным выбором
- [ ] 2.2 Взвешенный ролл с детерминизмом по seed RNG
- [ ] 2.3 Unit-тесты: «летнее зимой» невозможно; распределение весов на 10k роллов ±5%

## 3. Сезонный контент (≥8)

- [ ] 3.1 `event_spring_flood.json` (весной, усиливает crisis_07_flood)
- [ ] 3.2 `event_spring_spawn_surplus.json`
- [ ] 3.3 `event_summer_drought_risk.json`
- [ ] 3.4 `event_summer_caravan_peak.json`
- [ ] 3.5 `event_autumn_harvest_boom.json`
- [ ] 3.6 `event_autumn_mud_season.json` (распутица: −movement)
- [ ] 3.7 `event_winter_deep_frost.json` (усиливает event_10_cold)
- [ ] 3.8 `event_winter_starvation.json`
- [ ] 3.9 Теги `seasons` у существующих crisis_07_flood, event_02_harvest, event_10_cold

## 4. Редкий контент (≥4, rarity=rare, weight ≤0.05)

- [ ] 4.1 `event_rare_comet.json`
- [ ] 4.2 `event_rare_eclipse.json`
- [ ] 4.3 `event_rare_dragon_sighting.json`
- [ ] 4.4 `event_rare_gold_vein.json`

## 5. Верификация и закрытие

- [ ] 5.1 balance_probe: частота кризисов в допуске после добавления контента
- [ ] 5.2 Полный прогон `run_all.sh` зелёный
- [ ] 5.3 Отметить задачи 2.4/2.5 в `dynamic-world-crisis-system/tasks.md` как DONE-here
- [ ] 5.4 `/opsx-sync` delta crisis-events; архивация цикла

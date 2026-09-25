# Tasks: social-stats-weapon-tech

## 1. Социальные статы (8 статов)

- [x] 1.1 `HeroBuildProfile`: `base_stats` + `int/wis/cha/luk` (дефолт 2); бонусы социальных статов в `hero_races.gd`, `hero_classes.gd`, `hero_cultures.gd` (маг/жрец +wis, плут +luk, лидерские классы +cha, учёные +int — осмысленные, не всем)
- [x] 1.2 `HeroStatsComponent`: сериализация/десериализация 8 статов; миграция старых сейвов (отсутствующие статы → пересчёт из `HeroBuildProfile.get_stats` расы/класса)
- [x] 1.3 UI экрана героя: строки int/wis/cha/luk рядом с боевыми статами
- [x] 1.4 Unit-тесты: у каждого раса/класс есть 8 статов; сейв-миграция; боевой бонус не изменился (get_battle_bonus без социальных статов)

## 2. DeceptionCheck (обман в городе)

- [x] 2.1 Новый `scripts/systems/DeceptionCheck.gd` (статик): `roll(rng, int_, wis, cha, luk, base_pct, trap_dc) -> {deceived, severity, note, discount, revealed}`; формула `clamp(base + (10−int)*4 − max(wis−10, cha−10, luk−10,0)*2, 5, 85)`; wis-предупреждение, luk-спас/раскрытие, cha-скидка
- [x] 2.2 Константы в `GameNumbers`: базы по виду сделки, d20-сложности (10/13/14/16/18/20), диапазоны последствий (4 степени)
- [x] 2.3 Точки вызова: `CityService`/`CityScreen` — покупка дорогого, договор/найм-контракт, сомнительное задание; мелкая торговля ресурсов НЕ проверяется; последствия применяются (цена +10–30%, качество, долг/штраф, кража/репутация)
- [x] 2.4 Unit-тесты: границы 5–85%, компенсация от max, роли wis/cha/luk, 4 степени, детерминизм по seed

## 3. LeadershipCheck (харизма: население и отряд)

- [x] 3.1 `GameNumbers.SOCIAL_CHA_TABLES`: иммиграция-modifier (−50%…+50%), max_stacks (1…7), качество найма; новый `scripts/systems/LeadershipCheck.gd` (статик): `immigration_modifier(cha)`, `max_army_stacks(cha)`, `recruit_check(rng, cha, rep, offers, difficulty) -> outcome`, `recruit_quality(cha)`
- [x] 3.2 `ReputationSystem.process_migration`: множитель иммиграции от cha героя города + доп. отток при cha ≤ 5
- [x] 3.3 `CityService.recruit_military`: cap от `max_army_stacks(cha)` (min 3), проверка найма по d20, качество стека по `recruit_quality`; провалы: отказ/слухи (репутация −)/крит-инцидент
- [x] 3.4 Unit-тесты: таблицы cha (все пороги), найм (успех/отказ/слухи/крит), иммиграция (множитель, отток), cap отряда

## 4. WeaponTechService (тиры из технологий)

- [x] 4.1 `WeaponCatalog` (статик-данные): 5 тиров — материалы (вес/прочность/урон) и изделия (дубина→рун. меч), `Artifact.tier: int = 1` в каталоге
- [x] 4.2 Новый `scripts/systems/WeaponTechService.gd`: `city_weapon_tier(city)` из зданий (smithy lvl + уголь/руда/сталь/редкие), `max(fallback по уровню, tech_tier)`; `forge(rng, item_id, stats) -> {artifact, quality, notes}` (wis-подделка, luk-удача, int-изучение, cha-кузнец)
- [x] 4.3 `CityService.recruit_military`: тир стека из `city_weapon_tier`; найм кузнеца через `LeadershipCheck`
- [x] 4.4 Unit-тесты: тир-лестница (без печи нет железа; lvl 9 без технологий не даёт железо выше fallback), ковка (качество по статам), детерминизм

## 5. Связь с attribute-weight-system

- [x] 5.1 Веса артефактов из `WeaponCatalog` (дерево 1.0, камень 1.5, железо 2.0, сталь 1.8, редкое 2.5) при регистрации в `ArtifactRegistry`
- [x] 5.2 Проверить непересечение с `attribute-weight-system`: LoadCalculator-имена, формат сейва артефактов

## 6. UI и видимость

- [x] 6.1 Город: шанс обмана/результат проверки, тир технологий, качество найма — строки в CityScreen
- [x] 6.2 Отряд: текущий cap и причина отказа при наборе

## 7. Регрессия и калибровка

- [x] 7.1 Все GdUnit4-тесты зелёные (старые тесты найма/миграции перестроить под cha)
- [x] 7.2 MCP `test_balance_probe.py`: 60 ходов RUNNING на seed 20260913; при деградации — калибровка
- [x] 7.3 Поправка в `attribute-weight-system/design.md` (D1: уточнение про 4 социальных стата) + `openspec validate` + commit + push

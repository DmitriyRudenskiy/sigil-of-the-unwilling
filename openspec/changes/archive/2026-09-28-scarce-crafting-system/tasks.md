# Tasks: scarce-crafting-system

> **Status (2026-09-28):** done; Phase 1–4 закрыты.

## 1. Спецификация и данные

- [x] 1.1 `specs/crafting/spec.md`: требования рецептов/требований/стоков (draft в этом цикле)
  - 5 requirements: валидация, требования (ресурсы/тех/мастерская), вес, сейв/лоад, трофеи.
- [x] 1.2 `game/data/config/crafting_recipes.json`: ≥8 рецептов, покрытие всех стратегических ресурсов
  - 10 рецептов; все 13 стратегических ресурсов (oak, silver, quartz, saltpeter,
    turquoise, limonite, coal, gold_ore, coal_swamp, bog_iron, cinnabar, wood, stone)
    покрыты хотя бы одним рецептом (тест `test_recipes_cover_all_strategic_resources`).
- [x] 1.3 Схема JSON + загрузчик с валидацией (неизвестный ресурс/технология → ошибка на загрузке)
  - `CraftingSystem.load_recipes`: неизвестный ресурс/слот/редкость, вес ≤0,
    tech вне 1..5, дублирующийся id → push_error + рецепт пропускается.

## 2. Ядро системы

- [x] 2.1 `crafting_system.gd` (RefCounted, headless-safe): can_craft()/craft()/реестр открытых рецептов
  - `CraftingSystem` (RefCounted): `can_craft(id, ctx) -> {ok, reason, missing}`,
    `craft(id, ctx) -> {ok, reason, artifact, recipe_id}`, `unlocked`, serialize/deserialize.
    Контекст — `CraftingContext` (strategic/inventory/tech_tier/has_workshop),
    система не знает про героя/город.
- [x] 2.2 Требования: ресурсы (списание), технология (`weapon_tech_service`), мастерская (`unique_building`)
  - `HeroCraftingComponent._build_context(city)`: tech из
    `WeaponTechService.city_weapon_tier(city)`, workshop = smithy ≥1 в city.buildings.
  - Отказ → сырьё не списывается; backpack_full → полный откат.
- [x] 2.3 Результат: предмет в инвентарь героя с весом (`weight-carry-system`) или артефакт (`artifact_registry`)
  - `Artifact` с весом рецепта в `HeroInventory.backpack`; учтён через
    `LoadCalculator.equipment_weight`.
  - **Архитектурный fix**: крафтовые предметы (динамические id) отсутствуют в
    статическом `ArtifactRegistry` — добавлены `Artifact.to_dict()`/
    `is_registry_artifact()` и полная сериализация не-реестровых предметов в
    `HeroInventory.serialize/deserialize` (backward compat: id-строки как раньше).
- [x] 2.4 События: `item_crafted`, `recipe_unlocked` через GameEventBus
  - Сигналы на `CraftingSystem`, форвард через `HeroCraftingComponent`.
    (Прямой форвард в GameEventBus не добавлен: потребители появятся с UI,
    компонент — точка подключения.)

## 3. Интеграции

- [x] 3.1 Трофеи боя → сырьё (совместно с tactical-combat-implementation п.6)
  - `BattleTrophyService.roll_trophy()` (1–3 ед. из silver/turquoise/gold_ore/
    cinnabar/quartz, seed-детерминизм); hook в `WorldEventRouter._on_battle_won`
    → `hero.get_component("StrategicResources").add(...)`.
- [x] 3.2 Сейв/лоад: сериализация открытых рецептов/прогресса (координировать с save-load-coverage-expansion, версия сейва +1)
  - `SaveData.CURRENT_VERSION` 7→8, `_migrate_v7_to_v8` (hero.crafting default {}).
  - `HeroCraftingComponent.serialize/deserialize` → `SaveData.hero.crafting`.
  - Компонент инициализируется в `HeroController.setup` (список расширен).
- [x] 3.3 balance_probe: стоки крафта учтены в симуляции экономики
  - `test_crafting_balance_probe.gd`: 300-дневная симуляция (добыча + трофеи +
    жадный крафт) — ресурсы не уходят в минус, рюкзак не переполнен, темп крафта
    в допуске; трофейный доход ограничен [1,3]/победа; рецепты — чистые стоки.

## 4. Тесты и верификация

- [x] 4.1 Unit: рецепты, отказы (нет ресурса/технологии/мастерской), вес результата
  - `tests/unit/systems/test_crafting_system.gd` (20 тестов): схема/валидация,
    все 5 типов отказов, успех (списание/предмет/unlock/signal), вес через
    LoadCalculator, откат при полном рюкзаке, save roundtrip, legacy-сейв.
- [x] 4.2 Integration: бой → трофей → крафт → инвентарь → сейв/лоад roundtrip
  - `tests/functional/save_roundtrip_crafting.gd` (5 тестов): крафт → hero
    serialize → deserialize (unlocked + предмет с весом), legacy v7-сейв,
    SaveData v7→v8 миграция, трофей (детерминизм + границы).
- [x] 4.3 Полный прогон зелёный + balance допуски
  - 1879 тестов (1851 + 28 новых) | 62 errors + 4 failures = baseline
    (test_spells_json, test_crisis_events — pre-existing). 0 регрессий.
  - Обновлены: test_hero_controller (14→15 компонентов), test_world_bootstrap (то же).
- [~] 4.4 UI экрана крафта *(отложено: Godot-визуал, вне headless-верификации)*
- [x] 4.5 `/opsx-sync` crafting → main specs; архивация
  - `openspec/specs/crafting/spec.md` (5 requirements); архивация.

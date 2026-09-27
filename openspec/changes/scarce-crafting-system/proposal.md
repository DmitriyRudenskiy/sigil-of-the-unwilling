# Proposal: scarce-crafting-system

**Status:** Open (propose)
**Supersedes scope-out of:** `dynamic-ecosystem-scarce-crafting-overhaul` (статус изменён на `partially-completed`: экосистема/дефицит ресурсов сделаны, крафт — нет)

## Why

Аудит 2026-09-27 подтвердил: в `game/scripts/` **нет системы крафта** (`grep crafting|craft_` → только упоминания артефактов). Изменение `dynamic-ecosystem-scarce-crafting-overhaul` закрывало только экосистемную часть (resource chains, дефицит, `resource_chain_service.gd`, `resource_node_manager.gd`). Обещанный им «редкостный крафт» остался незакрытым циклом обещаний — выносим в отдельное изменение.

## What Changes

- **NEW capability `crafting`:** рецепты из дефицитных стратегических ресурсов; ограничение редкости (найдённые месторождения/трофеи, не рынок); привязка к hero-логистике (вес предметов — `weight-carry-system`) и городу (мастерские как здания `city-tech-tree`).
- Интеграции: `artifact_registry.gd` (созданные артефакты), `weapon_catalog.gd`/`weapon_tech_service.gd` (технологические требования), трофеи боя (пост-бой лут → сырьё).
- Данные: `game/data/config/crafting_recipes.json`.
- UI экрана крафта — откладывается (headless-верификация только логики).

## Capabilities

### New Capabilities
- `crafting`: рецепты, требования (ресурсы/технологии/герой), результат в инвентарь/артефактную палату, деградация источников сырья.

### Modified Capabilities
- `world-threat-rings` / экономика: добыча редких ресурсов ограничена узлами карты (уточнение при sync).

## Impact

- Новые: `game/scripts/systems/crafting_system.gd`, `game/data/config/crafting_recipes.json`
- Затрагиваемые: `hero_resources*`, `artifact_registry.gd`, `unique_building.gd` (мастерская), `world_state_serializer.gd` (сейв крафта — координировать с `save-load-coverage-expansion`)
- Баланс: новые стоки ресурсов → обязательный прогон `balance_probe`
- Тесты: unit (рецепты/стоимость/ограничения), integration (крафт → инвентарь → вес)

## Acceptance Criteria

- [ ] 1. ≥8 рецептов по всем стратегическим ресурсам, валидируются из JSON
- [ ] 2. Крафт невозможен без технологий/ресурсов/мастерской — тесты отказов
- [ ] 3. Созданные предметы попадают в инвентарь с корректным весом
- [ ] 4. balance_probe: экономика не ломается (избыточных стоков/источников нет)
- [ ] 5. Сейв/лоад сохраняет прогресс крафта (совместимо с save-migration)
- [ ] 6. Спецификация синхронизирована, цикл заархивирован

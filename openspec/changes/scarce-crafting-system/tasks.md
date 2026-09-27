# Tasks: scarce-crafting-system

> **Status (2026-09-27):** propose готов; apply не начинался.

## 1. Спецификация и данные

- [ ] 1.1 `specs/crafting/spec.md`: требования рецептов/требований/стоков (draft в этом цикле)
- [ ] 1.2 `game/data/config/crafting_recipes.json`: ≥8 рецептов, покрытие всех стратегических ресурсов
- [ ] 1.3 Схема JSON + загрузчик с валидацией (неизвестный ресурс/технология → ошибка на загрузке)

## 2. Ядро системы

- [ ] 2.1 `crafting_system.gd` (RefCounted, headless-safe): can_craft()/craft()/реестр открытых рецептов
- [ ] 2.2 Требования: ресурсы (списание), технология (`weapon_tech_service`), мастерская (`unique_building`)
- [ ] 2.3 Результат: предмет в инвентарь героя с весом (`weight-carry-system`) или артефакт (`artifact_registry`)
- [ ] 2.4 События: `item_crafted`, `recipe_unlocked` через GameEventBus

## 3. Интеграции

- [ ] 3.1 Трофеи боя → сырьё (совместно с tactical-combat-implementation п.6)
- [ ] 3.2 Сейв/лоад: сериализация открытых рецептов/прогресса (координировать с save-load-coverage-expansion, версия сейва +1)
- [ ] 3.3 balance_probe: стоки крафта учтены в симуляции экономики

## 4. Тесты и верификация

- [ ] 4.1 Unit: рецепты, отказы (нет ресурса/технологии/мастерской), вес результата
- [ ] 4.2 Integration: бой → трофей → крафт → инвентарь → сейв/лоад roundtrip
- [ ] 4.3 Полный прогон зелёный + balance допуски
- [ ] 4.4 UI экрана крафта *(отложено: Godot-визуал, вне headless-верификации)*
- [ ] 4.5 `/opsx-sync` crafting → main specs; архивация

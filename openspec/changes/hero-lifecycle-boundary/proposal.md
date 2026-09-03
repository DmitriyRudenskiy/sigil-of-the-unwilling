---
description: "Граница HeroLifecycleSystem: реестр потребителей вместо IHeroConsumer, указатель активного героя в системе (без обратного хода в фасад), единый путь установки героя."
---

## Why

`world-controller-decoupling` R1 извлёк логику смерти/преемственности в `HeroLifecycleSystem`
(WorldController.gd — 376 строк, цель ≤400 достигнута), но границу не закрыл:

- `_install_hero` (HeroLifecycleSystem.gd:306–337) жёстко переподключает 9 потребителей:
  `battle_coordinator.hero`, `interaction_controller.hero`, `enemy_proc._hero`,
  `input_controller.hero`, `shortcuts._hero`, `event_router.hero` +
  `_connect_hero_signals()`, `ui_manager._hero` + `ui.reattach_hero(hero, camera)`,
  `inventory_screen.set_hero()`, `city_screen.hero`. Новый потребитель = правка этой
  функции; забытый потребитель = freed-референс и краш в следующем кадре.
- Система ходит назад в фасад за указателем героя: `_hero_ptr()` → `world.get_hero()`,
  `_set_hero_ptr()` → `world.set_hero()` (HeroLifecycleSystem.gd:344–352) — с guard'ом
  `world.has_method("get_hero")`, который существует ровно потому, что система должна
  работать и без фасада (отсоединённые тесты).
- Указатель живёт в `WorldController._hero` (WorldController.gd:22, 18 обращений),
  а система лишь читает/пишет его через фасад — циклическая facade↔subsystem связь.
- Установка асимметрична: первый герой — `WorldController.set_hero` (WC.gd:253,
  из bootstrap), последующие — `HeroLifecycleSystem._install_hero` (2 вызова в системе).
- `setup()` принимает 12 аргументов по позициям (HeroLifecycleSystem.gd:32–46).
- Спек umbrella требует `IHeroConsumer.on_hero_changed(old, new)`, но Design D его
  отложил: «перевод на IHeroConsumer ломает _install_hero в 8+ местах и 3 тестовых
  файла» (test_hero_survival.gd, test_legend_chronicle.gd,
  test_worldcontroller_succession_wiring.gd).

## Proposed Change

1. **Реестр потребителей вместо IHeroConsumer.** `HeroLifecycleSystem.register_hero_consumer(Callable)`
   — однострочные лямбды, зарегистрированные координатором при setup. `_install_hero` =
   в дерево + `hero.setup` + позиция + прогон реестра в порядке регистрации.
   Интерфейс, конформные классы и конформные тесты не вводим.
2. **Указатель активного героя владеет система.** `HeroLifecycleSystem.active_hero` —
   единственный источник истины; `WorldController.get_hero()/set_hero()` становятся
   делегатами. Обратные вызовы `world.get_hero()/set_hero()` из системы удаляются;
   `world: Node2D` остаётся только как родитель для `add_child` (герой, экраны).
3. **Единый путь установки.** Первый герой ставится тем же `install_hero` системы;
   `WorldController.set_hero` — тонкий делегат для bootstrap.
4. **Сверхзапись в umbrella:** требование IHeroConsumer в спеке
   `world-controller-decoupling` помечается замещённым (реестр, этот change).

## Scope

- **In:** `HeroLifecycleSystem.gd` (реестр, `active_hero`, `install_hero`),
  `WorldController.gd` (регистрация 9 потребителей, делегирование get/set_hero,
  замена прямых `_hero` на `get_hero()`), 3 затронутых тестовых файла,
  артефакты umbrella (пометка о замещении).
- **Out:** новая механика героя, переезд UI-экранов, изменение порядка инициализации
  подсистем, типизация остальных полей системы (umbrella R3).

## Dependencies

- `world-controller-decoupling` R1 (извлечение) — готово; этот change закрывает его
  R1.2/R1.3 (IHeroConsumer → реестр) и снимает цикл facade↔subsystem.
- `lifecycle-test-strategy` — рекомендуется после: реестр упрощает L2-стабы
  (UI/router подменяются зарегистрированными фейковыми Callable).

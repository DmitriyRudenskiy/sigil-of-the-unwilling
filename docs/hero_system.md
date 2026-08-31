# Система героя

Герой — центральный игровой объект на карте мира: перемещается по клеткам,
носит армию, управляет ресурсами/инвентарём/магией, тратит очки времени.

**Корневой класс:** `entities/HeroController.gd` (`class_name HeroController`,
`extends Node2D`). Это **тонкий фасад** — он не хранит состояние сам, а
композирует подсистемы и пробрасывает вызовы/сигналы наружу.

## Архитектура: фасад + подсистемы

`HeroController` в `_ready()` создаёт и добавляет как дочерние ноды:

| Подсистема | Класс | Ответственность |
| --- | --- | --- |
| Движение | `HeroMovementController` (465 стр.) | Pathfinding, очки движения, стоимость рельефа |
| Армия | `HeroArmyController` (72) | Состав армии, сериализация в бой, применение результатов |
| Ресурсы | `HeroResources` (56) | Подбор ресурсов на карте, суточные эффекты |
| Визуал | `HeroVisualController` | Аватар, поворот, отрисовка пути/маркеров, idle-анимация |
| Магия | `HeroMagic` (107) | Мана, школы,_spellbook_, стоимость заклинаний |

**Цепочки ресурсов (Addendum 10):**

| Подсистема | Класс | Ответственность |
| --- | --- | --- |
| Время | `data/TimeSystem.gd` | Очки времени суток, трата на движение |
| Навыки | `HeroSkills` (49) | Уровни 0–3: nature_sense, keen_eye, navigation, geology, alchemy |
| Инструменты | `HeroTools` (107) | Отдельный 8-слотный инвентарь: лопата, кирка, телега, защита от кожи, сеть |
| Стратегические | `HeroStrategicResources` (69) | Дерево/камень и т.д., привязка к `ResourceRegistry` |

### Почему фасад, а не наследование

Подсистемы общаются с фасадом через **сигналы**, а не через обратные ссылки
`_parent`. Например, `HeroMovementController` эмитит `facing_changed`,
`move_requested`, `request_show_marker` и т.д. — фасад подписывается и делегирует
`HeroVisualController`. Это убирает циклические зависимости между классами.

Фасад сохраняет и **backward-compat проксирование** для старых вызывающих:
`mana_current`, `mana_max`, `magic_schools`, `spellbook`.

## Движение (`HeroMovementController`)

- **Pathfinding** — Dijkstra по клеткам, стоимость шага зависит от рельефа
  (`_terrain_cost(cell)`).
- **Очки движения — float** (`move_points`, старт 10.0), суточные восстанавливаются
  в конце хода с учётом модификаторов инвентаря (`get_daily_movement_points`).
- **`move_to_cell(cell) -> bool`** — если цель дальше оставшихся очков, герой идёт
  к ней в сторону, пока хватает очков; если цель занята вражеским стеком — подходит
  к нему вплотную (**бой триггерится контактом**, на клетку врага герой не вступает).
- **Reach-preview** — `can_reach(cell)` считается *до* начала движения;
  `reach_preview_changed` даёт маршрут и дистанцию для отрисовки.
- **Headless-safe** — tween-анимация позиции в `_tween_to` в headless-режиме
  вызывает callback сразу (без рендера).

## Армия (`HeroArmyController`)

- Армия — `Array[UnitStack]`. Реестр юнитов (`UnitRegistry`) **инжектируется**
  через `setup(registry)` (fallback → `ServiceContainer` → autoload); сам фасад
  не держает реестр, поэтому классы остаются тестируемыми.
- **В бой:** `get_army_for_battle() -> Array[UnitStack]` — перенос состава в битву.
- **Из боя:** `apply_battle_results(surviving_army)` — восстановление после боя.
- Сериализация состава (`serialize`/`deserialize`) для сохранения мира.

## Магия (`HeroMagic`)

- Мана: `mana_current`/`mana_max`, школы — `{"air","fire","water","earth"}`.
- `_spellbook` — `Array[StringName]` (id заклинаний). `knows/learn/forget`.
- **`can_cast`/`get_mana_cost`** учитывают `anti_magic` и `spellbinders_hat`.
- Восстановление: `tick_restore(knowledge)` — ежедневно, зависит от навыка
  Knowledge; `restore_full()` — полное.

## Ресурсы и цикл хода

`HeroResources` подбирает ресурсы на карте (`pickup_resource`) и применяет
суточные эффекты. **`end_turn()`** фасадa:

1. `_apply_daily_resource_effects()` — суточные золота/ресурсов + авто-дерево/камень.
2. `_restore_mana()` — мана через `magic.tick_restore(knowledge)`.
3. `_reset_time_and_movement()` — сброс времени, восполнение ОД.

## Боевые бонусы героя

`get_battle_bonus()` складывает базовые статы (`stats`: attack/defense/spell_power/
knowledge) и модификаторы экипировки (`inventory.get_total_modifiers()`), добавляя
`luck` и `morale`. `has_artifact_effect(effect)` — проверка special-effect из
инвентаря.

## Инициализация в мире

Полный конвейер в `world/WorldBootstrap.gd`:

1. `_create_hero()` — `HeroController.new()`, добавляется в дерево.
2. `_init_hero()` — `hero.setup(map_gen)` (инъекция `UnitRegistry` в армию и
   `ResourceRegistry` в стратегические ресурсы), затем `deserialize(save)` — если
   загружено сохранение.

Фабрика `ui/HeroModelFactory.gd` собирает «модель» героя (имя/статы/экипировка)
для модельных экранов (стартовое меню, `ArtifactInventoryScreen`).

## Сериализация

`serialize() -> Dictionary` / `deserialize(Dictionary)` сохраняют **всё** состояние
героя: клетка, очки движения, статы, ресурсы, армия, инвентарь, магия, навыки,
инструменты, стратегические ресурсы, потраченные MP за день. Источник надёжности
для `WorldPersistence` и тестов (`test_hero_serialize.gd`).

## Сигналы фасадa

`hero_moved`, `hero_entered_village`, `movement_points_changed`,
`resources_changed`, `path_previewed`, `strategic_resources_changed`,
`skills_changed`, `tools_changed`, `time_changed` — для реакционного UI
(`ArmyPanel`, `WorldUIManager`).

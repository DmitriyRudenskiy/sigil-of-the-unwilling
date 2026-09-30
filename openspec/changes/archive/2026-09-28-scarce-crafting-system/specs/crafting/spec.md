# Spec Delta: crafting (ADDED)

## ADDED Requirements

### Requirement: Рецепты крафта SHALL валидироваться при загрузке
`CraftingSystem` загружает рецепты из `game/data/config/crafting_recipes.json`. Каждый рецепт: `id`, `display_name`, `slot` (из `Artifact.Slot`), `resources` (карта `StringName -> int`, значения >0, ключи — валидные id из `ResourceRegistry`), `requires_tech` (1..5), `requires_workshop` (bool), `weight` (>0), `rarity` (minor/major/relic). Неизвестный ресурс/слот/отрицательный вес → push_error, рецепт пропускается; остальные загружаются.

#### Scenario: Валидный файл
- **WHEN** файл содержит N корректных рецептов
- **THEN** `load_recipes` возвращает N, все рецепты доступны в `get_recipes()`

#### Scenario: Неизвестный ресурс
- **WHEN** рецепт ссылается на ресурс вне ResourceRegistry
- **THEN** push_error с id рецепта, рецепт не добавляется, остальные читаются

#### Scenario: Повторяющийся id
- **WHEN** два рецепта имеют одинаковый `id`
- **THEN** push_error, второй пропускается

### Requirement: Крафт SHALL требовать ресурсы, технологию и мастерскую
`can_craft(recipe_id, ctx)` проверяет: (1) сырьё в стратегических ресурсах героя (полный набор), (2) `tech_tier >= requires_tech`, (3) `requires_workshop` → в городе героя есть кузница (smithy) ≥1. `craft` списывает сырьё и кладёт `Artifact` (с весом) в рюкзак героя. При любом отказе сырьё не списывается.

#### Scenario: Не хватает сырья
- **WHEN** ресурса X нет или его меньше требуемого
- **THEN** `can_craft` → `{ok: false, reason: "missing_resources"}`, `craft` ничего не списывает

#### Scenario: Нет технологии
- **WHEN** `ctx.tech_tier < requires_tech`
- **THEN** `can_craft` → `{ok: false, reason: "tech_required"}`

#### Scenario: Нет мастерской
- **WHEN** `requires_workshop` и `ctx.has_workshop == false`
- **THEN** `can_craft` → `{ok: false, reason: "workshop_required"}`

#### Scenario: Рюкзак полон
- **WHEN** инвентарь не принимает предмет
- **THEN** `craft` → `{ok: false, reason: "backpack_full"}`, сырьё возвращается

#### Scenario: Успех
- **WHEN** все требования выполнены
- **THEN** сырьё списано, `Artifact` с весом рецепта в рюкзаке, рецепт помечен unlocked, эмитится `item_crafted`

### Requirement: Результат крафта SHALL иметь вес
Созданный `Artifact` наследует `weight` из рецепта; суммарный вес рюкзака/экипировки (через `LoadCalculator.equipment_weight`) увеличивается на этот вес.

#### Scenario: Вес учтён
- **WHEN** герой с пустым рюкзаком крафтит предмет весом W
- **THEN** `LoadCalculator.equipment_weight(inventory) == W`

### Requirement: Прогресс крафта SHALL переживать сейв/лоад
`CraftingSystem.serialize()/deserialize()` сохраняет набор unlocked-рецептов; через компонент героя попадает в `SaveData.hero`. Старый сейв без ключа → пустой набор (backward compat). Версия сейва +1.

#### Scenario: Roundtrip
- **WHEN** герой разблокировал 3 рецепта, сейв, лоад
- **THEN** все 3 рецепта unlocked, инвентарь с предметами сохранён

#### Scenario: Старый сейв
- **WHEN** сейв v7 (без ключа crafting) загружается
- **THEN** unlocked пуст, крафт доступен с нуля, ошибки нет

### Requirement: Трофеи боя SHALL давать стратегическое сырьё
Победа в бою (GameEventBus.battle_won) даёт герою 1–3 единицы редкого стратегического ресурса (список трофеев: silver, turquoise, gold_ore, cinnabar, quartz) — детерминированно по seed. Это единственный «не-узел» источник редких ресурсов.

#### Scenario: Победа даёт трофей
- **WHEN** hero побеждает в бою
- **THEN** в стратегических ресурсах героя прибавляется ≥1 единица ресурса из списка трофеев

#### Scenario: Детерминизм
- **WHEN** два прогона с одинаковым seed
- **THEN** последовательность трофеев идентична

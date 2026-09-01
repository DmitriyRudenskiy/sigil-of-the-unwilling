## Context

`Follower.gd` (city-in-world) — именованный последователь героя с заготовками
`race = &"human"` и `path = &"unaligned"`. При найме (`FollowerSystem.recruit`) даётся
имя + черты из `TraitRegistry`, но раса/класс не определяются. Текущая модель героя
(`HeroSkills`, `HeroMagic`, `TraitRegistry`, `Character`/потребности) остаётся
неизменной — мы её **дополняем** модификаторами от расы/класса, а не перестраиваем под
полные Pathfinder-статы (BAB, hit dice, спасброски).

Данные Pathfinder извлечены в `game/assets/data/races_classes.json` (6 рас, 16 классов × 4
архетипа, +bloodlines/domains/prestige/feats как данные для будущих циклов).

## Design

**Data-first, JSON-driven** — по образцу `SpellRegistry`/`TemplateBootstrap`. Всё
содержимое таблицы читается из JSON, код не меняется при расширении.

### Модели данных

- **`RaceDef.gd`** (`RefCounted`, class_name): `id: StringName`, `name: String`,
  `size: String`, `speed: int`, `ability_adjustments: Dictionary` (`StringName`→`int`,
  напр. Elf `{DEX:2, INT:2, CON:-2}`), `traits: Array[String]`, `subraces: Array[Dictionary]`
  (`{id,name}`). Методы `to_dict()` / `from_dict()`.
- **`ClassDef.gd`** (`RefCounted`, class_name): `id: StringName`, `name: String`,
  `hit_die: int`, `bab: String`, `saves: Dictionary`, `skill_points: int`,
  `class_skills: Array[String]`, `spellcasting: Dictionary` (пустой для незалинателей),
  `class_resources: Array[Dictionary]`, `features: Array[String]`,
  `archetypes: Array[Dictionary]`. Методы `to_dict()` / `from_dict()`,
  `is_spellcaster() -> bool`, `spellcasting_ability() -> String`.

### Реестр

- **`RaceClassRegistry.gd`** (`RefCounted`, class_name, lazy load):
  - грузит `res://assets/data/races_classes.json` один раз (`ensure()`);
  - `_races: Dictionary` (id→`RaceDef`), `_classes: Dictionary` (id→`ClassDef`);
  - `get_race(id)` / `get_class(id)`, `all_races()` / `all_classes()`,
    `count_races()` / `count_classes()`;
  - `pick_race(rng)` / `pick_class(rng)` — равномерный взвешенный выбор (веса = 1,
    легко расширить до весов по редкости);
  - `pick_archetype(class_def, rng)` — выбор архетипа из `class_def.archetypes`;
  - подсистемы (bloodlines/domains/prestige/feats) доступны как данные
    (`get_bloodline(id)` и т.п.), но при найме не назначаются.

### Интеграция с Follower

- `Follower.race: StringName` ← одна из 6 (был `&"human"`);
- `Follower.path: StringName` ← один из 16 (был `&"unaligned"`);
- `Follower.archetype: StringName = &""` (пусто = базовый класс);
- `Follower.stat_modifiers: Dictionary` ← `ability_adjustments` расы
  (`StringName`→`int`);
- `Follower.abilities: Array[StringName]` ← `features` класса + `traits` расы
  (как подписи способностей; мапия на эффекты — в будущих циклах);
- сериализация/десериализация обновлены (новые поля сохраняются);
- `describe()` выводит: `Имя (Раса, Класс, [Архетип], черты)`.

### FollowerSystem.recruit

1. выбрать расу (`pick_race`), класс (`pick_class`), архетип (`pick_archetype`);
2. вычислить `stat_modifiers` (раса) и `abilities` (класс + раса);
3. собрать `Follower` с назначенными `race`/`path`/`archetype`/`stat_modifiers`/`abilities`.

### Grounding facts

- `world/WorldBootstrap.gd:125` `_create_hero` — НЕ меняется (герой остаётся без расы/класса;
  раса/класс — свойство последователей).
- `demographics/TraitRegistry.gd` — черты последователя остаются как есть.
- `game/scripts/entities/Follower.gd` / `FollowerSystem.gd` — точки интеграции.
- `CityScreen.gd:216` `hire_pressed()` — вызывает `recruit` (точка входа UI, отдельный цикл).

## Risks / Trade-offs

- **Модификаторы vs новые статы.** Мы не строим BAB/hit dice/спасброски под Pathfinder —
  это сломало бы баланс текущей модели. Раса/класс дают модификаторы, применяемые в
  будущих циклах.
- **Охват данных.** Полная таблица (6 × 16 × 4) велика для баланса; этот цикл задаёт
  механизм и данные, тонкая настройка весов/способности — в следующих циклах.
- **Пересечение с городом-миром.** `CityScreen.gd` сейчас в WIP (Parse Error, отдельная
  тема); интеграция только через публичный API `FollowerSystem`, без правки WIP-файла.

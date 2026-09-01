---
description: "Матрица рас и классов по Pathfinder (6 рас × 16 классов × 4 архетипа) для именованных последователей города: раса/класс/архетип + модификаторы, данные для будущих циклов."
---

## Why

Последователи героя (`Follower`, цикл «город в мире») сейчас несут только **заготовки**:
`race = &"human"` («заготовка до матрицы рас-классов») и `path = &"unaligned"`
 («заготовка до системы пути героя»). При найме (`FollowerSystem.recruit`) последователю
даётся имя и черты, но раса и класс не назначаются — все последователи идентичны по
«рождению». Это фундаментальный пробел: нет ни расы, ни класса, ни комбинации, из которой
вытекает сборка последователя.

Данные Pathfinder: Kingmaker (9 рас, 16 классов × 4 архетипа, bloodlines, domains,
prestige_classes, feats) уже извлечены в `game/assets/data/races_classes.json`. В матрицу
идут **6 рас** (Half-Elf и Half-Orc не добавляем).

## What Changes

- **6 рас** (Aasimar, Dwarf, Elf, Gnome, Halfling, Human) с расовыми
  модификаторы характеристик (`ability_adjustments`) и расовыми способностями (`traits`).
- **16 классов** (Alchemist, Barbarian, Bard, Cleric, Druid, Fighter, Inquisitor,
  Kineticist, Magus, Monk, Paladin, Ranger, Rogue, Sorcerer, Wizard, Witch) × **4
  архетипа** каждый — с hit die, спасбросками, очками/навыками, классовыми
  способностями (`features`), ресурсами (`class_resources`), признаком заклинателя
  (`spellcasting`).
- **Матрица**: `RaceClassRegistry` хранит расы и классы, даёт полный перебор
  6 × 16 × 4 (раса × класс × архетип) и взвешенный выбор при найме.
- **Follower** получает реальную `race`, `path` (класс), `archetype`, а также
  вычисленные **модификаторы**: `stat_modifiers` (расовые модификаторы характеристик)
  и `abilities` (классовые способности + расовые особенности).
- **Модификаторы, а не новые статы.** Текущая система (`HeroSkills`, `HeroMagic`,
  `TraitRegistry`, `Character`/потребности) **не переписывается** — раса/класс дают
  модификаторы к характеристикам/навыкам, которые применяются в будущих циклах.
- **Подсистемы** (bloodlines, domains, prestige_classes, feats) хранятся в JSON и
  доступны через реестр, но **не назначаются** при найме (это выбор подкласса → отдельный
  UI-цикл).

## Capabilities

### New Capabilities
- `race-class`: data-driven матрица рас и классов (6 рас × 16 классов × 4 архетипа),
  реестр `RaceClassRegistry`, назначение расы/класса/архетипа последователю и
  вычисление модификаторов (модификаторы характеристик от расы, способности от класса).

### Modified Capabilities
- (нет — существующие поведения `Follower`/`FollowerSystem` расширяются, не переписываются;
  `HeroSkills`/`HeroMagic`/`TraitRegistry` не изменяются.)

## Impact

- `game/assets/data/races_classes.json` — новый файл данных (6 рас, 16 классов × 4
  архетипа, +bloodlines/domains/prestige/feats).
- `game/scripts/data/RaceDef.gd`, `ClassDef.gd` — модели данных.
- `game/scripts/data/RaceClassRegistry.gd` — загрузчик из JSON, реестр, взвешенный выбор.
- `game/scripts/entities/Follower.gd` — поля `race`/`path`/`archetype`/`stat_modifiers`/`abilities`,
  сериализация, `describe()`.
- `game/scripts/entities/FollowerSystem.gd` — найм с назначением расы/класса/архетипа и
  вычислением модификаторов.

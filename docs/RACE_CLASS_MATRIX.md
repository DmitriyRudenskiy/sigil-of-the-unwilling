# Матрица рас и классов (Follower)

Data-driven матрица рас/классов для последователей (Follower) на основе Pathfinder 1e.
Заменяет заготовки `race="human"` / `path="unaligned"` на реальные данные.

## Данные

`game/assets/data/races_classes.json` — единый источник:
- **6 рас**: Aasimar, Dwarf, Elf, Gnome, Halfling, Human
  (Half-Elf и Half-Orc намеренно исключены).
- **16 классов × 4 архетипа**.
- Подсистемы: bloodlines, domains, prestige_classes, feats.

Валидировать JSON:
```bash
python3 -c "import json; json.load(open('game/assets/data/races_classes.json'))"
```

## Компоненты

| Класс | Назначение |
|-------|-----------|
| `RaceDef.gd` (RefCounted) | Расы: `id, name, size, speed, ability_adjustments, traits, subraces`. `to_dict()`/`from_dict()`. |
| `ClassDef.gd` (RefCounted) | Классы: `hit_die, bab, saves, skills, spellcasting, class_resources, features, archetypes`. `is_spellcaster()`, `spellcasting_ability()`. |
| `RaceClassRegistry.gd` (RefCounted, lazy load) | Хранит расы/классы, `pick_race/pick_class/pick_archetype`, доступ к подсистемам. |
| `Follower.gd` | `race`, `path`, `archetype`, `stat_modifiers`, `abilities`; сериализация/десериализация. |
| `FollowerSystem.gd` | `recruit()` назначает расу/класс/архетип, вычисляет модификаторы и способности. |

## Как работает найм

```gdscript
var f := _FollowerSystem.recruit(city, hero, rng)
# f.race   — из RaceClassRegistry.pick_race(rng)
# f.path   — из pick_class(rng)
# f.archetype — из pick_archetype(class, rng)
# f.stat_modifiers — ability_adjustments расы (String → int)
# f.abilities  — class features + trait расы
```

Модификаторы влияют только на числа характеристик; UI-отображение отложено
в отдельный цикл.

## Расширение

- Добавить расу/класс → запись в JSON, реестр подхватит автоматически
  (`count_races()` / `count_classes()`).
- Вес подбора (`pick_race(weights=...)`) — взвешенный рандом, по умолчанию веса = 1.

## Тесты

- `game/tests/test_race_class_matrix.gd` — реестр, уникальность, подбор, `describe()`.
- `game/tests/test_follower_race_class.gd` — `recruit`, `stat_modifiers`, roundtrip.

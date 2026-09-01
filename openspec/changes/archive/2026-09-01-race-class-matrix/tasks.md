## 1. Данные
- [x] Извлечь JSON из Pathfinder-файла → `game/assets/data/races_classes.json` (6 рас
      (без Half-Elf/Half-Orc), 16 классов × 4 архетипа, +bloodlines/domains/prestige/feats).
- [x] Проверить валидность JSON (`python3 -c "import json; json.load(...)"`).

## 2. Модели данных
- [x] `RaceDef.gd` (RefCounted): id, name, size, speed, ability_adjustments, traits, subraces;
      `to_dict()` / `from_dict()`.
- [x] `ClassDef.gd` (RefCounted): id, name, hit_die, bab, saves, skill_points, class_skills,
      spellcasting, class_resources, features, archetypes; `to_dict()` / `from_dict()`,
      `is_spellcaster()`, `spellcasting_ability()`.

## 3. Реестр
- [x] `RaceClassRegistry.gd` (RefCounted, lazy load): загрузка JSON, `get_race/get_class`,
      `all_races/all_classes`, `count_races/count_classes`, `pick_race/pick_class`
      (взвешенный), `pick_archetype`, доступ к подсистемам (bloodlines/domains/prestige/feats).

## 4. Интеграция с Follower
- [x] `Follower.race`, `Follower.path`, `Follower.archetype` (были заготовки `&"human"`/`&"unaligned"`);
      `Follower.stat_modifiers`, `Follower.abilities`.
- [x] Обновить сериализацию/десериализацию (новые поля сохраняются).
- [x] `describe()` выводит раса + класс + архетип.

## 5. FollowerSystem.recruit
- [x] Найм с назначением расы/класса/архетипа (`pick_race/pick_class/pick_archetype`).
- [x] Вычисление `stat_modifiers` (раса) и `abilities` (класс + раса).

## 6. Тесты
- [x] `test_race_class_matrix.gd`: реестр загружен; 6 рас / 16 классов × 4 архетипа;
      уникальность ids; `pick_race/pick_class` верны; `describe()`; сериализация.
- [x] `test_follower_race_class.gd`: `recruit` назначает расу/класс/архетип;
      `stat_modifiers` (elf = {DEX:2, INT:2, CON:-2}); `abilities` (class features);
      roundtrip сериализации.

## 7. Валидация
- [x] `run_all_ci_checks.sh` зелёный (operability, validator, tests).

## 8. Docs + commit
- [x] Документировать матрицу в `docs/`.
- [x] Commit по изменению (scoped).
- [x] Архивация change по openspec.

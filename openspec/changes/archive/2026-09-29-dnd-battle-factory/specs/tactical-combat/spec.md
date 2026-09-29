# Delta Spec: tactical-combat — D&D-бой по определениям персонажей

**Change:** dnd-battle-factory
**Base:** openspec/specs/tactical-combat/spec.md
**Status:** Open

## ADDED Requirements

### Requirement: D&D-бой по определениям персонажей

Игра предоставляет production-API (`DnDBattleFactory`) для построения и разрешения D&D-боя из явных определений персонажей. Определение персонажа (`DnDCharacterDef`) несёт: id, name, class_id, race_id, weapon, is_ranged, max_hp, speed, abilities (scores), ac_override (опц.). Фабрика строит из определений `DnDCombatantProfile`, `UnitStack` с `dnd_profile` и полный `BattleState`, и разрешает бой через `BattleEmulator`, возвращая результат.

#### Scenario: Построение профиля из определения

- **GIVEN** `DnDCharacterDef` (class_id="fighter", race_id="dwarf", abilities={str:16, dex:12}, max_hp=20, weapon="longsword")
- **WHEN** `DnDBattleFactory.build_profile(def)`
- **THEN** `DnDCombatantProfile` с abilities (STR=16, DEX=12), class_id="fighter", race_id="dwarf", max_hp=20, weapon="longsword"
- **AND** `get_ac()` = 10 + DEX-mod(12) + armor_bonus (+ class/race defense bonus)
- **AND** класс/расовые бонусы учитываются (get_attack_bonus/get_defense_bonus по class_id/race_id)

#### Scenario: Построение UnitStack с профилем

- **GIVEN** `DnDCharacterDef` (id="p1", speed=5)
- **WHEN** `DnDBattleFactory.build_stack(def)`
- **THEN** `UnitStack` с `dnd_profile != null`, count=1, stats.speed = 5
- **AND** `duplicate_stack()` сохраняет dnd_profile

#### Scenario: Построение полного D&D-боя

- **GIVEN** два списка определений (ally_defs, enemy_defs)
- **WHEN** `DnDBattleFactory.build_battle(ally_defs, enemy_defs)`
- **THEN** `BattleState` с юнитами обеих сторон
- **AND** каждый юнит `is_dnd_character()` и `dnd_current_hp == max_hp` (инициализирован)
- **AND** бой не завершён (check_end: обе стороны живы)

#### Scenario: Разрешение боя (simulate)

- **GIVEN** ally_defs (сильные персонажи), enemy_defs (слабые), seed
- **WHEN** `DnDBattleFactory.simulate(ally_defs, enemy_defs, seed)`
- **THEN** результат `{winner, atk_survivors, def_survivors}`
- **AND** `winner` ∈ {attacker, defender} (бой до победы)
- **AND** у проигравшей стороны 0 выживших
- **AND** детерминизм: тот же seed → тот же winner

#### Scenario: Класс/расовые бонусы в разрешении

- **GIVEN** два одинаковых персонажа, один с class_id="rogue" (crit_bonus +1), другой без класса
- **WHEN** `simulate` с фиксированным seed
- **THEN** персонаж с классом получает тактические бонусы в бою (бонусы влияют на исход)
- **AND** персонаж без класса — бонусы 0 (backward-compat)

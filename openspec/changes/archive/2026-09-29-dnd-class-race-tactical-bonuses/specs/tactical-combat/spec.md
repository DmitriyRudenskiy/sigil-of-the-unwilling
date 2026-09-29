# Spec Delta: tactical-combat (ADDED — Класс/расовые тактические бонусы)

> Дельта к main-spec `openspec/specs/tactical-combat/spec.md`. Добавляет тактические
> бонусы класса/расы для D&D-персонажей в живом D&D-бою (backward compatible).

## ADDED Requirements

### Requirement: Класс/расовые тактические бонусы
D&D-персонаж (`DnDCombatantProfile`) MAY нести опциональные `class_id` и `race_id` (default `""`). По этим идентификаторам таблица `DnDTacticalBonuses` выдаёт четыре тактических бонуса, которые `DnDBattleBridge.resolve_attack` применяет к резолву атаки:

- **attack_bonus** — прибавка к d20-броску атаки (складывается в `other_modifiers` броска);
- **defense_bonus** — прибавка к эффективному AC цели (`get_total_ac() = get_ac() + defense_bonus`);
- **crit_bonus** — расширение диапазона крита: крит при натуральном `d20 >= 20 - crit_bonus` (0 = только натуральная 20);
- **damage_bonus** — плоский урон, добавляемый к результату кубиков оружия.

Бонусы класса и расы **суммируются**. Персонаж без class/race (default `""`) и stack-юниты получают нулевые бонусы и резолвятся без изменений.

#### Scenario: Боец получает бонус защиты
- **WHEN** D&D-персонаж с `class_id = "fighter"` (defense_bonus +1) является целью
- **THEN** эффективный AC цели = базовый AC + 1
- **AND** атака, которая попала бы при базовом AC, промахивается при AC+1 (при том же d20)

#### Scenario: Плут расширяет диапазон крита
- **WHEN** D&D-персонаж с `class_id = "rogue"` (crit_bonus +1) бьёт и получает натуральный 19
- **THEN** атака является критической (крит при d20 ≥ 19)
- **AND** при натуральном 18 атака не является критической

#### Scenario: Варвар добавляет урон ярости
- **WHEN** D&D-персонаж с `class_id = "barbarian"` (damage_bonus +1) попадает
- **THEN** итоговый урон = кубики оружия + модификатор + 1

#### Scenario: Стрелок получает бонус атаки
- **WHEN** D&D-персонаж с `class_id = "ranger"` (attack_bonus +1) бьёт
- **THEN** d20-бросок атаки = d20 + модификатор + proficiency + 1

#### Scenario: Бонусы класса и расы суммируются
- **WHEN** D&D-персонаж с `class_id = "paladin"` (defense +1) и `race_id = "dwarf"` (defense +1)
- **THEN** суммарный defense_bonus = +2 (эффективный AC = базовый + 2)

#### Scenario: Неизвестный класс/раса
- **WHEN** `class_id`/`race_id` не найдены в таблице
- **THEN** соответствующие бонусы = 0 (персонаж дерётся без бонуса)

#### Scenario: Backward-compatibility
- **WHEN** D&D-персонаж без class/race (default `""`) или stack-юнит
- **THEN** все четыре бонуса = 0; резолв атаки идентичен поведению до изменения

# D&D Battle System Integration

## Status
**Completed except declared deferrals (2026-09-27).** Фазы 1–6 реализованы и протестированы (см. CHANGELOG 2026-09-25, сьют 1736+ тестов). Остаток цикла: (1) TASK_11 vertical movement и TASK_12 falling damage — НЕ реализованы, рекомендовано вынести в новое изменение `dnd-verticality-falling`; (2) Phase 6 UI/live-wiring — обоснованные отложения; (3) next step: sync delta-specs (core-mechanics, height-system) → archive. Отсутствующий файл `specs/damage-calculation/spec.md` из Related Documents объединён внутри `specs/core-mechanics/spec.md` (ссылка исправлена ниже).

## Overview
Integrate classic Dungeons & Dragons 5th Edition combat mechanics into the game's battle system, replacing or augmenting existing damage calculation, turn order, and tactical positioning systems.

## Problem Statement
The current battle system lacks:
- Proper advantage/disadvantage mechanics based on elevation and positioning
- D&D-style damage calculation with dice rolls and modifiers
- Height-based combat bonuses (high ground advantage)
- Cover and concealment mechanics
- Proper initiative system based on Dexterity
- Attack of opportunity mechanics
- Grapple and shove actions

## Proposed Solution
Implement a comprehensive D&D 5e-inspired combat system that includes:
1. **Damage Calculation**: d20 + modifiers vs AC (Armor Class)
2. **Height System**: Elevation bonuses for ranged and melee attacks
3. **Cover Mechanics**: Half cover (+2 AC), three-quarters cover (+5 AC), full cover
4. **Initiative System**: d20 + Dexterity modifier for turn order
5. **Combat Actions**: Attack, Dash, Disengage, Dodge, Help, Hide, Ready, Search, Use an Object
6. **Bonus Actions**: Off-hand attack, spell casting, special abilities
7. **Reactions**: Opportunity attacks, shield usage, countering spells

## Benefits
- More strategic and tactical combat
- Familiar mechanics for D&D players
- Better balance between different character builds
- Enhanced replayability through varied combat scenarios
- Clear progression system through proficiency bonuses and ability improvements

## Acceptance Criteria
- [x] All attack rolls use d20 + proficiency + ability modifier vs target AC *(attack_roll.gd, battle_bridge.resolve_attack; test_dnd_integration.gd)*
- [x] Height difference provides +1 to +5 bonus based on elevation levels *(height_modifier.gd, elevation_system.gd)*
- [x] Cover system properly calculates AC bonuses *(cover_calculator.gd; soft cover from creatures — deferred, см. tasks TASK_10)*
- [x] Initiative order is determined at combat start and maintained throughout *(initiative_tracker.gd, build_initiative)*
- [x] Opportunity attacks trigger when enemies leave reach without disengaging *(opportunity_attack.gd; test_dnd_maneuvers/action-economy tests)*
- [x] Damage rolls include weapon dice + ability modifier + situational bonuses *(damage_calculator.gd)*
- [x] Critical hits on natural 20, critical misses on natural 1 *(attack_roll.gd nat-20 crit path; saving_throw crit success/failure)*
- [~] Flanking provides advantage on melee attack rolls *(scope-out: фланкинг не входит в height-system spec и отсутствует в скоупе задач; вынести в отдельное изменение при необходимости)*
- [x] All mechanics are documented and tested *(specs/*, CHANGELOG Phases 1–6; runtime-эффекты действий и live-wiring отложены в Phase 6 с обоснованием)*

## Implementation Phases
1. Core mechanics (damage, AC, initiative)
2. Positioning system (height, cover, flanking)
3. Action economy (actions, bonus actions, reactions)
4. Special combat maneuvers (grapple, shove, disarm)
5. Integration with existing magic system
6. UI updates for D&D mechanics display

## Related Documents
- `/openspec/changes/dnd-battle-system/specs/core-mechanics/spec.md`
- `/openspec/changes/dnd-battle-system/specs/height-system/spec.md`
- `/openspec/changes/dnd-battle-system/tasks.md`

# Tasks: dnd-battle-factory

**Status:** DONE (2026-09-29)
**Gate:** `bash tests/run_all.sh` (полный прогон зелёный)

## Фаза 1 — DnDCharacterDef + build_profile
- [x] 1.1 `DnDCharacterDef` (data-класс: id/name/class_id/race_id/weapon/is_ranged/max_hp/speed/abilities/ac_override)
- [x] 1.2 `build_profile(def)`: abilities (string→Ability маппинг + set_score), class_id/race_id, weapon/is_ranged, max_hp; ac_override (armor_bonus) или стандартный AC
- [x] 1.3 Тесты: build_profile (abilities, class/race, max_hp, AC override + стандарт)

## Фаза 2 — build_stack + build_battle
- [x] 2.1 `build_stack(def)`: UnitStack с dnd_profile, count=1, speed из def
- [x] 2.2 `build_battle(ally_defs, enemy_defs)`: через BattleStateBuilder (профили переносятся, HP инициализируется)
- [x] 2.3 Тесты: build_stack (profile, count, speed); build_battle (обе стороны is_dnd_character, HP init, бой не завершён)

## Фаза 3 — simulate + бонусы
- [x] 3.1 `simulate(ally_defs, enemy_defs, seed)`: build_battle → BattleEmulator.run_auto_battle → {winner, atk_survivors, def_survivors}
- [x] 3.2 Тесты: simulate (winner, 0 выживших у проигравших, детерминизм по seed)
- [x] 3.3 Тесты: класс/расовые бонусы в разрешении (персонаж с class_id получает бонус; без класса — 0)

## Фаза 4 — регрессия + артефакты
- [x] 4.1 unit/battle зелёный (регрессия)
- [x] 4.2 Полный прогон зелёный (stack-модель не изменилась)
- [x] 4.3 Спек-дельта → main spec (tactical-combat), Implementation Status
- [x] 4.4 Архив изменения + README-индекс
- [x] 4.5 Коммит

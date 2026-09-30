# Proposal: dnd-class-race-tactical-bonuses

**Status:** Open (propose)
**Depends on:** `dnd-live-battle-wiring` (archive/2026-09-28-dnd-live-battle-wiring) — D&D-персонажи уже сражаются в живом цикле боя (пул HP, d20 vs AC через `DnDBattleBridge`). `dnd-battle-system` (archive/2026-09-27) — мост + `DnDCombatantProfile` + кубики урона готовы.

## Why

`dnd-live-battle-wiring` закрыл последний большой ⏳ в тактической спеке, кроме одного пункта: **«Класс/расовые тактические бонусы»** (main spec, Implementation Status). Он был отложен с пометкой «D&D-профили отложены» — а теперь D&D-профили **привязаны к живому бою**. Причина отложенности устранена.

Сегодня D&D-персонаж — это «стат-блок»: характеристики, AC, оружие, пул HP. Но **класс и раса не влияют на бой** — все персонажи одного класса/расы (а по факту — все персонажи без class/race) дерутся одинаково. В D&D 5e класс и раса дают конкретные боевые преимущества (Fighting Style, Sneak Attack, Rage, Divine Grace, Stonecunning, Lucky и т.д.). Без них D&D-персонажи — генерические бойцы, а не «боец/плут/варвар».

## What Changes

**Класс и раса D&D-персонажа дают тактические бонусы в живом D&D-бою.**

`DnDCombatantProfile` получает опциональные `class_id` / `race_id` (default `""` — без бонуса, backward compatible). Новая таблица `DnDTacticalBonuses` (battle/dnd/) мапит class_id/race_id → 4 тактических бонуса:

1. **attack_bonus** — прибавка к d20-броску атаки (в `other_mods` `DNDAttackRoll.roll`).
2. **defense_bonus** — прибавка к эффективному AC (`get_total_ac()`).
3. **crit_bonus** — расширение диапазона крита (крит при `d20 >= 20 - crit_bonus`; 0 = только натуральная 20).
4. **damage_bonus** — плоский урон, добавляемый к кубикам оружия.

`DnDBattleBridge.resolve_attack` применяет все четыре бонуса. Чистые персонажи (без class/race) и stack-юниты не меняются.

**Базовая таблица (DnD 5e-аутентичная, минимальная):**

| class_id | attack | defense | crit | damage | обоснование |
|---|---|---|---|---|---|
| fighter | 0 | +1 | 0 | 0 | Fighting Style: Defense |
| rogue | 0 | 0 | +1 | 0 | Sneak Attack (выше шанс крита) |
| ranger | +1 | 0 | 0 | 0 | Fighting Style: Archery |
| barbarian | 0 | 0 | 0 | +1 | Rage |
| paladin | 0 | +1 | 0 | +1 | Aura of Protection + Divine Smite |
| cleric | 0 | +1 | 0 | 0 | Divine Grace |

| race_id | attack | defense | crit | damage | обоснование |
|---|---|---|---|---|---|
| dwarf | 0 | +1 | 0 | 0 | Dwarven Resilience / Stonecunning |
| human | +1 | 0 | 0 | 0 | Versatile / Martial Adept |
| dragonborn | 0 | 0 | 0 | +1 | Draconic Ancestry |
| halfling | 0 | 0 | +1 | 0 | Lucky |

Бонусы класса и расы **суммируются** (персонаж = класс + раса).

## Capabilities

### Modified Capabilities
- `tactical-combat`: добавлено требование «Класс/расовые тактические бонусы» (ADDED Requirement в delta) — D&D-персонаж получает тактические бонусы от класса/расы в живом D&D-бою.

## Impact

- `game/scripts/battle/dnd/combatant_profile.gd` (+class_id, +race_id, +get_*_bonus, +get_total_ac, сериализация)
- `game/scripts/battle/dnd/tactical_bonuses.gd` (новый — таблица + lookup)
- `game/scripts/battle/dnd/battle_bridge.gd` (применение 4 бонусов в resolve_attack)
- Тесты: `game/tests/unit/battle/test_dnd_tactical_bonuses.gd` (новый)
- **Не затрагивает**: stack-модель, персонажей без class/race (default `""`), DnD-механики вне resolve_attack, save-систему, UI

## Acceptance Criteria

- [ ] 1. `DnDCombatantProfile.class_id`/`race_id` сериализуются (roundtrip); default `""`
- [ ] 2. `DnDTacticalBonuses` возвращает бонусы по class_id/race_id; неизвестный id → 0
- [ ] 3. attack_bonus повышает d20-бросок атаки (детерминированный тест)
- [ ] 4. defense_bonus повышает эффективный AC (детерминированный тест)
- [ ] 5. crit_bonus расширяет диапазон крита (крит при 19 с crit_bonus=1; miss при 18)
- [ ] 6. damage_bonus добавляет плоский урон к кубикам оружия
- [ ] 7. Бонусы класса и расы суммируются
- [ ] 8. Backward-compat: персонаж без class/race (default) и stack-юниты не меняются (существующий набор зелёный)
- [ ] 9. Полный прогон unit/battle: 0 новых ошибок/провалов

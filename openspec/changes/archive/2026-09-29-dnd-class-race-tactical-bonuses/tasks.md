# Tasks: dnd-class-race-tactical-bonuses

> **Status (2026-09-29):** DONE (apply → archive). Класс/расовые тактические бонусы
> для D&D-персонажей в живом D&D-бою. Завершает последний ⏳ в тактической спеке.
>
> **Прогресс:** фазы 1–5 реализованы и зелёные (13 новых тестов, unit/battle 166/166,
> полный прогон 204/204 suites / 1933 cases, 0 errors / 0 failures).
>
> **Фундамент:** D&D-персонажи уже в живом цикле (dnd-live-battle-wiring); мост
> `DnDBattleBridge.resolve_attack` готов (dnd-battle-system).

## 1. Таблица бонусов (data)

- [x] 1.1 `DnDTacticalBonuses` (новый, `game/scripts/battle/dnd/tactical_bonuses.gd`)
  - `class_name DnDTacticalBonuses extends RefCounted`
  - `const _CLASSES: Dictionary` (id → {attack, defense, crit, damage}) — 6 классов из proposal
  - `const _RACES: Dictionary` (id → {attack, defense, crit, damage}) — 4 расы из proposal
  - Статические: `get_attack_bonus/get_defense_bonus/get_crit_bonus/get_damage_bonus(class_id, race_id) -> int`
    (сумма класс+раса; неизвестный id → 0; безопасный доступ по ключу)
  - Критерий: lookup по известному id возвращает бонус; неизвестный → 0; класс+раса суммируются. ✅ test

## 2. Профиль (class_id / race_id)

- [x] 2.1 `DnDCombatantProfile`: `class_id: String = ""`, `race_id: String = ""`
  - Файл: `game/scripts/battle/dnd/combatant_profile.gd`
  - Методы: `get_attack_bonus()`, `get_defense_bonus()`, `get_crit_bonus()`, `get_damage_bonus()`
    (делегирование в `DnDTacticalBonuses`); `get_total_ac() -> int` = `get_ac() + get_defense_bonus()`.
  - `to_dict`/`from_dict`: +`class_id`/`race_id` (default `""`).
  - Критерий: сериализация roundtrip сохраняет id; default `""` → все бонусы 0; get_total_ac = AC + defense. ✅ test

## 3. Интеграция в резолв атаки

- [x] 3.1 `DnDBattleBridge.resolve_attack`: применить 4 бонуса
  - Файл: `game/scripts/battle/dnd/battle_bridge.gd`
  - `ac = def.get_total_ac()` (defense_bonus)
  - `total = roll.roll(rng, atk.get_attack_ability_mod(), atk.proficiency_bonus, atk.get_attack_bonus(), adv, disadv)` (attack_bonus)
  - `crit = roll.get_natural_roll() >= (20 - atk.get_crit_bonus())` (crit_bonus; B=0 ≡ натуральная 20)
  - `result["damage"] = int(dmg.get("total", 0)) + atk.get_damage_bonus()` (damage_bonus)
  - Критерий: детерминированные тесты 4 бонусов (см. тесты). ✅
  - ⚠️ Не трогать: `resolve_fall`, `build_initiative`, сигнатуру resolve_attack (параметры не меняются).

## 4. Тесты

- [x] 4.1 `game/tests/unit/battle/test_dnd_tactical_bonuses.gd` (новый)
  - Сериализация: class_id/race_id roundtrip; default `""`.
  - Таблица: lookup известного id; неизвестный id → 0; суммирование класс+раса.
  - attack_bonus: фиксированный d20 (seed) → total выше на +1 с ranger.
  - defense_bonus: fighter/dwarf → get_total_ac = AC + 1; суммарно +2 (paladin+dwarf).
  - crit_bonus: rogue (crit+1) → крит при натуральном 19, miss при 18 (детерминированный d20).
  - damage_bonus: barbarian → damage = кубики + mod + 1.
  - Backward-compat: персонаж без class/race → бонусы 0, резолв как раньше.
- [x] 4.2 Регресс: `test_dnd_live_battle.gd` (18) + весь `unit/battle` зелёные (166/166). ✅

## 5. Закрытие

- [x] 5.1 Полный прогон: 204/204 suites / 1933 cases, 0 errors / 0 failures.
- [x] 5.2 Sync дельты в main spec `tactical-combat`: ⏳→✅ строка «Класс/расовые тактические бонусы»
      + Implementation Status + примечание цикла.
- [x] 5.3 Архивация изменения; индекс `openspec/changes/README.md`.
- [x] 5.4 Коммит.

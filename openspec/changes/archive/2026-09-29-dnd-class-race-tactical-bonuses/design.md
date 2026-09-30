# Design: dnd-class-race-tactical-bonuses

## Context

`DnDCombatantProfile` — «стат-блок» персонажа (характеристики, AC, оружие, пул HP).
`DnDBattleBridge.resolve_attack(atk, def, rng)` резолвит одну D&D-атаку:
`ac = def.get_ac()` → `total = DNDAttackRoll.roll(rng, atk_ability_mod, atk.proficiency_bonus, 0, adv, disadv)`
→ `hit = total >= ac` → `crit = natural == 20` → `damage = DNDDamageCalculator.calculate_damage(...)` (только при hit).

Задача: добавить 4 тактических бонуса (attack/defense/crit/damage), зависящие от class_id/race_id,
не ломая существующий резолв и не затрагивая персонажей без class/race.

## Decisions

### D1. Бонусы живут в таблице `DnDTacticalBonuses` (data-driven, не в профиле)
Новый `class_name DnDTacticalBonuses` (battle/dnd/) с двумя `Dictionary`-таблицами
(`_CLASSES`, `_RACES`), ключ — id, значение — `Dictionary` из 4 полей
(`attack`, `defense`, `crit`, `damage`, default 0). Статические методы:
- `get_attack_bonus(class_id, race_id) -> int`
- `get_defense_bonus(class_id, race_id) -> int`
- `get_crit_bonus(class_id, race_id) -> int`
- `get_damage_bonus(class_id, race_id) -> int`
Каждый = `class_value + race_value` (суммирование). Неизвестный id → 0.

**Почему не в профиле:** профиль — данные персонажа; таблица бонусов — игровые правила.
Разделение позволяет менять баланс без правки профиля и сериализации.

### D2. Профиль хранит только id, бонусы вычисляются
`DnDCombatantProfile` получает `class_id: String = ""` и `race_id: String = ""` +
конvenience-методы:
- `get_attack_bonus() -> int` → `DnDTacticalBonuses.get_attack_bonus(class_id, race_id)`
- `get_defense_bonus() -> int`
- `get_crit_bonus() -> int`
- `get_damage_bonus() -> int`
- `get_total_ac() -> int` → `get_ac() + get_defense_bonus()`
Сериализация: `to_dict`/`from_dict` включают `class_id`/`race_id` (default `""`).

**Почему id, а не сами бонусы:** бонусы производные от id (таблица). Хранить id —
меньше данных, единый источник правды (таблица), легко менять баланс.

### D3. Интеграция в `resolve_attack` — 4 точечных изменения
1. `var ac: int = def.get_total_ac()` (was `def.get_ac()`) — defense_bonus.
2. `total = roll.roll(rng, atk.get_attack_ability_mod(), atk.proficiency_bonus, atk.get_attack_bonus(), adv, disadv)` (was `0` в other_mods) — attack_bonus.
3. `var crit: bool = roll.get_natural_roll() >= (20 - atk.get_crit_bonus())` (was `roll.is_crit_hit()`) — crit_bonus.
   При crit_bonus=0: `natural >= 20` ≡ `natural == 20` (d20 max 20) — идентично старому.
4. `result["damage"] = int(dmg.get("total", 0)) + atk.get_damage_bonus()` (was без бонуса) — damage_bonus.

**Почему crit через диапазон, а не %шанс:** диапазон крита (d20 ≥ 20−B) — каноническая
D&D-модель (Keen/Sharp оружие), детерминирована по натуральному броску (проще тестировать),
не требует доп. рандома.

### D4. Backward-compat по умолчанию
Все новые поля default `""`/0. Персонаж без class/race → все бонусы 0 →
`get_total_ac() == get_ac()`, `attack_bonus == 0`, `crit: natural >= 20 ≡ natural == 20`,
`damage + 0`. Резолв **побитово идентичен** старому для существующих персонажей.
Stack-юниты (без профиля) не проходят через D&D-ветку — не затрагиваются.

## Risks / Trade-offs

- **Баланс:** таблица — осознанный минимум (1–2 бонуса на класс/расу). Значения (+1, crit+1)
  малы и не ломают существующий калибр. Балансировка — follow-up (playtest).
- **Крит-модель:** расширение диапазона крита меняет определение крита (но backward-compat при B=0).
  Существующие тесты моста (крит при натуральной 20) остаются зелёными.
- **Scope:** speed_bonus (Elves/Halflings +скорость) НЕ входит — требует правки stack-speed
  в BattleStateBuilder (пересекает профиль/стэк). Отложен как follow-up.

## Testing

- `test_dnd_tactical_bonuses.gd`: сериализация id; lookup таблицы (известный/неизвестный id);
  детерминированные тесты 4 бонусов (экстремальный AC + фиксированный d20 через seed/подмена);
  суммирование класс+раса; backward-compat (default → 0 бонусов).
- Регресс: `test_dnd_live_battle.gd` (18) + весь `unit/battle` остаются зелёными.

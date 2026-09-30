# Design: dnd-battle-factory

## Цель
Production-API для построения и разрешения D&D-боя из явных определений персонажей — перевод D&D-фичи из test-only в production-API, без правки stack-flow / WorldBattleCoordinator.

## Компонент
`class_name DnDBattleFactory extends RefCounted` (battle/dnd/battle_factory.gd) — статические методы + внутренний data-класс `DnDCharacterDef`.

### DnDCharacterDef (определение персонажа)
```
id, name, class_id="", race_id="", weapon="longsword", is_ranged=false,
max_hp=10, speed=5, abilities={} (str/dex/con/int/wis/cha -> score), ac_override=-1
```
- `abilities` — словарь string→score (маппинг в `DNDAbilityScores.Ability`: str→STR, dex→DEX, ...).
- `ac_override=-1` — опционально: если >= 0, AC принудительно = ac_override (через armor_bonus); иначе AC = 10 + DEX-mod + armor_bonus (стандартный расчёт).

### Методы
- **`build_profile(def) -> DnDCombatantProfile`** — создаёт профиль: abilities (set_score по маппингу), class_id, race_id, weapon, is_ranged, max_hp. Если ac_override >= 0: `armor.armor_bonus = ac_override - (10 + dex_mod)`.
- **`build_stack(def) -> UnitStack`** — `UnitStats.new(id, name, 0, 0, 1, speed, 0, [id])` + `UnitStack.new(stats, 1)` + `stack.dnd_profile = build_profile(def)`.
- **`build_battle(ally_defs, enemy_defs) -> BattleState`** — списки def → списки stack → `BattleStateBuilder.set_attacker_army/set_defender_army` → `build()`. (BattleStateBuilder уже переносит dnd_profile + инициализирует HP.)
- **`simulate(ally_defs, enemy_defs, seed) -> Dictionary`** — `build_battle` → `BattleEmulator.run_auto_battle(state, rng)` (rng.seed = seed) → результат `{winner, atk_survivors, def_survivors}`.

## Почему фабрика, а не правка WorldBattleCoordinator
- `WorldBattleCoordinator._apply_results` stack-ориентирован (surviving stacks, extract_hero_survivors). D&D-результат (выжившие персонажи с пулом HP) — другая модель; интеграция требует отдельной обработки результатов + плейтеста.
- Фабрика — bounded, additive, testable: даёт production-API (`simulate`), которое сценарий/событие может вызвать. Интеграция в конкретный сценарий — следующая задача (на этой фабрике).

## Backward-compatibility
- Новый компонент; не трогает stack-модель, BattleStateBuilder, BattleFlow, WorldBattleCoordinator, hero, save, UI.
- `DnDCharacterDef` с пустым class/race → бонусы 0 (backward-compat с dnd-class-race-tactical-bonuses).

## Тестируемость (headless, GdUnit4)
- build_profile: abilities, class/race, max_hp, AC (ac_override и стандартный расчёт).
- build_stack: dnd_profile != null, count=1, speed.
- build_battle: обе стороны is_dnd_character, HP инициализирован, бой не завершён.
- simulate: winner ∈ {attacker,defender}, у проигравших 0 выживших, детерминизм по seed.
- Класс/расовые бонусы: персонаж с class_id получает бонус (сравнение seed-пар).
- Backward-compat: полный прогон зелёный.

## Ограничения
- `simulate` использует `BattleEmulator` (авто-бой, AI-решения) — для production-сценария, где D&D-бой разрешается автоматически (не интерактивно). Интерактивный D&D-бой (UI) — отдельная задача.
- Фабрика не привязана к конкретному сценарию — это entry point; вызов из сценария/события — следующая задача.

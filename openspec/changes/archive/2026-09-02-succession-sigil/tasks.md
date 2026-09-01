## 1. Death event seam
- [x] Add `HeroController.is_alive` flag (default true).
- [x] Add `hero_died(cause: StringName)` and `hero_successor(hero)` signals to `core/GameEventBus.gd`.
- [x] In `world/WorldBattleCoordinator._apply_results`, when the attacker loses AND the hero combat HP is zero, emit `hero_died(&"battle")` and skip `_restore_hero_after_retreat`; keep retreat when the hero merely routes (HP > 0).
- [x] Unit test: battle loss with zero hero HP emits `hero_died(&"battle")` and does not retreat.

## 2. Path gate + successor eligibility
- [x] Add `HeroController.path_id: StringName` (source of truth) and `PopUnit.path_id: StringName` (default = capital path).
- [x] Serialize/deserialize `path_id` on both `HeroController` and `PopUnit`.
- [x] Unit test: `PopUnit.path_id` round-trips through serialize/deserialize.

## 3. SuccessionController (selection + transfer)
- [x] Create `world/SuccessionController.gd` (`class_name SuccessionController`, RefCounted). Injected directly in `WorldController._ready` (via its local `SuccessionControllerScript` preload, not `WorldBootstrap`) — satisfies the spec's wiring requirement and avoids bootstrap coupling. In detached test compiles the global `class_name` isn't registered, so WorldController references the script by its local const.
- [x] `select_successor()`: choose an eligible same-path follower from the capital `pop` (oldest free follower of the path; seeded roll). Return null if none.
- [x] `transfer_legend()`: build a fresh `HeroController`, copy `path_id`, `HeroMagic` (spellbook/schools/mana), `HeroInventory`, strategic resources; re-register deceased hero's cities onto the successor `CityManager`, preserving `capital`/`glory`/`current_turn`; remove old hero; swap `WorldController._hero`; emit `hero_successor`.
- [x] Unit test: after succession, successor owns identical cities (boroughs/buildings/roads/pop/specialization/level/reputation/faction/storage/resource_ctx), spellbook, inventory, and `path_id`.
- [x] Unit test: a follower of a different path is never selected.
- [x] Unit test: no eligible follower → selection returns null (run ends).

## 4. Resurrection temple gate
- [x] Add `City.can_resurrect(required) -> bool` (temple level ≥ 1 and `storage` has required industry + special resource `&"gold"`). Costs: `RESURRECTION_INDUSTRY=500`, `RESURRECTION_SPECIAL_AMOUNT=100`.
- [x] Add `SuccessionController.resurrect_hero(city, ...)` — consumes resources, rebuilds dead hero with path + spellbook + template gear only (no inventory); enforce one-per-cycle.
- [x] Unit test: resurrection succeeds with temple + resources and consumes them.
- [x] Unit test: resurrection refused without a temple; inventory not restored after resurrection.

## 5. Integration + UI
- [x] Wire `GameEventBus.hero_died` → `SuccessionController.on_hero_died` in `WorldController`: connect in `_ready`, `_on_hero_died` selects via `_plan_succession` (testable seam), `_reincarnate` swaps the hero in the tree and re-points `battle_coordinator.hero` / `interaction_controller.hero`. Emit `hero_successor`.
- [ ] UI hook: refresh world/hero panels on `hero_successor` (new hero figure, status message).
- [ ] Headless scenario: death → succession → new active hero; verify no economy reset.

## 6. Save/migration
- [x] Bump save version 3 → 4; add `successor` + `legend` dicts + `_migrate_v3_to_v4` (defaults to empty dicts). `deserialize` loads `path_id` (default `&""`).
- [x] Unit test: legacy save without `path_id` deserializes without error (v3→v4 migration defaults).

## 7. Tests + validation
- [x] Add/adjust unit tests under `tests/`: test_hero_combat_death, test_follower_path_id, test_succession, test_worldcontroller_succession_wiring. Full suite: 5136 passed, 0 failed (89 files).
- [ ] Run `run_all_ci_checks.sh` (or `python3 run_all_tests.py` + spell validator) green.

## 8. Docs + commit
- [ ] Update `docs/` notes on hero death/succession/resurrection.
- [ ] Commit with a conventional-commit message; scope the commit to changed files only.

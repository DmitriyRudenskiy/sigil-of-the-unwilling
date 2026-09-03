## Context

`systems/BattleActionResolver.gd` (`class_name BattleActionResolver`, RefCounted, stateless) holds all battle logic as static methods: `apply_attack`, `apply_spell`. Each takes `(state, ...)` and mutates `BattleState` (via `state.set_count`, `state.kill_unit`, `state.revive_unit`) then calls `state.invalidate_board_cache()` / `state.check_end()`. `apply_attack` does first-strike → damage (`BattleDamageResolver.resolve`) → charge → mutation → rebirth check → kill. `apply_spell` validates → `SpellCaster.cast` → damage/heal/revive. `BattleState.BattleUnit` has `get_count/set_count`, `is_alive`, `has_tag`, `max_count`. Monsters can carry a `rebirth` tag (checked in `_try_rebirth`). `BattleTurnExecutor` drives turns and emits `execute_attack`/`execute_move` signals the `BattleView` renders.

Sacrifice must slot into this exact pattern: a static method that validates, mutates `state`, and returns a result dict. The cost types map onto existing models:
- **Follower/unit stack** → a `BattleState.BattleUnit` on the acting side (kill/remove via `state.kill_unit`).
- **Stored resource** → the controlled economy `city.storage` (deduct here; the economy `resource_ctx` is separate, but `storage` is the visible industry/gold pool).
- **Artifact** → `HeroInventory.equipped[slot]` (remove from slot).

The acting unit, target, and cost are passed in; the "finish off" effect is `target.set_count(0); state.kill_unit(target)` — bypassing `_try_rebirth`.

## Design

Add `static func apply_sacrifice(state, acting, sacrifice, target, cost, rng) -> Dictionary` to `BattleActionResolver`:

1. **Validate:** `acting` alive, `target` alive enemy, `sacrifice` matches `cost`, cost available. Return `{"result": "invalid_*"}` (no mutation) on failure.
2. **Resolve:**
   - `target.set_count(0)` then `state.kill_unit(target)` (no rebirth check — finish off).
   - Consume cost: follower stack → `state.kill_unit(sacrifice)`; resource → deduct from the passed-in economy `storage` dict; artifact → remove from `HeroInventory`.
   - Mark `acting.has_moved = true` (one action).
3. `state.invalidate_board_cache(); state.check_end();` return `{"result": "success", "finished": target}`.

`BattleTurnExecutor` gains a path to emit a new `execute_sacrifice(acting, target, cost)` signal so `BattleView` renders it; the player-facing UI (select cost → select target → confirm) is a UI task, not a logic task.

**Grounding facts (files):**
- `systems/BattleActionResolver.gd` — add `apply_sacrifice` next to `apply_attack`/`apply_spell`.
- `systems/BattleState.gd` — `BattleUnit` (set_count/is_alive/has_tag), `kill_unit`, `revive_unit`, `check_end`.
- `systems/BattleTurnExecutor.gd` — add `execute_sacrifice` signal + executor path.
- `entities/HeroInventory.gd` — artifact removal.

## Risks / Trade-offs

- **Balance:** a guaranteed kill is powerful; the cycle owner sets what it costs and cooldowns. Keep the action count-limited (one per turn) to avoid trivializing combat.
- **Cost data:** this change defines the *mechanism*, not the balance table (what resources, how many). Leave the table as a config the cycle owner fills — matches "system depth" without over-committing.
- **Rebirth bypass:** deliberate (finish off), but means sacrifice is the only reliable anti-rebirth tool; document.

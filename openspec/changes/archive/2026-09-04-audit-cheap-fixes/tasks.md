## Tasks

- [x] 1. `core/GameLogger.gd`: make `_tag` return plain text (no
      `[color=...]` markup) when `Platform.is_headless()`; bodies of
      `info`/`warn`/`error`/`trace` unchanged (see design). Preserve `warn`
      via `push_warning` / `error` via `push_error`.
- [x] 2. `core/HexUtils.gd:157`: `cur_g > best_g + 0.001` → `cur_g > best_g`.
- [x] 3. Run GUT: `godot --headless --path game -s addons/gut/gut_cmdln.gd
      -gdir=res://tests -ginclude_subdirs -gexit`. Full suite noisy (22 failing)
      from the uncommitted starvation/hunger bundle + new `remove-hunger-mechanic`
      change — all unrelated to `_tag`/astar. Diff of `[Failed]` messages between
      HEAD and my change is byte-identical: zero new failures, my logger test stays
      green. Pre-existing count is 1120/22, not the task's stale 1141/1.
- [x] 4. Verify headless logging: ran a `-s` script in headless; `Platform.is_headless()==true`,
      `_tag("Hero")` -> `[[Hero          ]]` (no `[color=...]`), all public methods smoke ok.
- [x] 5. Commit: `fix(audit): headless-safe GameLogger; strict astar stale-entry`.

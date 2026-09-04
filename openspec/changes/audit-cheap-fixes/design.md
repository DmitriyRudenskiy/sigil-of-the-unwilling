## Design

Both fixes are localized; neither changes public behavior except GameLogger's
headless output (dev-logging, not a product requirement).

### GameLogger headless-safe logging

`GameLogger` is a `static` class. Every method renders the tag through `_tag`,
which wraps it in `[color=gray]…[/color]`. In `--headless` a plain terminal
renders those as literal `[color=gray]…[/color]` text — the finding `#11`.

`info` uses `print_rich`; `warn`/`error` use `push_warning`/`push_error`
(preserve those streams — do **not** route them through `print`). The minimal
fix is at the single shared point: make `_tag` emit plain text in headless.
This covers `info`/`warn`/`error`/`trace`/`world`/`inventory`/`hero`;
`battle`/`ui` carry an inline `[color=cyan]`/`[color=magenta]` that is a
cosmetic debug-only concern (noted below, out of scope for `#11`).

```gdscript
static func _tag(tag: String) -> String:
    var padded := "[%s]" % tag.rpad(TAG_WIDTH)
    if _Platform.is_headless():
        return padded          # no color markup in headless
    return _COLOR_GRAY + padded + _RESET
```

`info`/`warn`/`error`/`trace` bodies unchanged — they already call `_tag`; with
a plain tag `print_rich` simply emits plain text.

> ponytail: one shared point, no new `_emit` helper, no stream rewrites.
> `battle`/`ui` inline tags: if headless cleanliness matters there, gate the
> inline color through the same `is_headless()` check — don't build a logging
> framework for it now.

### astar_path stale-entry check

`core/HexUtils.gd:157`:

```gdscript
if cur_g > best_g + 0.001:   # before
if cur_g > best_g:            # after
```

`MinHeap.pop()` inside the loop is guarded by `while not open.is_empty()`, so
`cur` is never `[]` (the audit's out-of-bounds concern is unreachable — see
proposal). Strict `>` is the correct stale-entry test: an entry equal to
`best_g` is the live one, not stale.

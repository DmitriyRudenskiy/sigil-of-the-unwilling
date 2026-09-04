# Project audit — worthwhile findings

## Why

A broad audit of the project flagged 11 findings across UI, algorithms,
best-practices and refactoring. Most are theoretical, already handled, or big
refactors that belong in their own change. This change takes only the findings
that are **genuinely worth doing now**: real bugs with trivial, low-risk fixes,
plus two safe cleanups. The rest are explicitly declined (see design.md).

## What Changes

- **UI — ArtifactChestDialog Close button (R1):** the scene has a `cancel`
  button (label "Close") that is never connected, so dismissing the chest
  dialog does nothing. Connect `cancel.pressed` → `_on_close()` (the handler
  already exists and hides the dialog). One line. Dismissing emits **no**
  `choice_made` — a cancel is not a take/gold choice and must not consume or
  remove the chest from the world (the `choice_made` consumer runs chest
  removal for any choice string).
- **UI — BattleUI collapse button (R2):** `collapse_btn` is a child of
  `bottom_bar`, and `_on_collapse()` toggles `_bottom_bar.visible`, so the
  button hides itself and the panel can never be expanded again. Move
  `collapse_btn` out of `bottom_bar` into the root and fix the lookup path.
- **City — ArenaClusterSystem cache after load (R5):** the cluster cache is
  keyed on `city.uid` and is only invalidated from `ArenaTurnRunner.place_building`.
  `City.deserialize` repopulates `buildings` but never invalidates, so a
  loaded city reports stale clusters. Add one `ArenaClusterSystem.invalidate(uid)`
  call in `City.deserialize`.
- **Cleanup — dead MapRenderer.diversify() (R8):** body is `pass` with a
  comment "biome has one base variant, diversification not needed". Remove the
  method and its single call in `MapGenerator`.
- **Cleanup — spell validator class_name regex (R9):** `_load_src` strips
  `class_name` by `begins_with("class_name ")`, which is fragile if the token
  appears inside a string literal. Make the strip regex-aware.

## Capabilities

### Modified Capabilities

- `ui-scenes`: add requirements that dialog buttons (Close) and the BattleUI
  collapse button are wired and usable.
- `arena-model-decomposition`: extend the cluster-cache requirement so
  deserialization of a city invalidates the cache.

### New Capabilities

(нет — новые системы не вводятся)

## Impact

- **Код:** `scripts/ui/ArtifactChestDialog.gd`, `scripts/ui/BattleUI.tscn` +
  `scripts/ui/BattleUI.gd`, `scripts/world/City.gd`,
  `scripts/world/MapRenderer.gd` + `scripts/world/MapGenerator.gd`,
  `tools/spell_validation/validate_spells.gd`.
- **Спецификации:** delta-спекты `ui-scenes` и `arena-model-decomposition`.
- **Тесты:** ожидаемых регрессий нет — все правки либо добавляют пропущенное
  подключение, либо убирают мёртвый код, либо расширяют проверку кэша.

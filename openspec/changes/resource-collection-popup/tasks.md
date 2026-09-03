## 1. Discovery & data mapping

- [x] 1.1 Determine the sprite/atlas format provided for resource icons (single atlas with regions vs per-resource PNG) and gather the exact `resource_id`s used on the world map (rich nodes + simple collection).
- [x] 1.2 Build a data-driven `resource_id → texture/region` resolver (dictionary) plus `resource_id → name` for the popup; no hardcoded paths in logic.
- [x] 1.3 Confirm `GameEventBus.resource_extracted(cell, resource_id, amount)` is emitted for the rich extraction path (already done in ResourceNodeManager).
- [x] 1.4 Inspect `WorldInteractionController.collect_resource_at` and the simple-collection cell data (`res_type`) to obtain resource_id + amount for the simple path.

## 2. ResourceCollectPopup control

- [x] 2.1 Create `ResourceCollectPopup` (Control) mirroring `ArtifactChestDialog`: MarginContainer → VBox → TextureRect image, name/amount label, OK button.
- [x] 2.2 Implement `show_resource(resource_id, amount)` that resolves the texture via the resolver + amount + name, with placeholder/`0` degradation on unknown data.
- [x] 2.3 OK button hides the popup and makes it reusable for the next collection.
- [x] 2.4 Add auto-dismiss timer (~4 s) that hides the popup independently of OK.

## 3. Wiring / coordinator

- [x] 3.1 Add a coordinator (in `AdventureUI`, overlay layer) that lazily creates one `ResourceCollectPopup` (like `_options_popup`).
- [x] 3.2 Subscribe the coordinator to `GameEventBus.resource_extracted` and call `show_resource(resource_id, amount)` with `popup_centered`.
- [x] 3.3 Extend `collect_resource_at` to emit `GameEventBus.resource_extracted(cell, resource_id, amount)` for the simple path (COLLECT_HERE / SocketController) using data from 1.4.

## 4. Verification

- [ ] 4.1 Run `game/tools/shell/run_operability.sh`; ensure verdict is `CLEAN` (scenes, scenarios, unit tests).
- [x] 4.2 Add any new console warning from the popup to `docs/CONSOLE_ALLOWLIST.md` if truly benign.

## 5. Docs

- [x] 5.1 Update `docs/economy_runtime.md` / `docs/world_adventure.md` with the collection-popup behavior (both paths, OK + auto-dismiss).

## 6. Commit

- [ ] 6.1 Commit only files belonging to this change, scoped to `resource-collection-popup`.

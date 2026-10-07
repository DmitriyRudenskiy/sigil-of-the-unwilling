# Design

## Context

See `proposal.md` and `specs/campaign-city-management-ui/spec.md`. `world_ui_manager.gd` opens one `CityScreen`; today it is a 560×420 modal that reads legacy building/storage fields and does not render campaign building instances. The `City` object also carries `CityData.campaign_buildings`, the 52-cell center/core/ring geometry, and the shared `ResourceContext`. `HexUtils` is the existing geometry authority. The campaign building catalog and placement explanation exist, but the construction request/progress service is still planned in `campaign-city-construction-queue`.

The reference file is `reference/port-district-tier1.webp` (1920×1200). The prose UI spec names 1920×1080 and a 300–340px sidebar; the image is 1920×1200 and its sidebar is proportionally wider. The image is the reference for composition/material and the written spec for motion, accessibility, and supported viewport sizes. Canonical runtime state always outranks prototype labels and sample values.

## Goals / Non-Goals

**Goals:**
- Reshape the existing city-screen entry point into one campaign-city view with catalog, 52-hex viewport, live HUD, and inspection/placement states.
- Make inspection read-only and delegate accepted placement to the construction service; keep displayed costs, progress, and effects sourced from existing data.
- Match the reference composition and restrained dark-panel/gold-accent presentation while remaining legible at the specified desktop sizes.

**Non-Goals:**
- Another city instance, game mode, score economy, Port District tier, 1–11 city progression, or source-game resources/mechanics.
- Manual worker assignment, naval gameplay, custom trade, or a new help/tooltip framework.
- A new render engine, third-party UI package, or a complete bespoke 3D building asset pack.
- Save-schema changes. The screen is a view over existing city state.

## Decisions

1. **Keep the existing `CityScreen` entry point.** Replace its centered-modal composition in the existing scene and preserve `WorldUIManager` open/close signaling. This avoids duplicate city entry flows. Keep still-supported non-campaign city operations reachable through their existing handlers; do not route them through the campaign catalog or resource HUD. The campaign build panel itself uses only campaign services.

2. **Bind views, don't mirror rules.** Pass the selected city and validated campaign catalog into the screen. Read balances from `ResourceContext`, construction progress and state from building instances, population/housing from existing city queries, persisted group satisfaction per group, and effect explanations from existing reports/resolvers. Do not invent a single happiness aggregate. Cards are projections of catalog records. The view does not calculate a second economy or write city data during inspection.

3. **Render the existing 52-cell city, not the screenshot's gameplay.** Build the main board from `CityData.center` and the core/ring cell helpers in `HexUtils`; query existing terrain/buildability providers and overlay current legacy/campaign building instances. Use existing hex tile textures, resource/icon lookup, and the transparent object sprites from PR #22 at source head `446ebd40b76a54a0bb1346ad7edfcaecb2433359` (magenta-keyed and converted to WebP) only for exact or source-backed building matches; unmatched buildings keep the established role-icon fallback. Use custom overlay drawing only for selection, valid/invalid previews, and tooltips. Do not crop the prototype into a fake interactive background or invent port/water behavior to fill it.

4. **Use the current Godot UI stack and shared theme.** Compose the top HUD, left tabbed catalog, central board, and lower-right legend with anchors/containers and current theme assets. Apply the supplied palette as screen-scoped theme overrides; keep the prototype's dark/warm panel treatment, gold active state, and teal information cues. Dim the existing world behind the screen with a translucent shade rather than replacing it with black. Do not add a UI dependency or global theme rewrite for one screen.

5. **Resolve the viewport conflict around the prototype capture.** Use the reference image's native 1920×1200 size for the visual comparison. Also validate 1920×1080 and 1280×720; calculate the sidebar from a responsive width range and collapse it to the existing-style icon rail at the minimum size. At 4K rely on Godot UI scaling, not duplicated assets. Image composition takes precedence over its conflicting written sidebar measurement; semantic color, typography, and accessibility rules remain from the prose spec.

6. **Do not guess a cross-change construction API.** The UI depends on the public request/result contract from `campaign-city-construction-queue`. Complete that change first (or expose its service before this change's integration tasks); placement confirmation must call that one service. If the service rejects, keep selection and show the returned reason. Do not add a second queue, cost transaction, or fallback mutation path.

   **Available contract:** `CampaignBuildingConstructionService.explain_request(city, catalog, building_id, anchor, terrain_by_cell = {}, scenario_flags = [], admin_capacity = 0)` is a read-only preview returning `ok`, and on success the canonical definition, costs, construction turns and placement cells; failures return a stable `reason` and, where relevant, `missing`, `issues`, or `placement`. `request(...)` accepts the same arguments, repeats validation, atomically charges the shared `ResourceContext`, appends one persisted instance, and returns `{ok, instance, flow}`; rejection returns `{ok: false, reason, ...}` without changing city state or the ledger. The caller supplies an already validated catalog. The screen uses `explain_request` for preview and calls `request` exactly once only on confirmation.

7. **Use native controls for interaction feedback.** Use existing button/card states and one delayed tooltip mechanism for card and resource explanations. Keep hover/press response within the supplied timings; focus states remain visible, all actions keyboard reachable, and Escape cancels placement before closing the screen. No new animation framework.

8. **Verify logic and appearance separately.** GdUnit4 covers data binding, visibility/status reasons, delegated requests, cancellation, and no-write inspection/rejection. A fixed sample city is used only in tests. Capture the real UI at 1920×1200 and 1280×720 and compare side-by-side with the reference for region placement, proportions, palette, and hierarchy. This is a manual visual gate; headless tests do not certify it, and no image-diff dependency is added.

## Risks / Trade-offs

- [The reference shows Gold, Stone, a Port District tier, and a coastal port economy that the campaign MVP does not support] → preserve its panel composition only; display canonical resources/buildings and omit unsupported labels and mechanics.
- [The prototype's single happiness value has no defined city-wide campaign aggregate] → show available satisfaction per populated group from the saved campaign state; do not invent an aggregate.
- [The reference is more detailed than the available terrain and object assets] → reuse bundled hex tiles; use PR #22's transparent object sprites only for semantically matched building IDs, and retain role icons for unmatched structures. This improves visual identity without claiming pixel-identical art or inventing asset matches.
- [Construction service is not yet implemented] → apply `campaign-city-construction-queue` first; do not wire a temporary build path.
- [The city object retains legacy building and city operations] → render all occupied cells and preserve existing handlers; campaign catalog actions remain isolated from unrelated legacy operations.
- [At 1280×720 a full card list competes with the map] → collapse the catalog to its rail and show one selected-card detail at a time; never shrink the 52-cell hit targets below usable size.

## Migration Plan

No save migration. Replace the presentation in place, retain the same city open/close lifecycle, and keep non-campaign actions routed to their existing services. Rollback is limited to restoring the previous `city_screen.tscn`/script composition; city and save data are unchanged.

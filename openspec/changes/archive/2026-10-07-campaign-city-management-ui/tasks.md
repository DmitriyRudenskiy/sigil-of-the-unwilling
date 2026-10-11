# Tasks

## 1. Construction dependency and screen shell

- [x] 1.1 Complete `campaign-city-construction-queue` first and verify its focused construction tests plus `game/run_tests.sh`; document the callable request/result contract before connecting this screen.
- [x] 1.2 Reshape the existing `CityScreen` scene into anchored HUD/sidebar/viewport/legend regions while preserving `WorldUIManager` open/close signaling and still-supported legacy actions; verify existing city-screen and UI-manager tests.

## 2. Live city display

- [x] 2.1 Render the existing 52-cell geometry, terrain, core/rings, occupied cells from both building collections, and selection using canonical city state; verify all 52 cells and their rendered identities against the city fixture.
- [x] 2.2 Populate the resource/population/housing HUD from `ResourceContext` and city queries, show per-group satisfaction only from persisted state, and expose ledger breakdowns; verify no Gold/Stone/score/mock values appear and empty state does not invent values.
- [x] 2.3 Build scrollable role/category filters and building cards from validated catalog definitions with existing icon lookup/fallback; verify affordability, prerequisites, duration, and disabled reason reflect the selected city's data.
- [x] 2.4 Add selected-cell/building inspection for state, construction progress, active effects, and available cause breakdowns; verify inactive/ruined/in-progress structures never display effects the simulation suppresses.

## 3. Interaction and feedback

- [x] 3.1 Implement catalog selection, valid/invalid placement preview, exact blocking reasons, cancel, sidebar collapse, keyboard focus, and delayed tooltips; verify each state and Escape cancellation without city mutation.
- [x] 3.2 Route placement confirmation through the construction service from task 1.1 and render its accepted/rejected result; verify a successful request is charged once and a rejected request changes neither city state nor ledger.
- [x] 3.3 Apply the prototype-matched panel composition, screen-scoped palette, AA contrast, keyboard-visible focus, and specified calm animation timings; verify contrast tokens in a focused test and confirm no new UI dependency was added.

## 4. Verification and visual acceptance

- [x] 4.1 Add focused GdUnit4 coverage for live HUD/card binding, read-only inspection, unavailable values, selection/preview state, service delegation, and failure no-mutation; run the focused UI suite.
- [x] 4.2 Run `game/run_tests.sh`, `openspec validate campaign-city-management-ui --strict`, `python3 scripts/check_docs_links.py`, and `git diff --check`; resolve failures before completion.
- [x] 4.3 Launch the actual Godot UI and capture the deterministic showcase city at 1920×1200, 1920×1080, and 1280×720; place every supported source-backed building sprite in the non-persistent visual sample, compare side-by-side with `reference/port-district-tier1.webp`, refine layout/readability, and record author visual approval (not covered by headless tests).

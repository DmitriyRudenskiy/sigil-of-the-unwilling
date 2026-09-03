## 1. Audit (baseline)
- [x] List AdventureUI right-column panels and the `ToolsPanel` screen-toggle pattern to copy.
- [x] Confirm the hero has no needs data today (panel must degrade gracefully).

## 2. `HeroStatusPanel`
- [x] `ui/HeroStatusPanel.gd`: condition (needs/inspiration when present), stats, followers list; read-only; renders only sections whose data exists.
- [x] Add to AdventureUI right column + toggle from `ToolsPanel`.
- [x] Test: panel renders with empty/partial data (no crash) and with full data.

## 3. `DeathSequence`
- [x] `ui/DeathSequence.tscn` overlay: fall beat, run-summary grid, successor card (when a successor exists).
- [x] Wire to the `succession-sigil` death event (fallback: `endgame-conditions` defeat); «Знак переходит» invokes the succession flow; else «В меню».
- [x] Animate with `UIAnimator`; block input while open.
- [x] Test: death event shows the sequence; successor path and no-successor path both render.

## 4. `Chronicle`
- [x] `core/Chronicle.gd`: `GenerationEntry`, append on `cycle_ended` / `game_ended`; serialize in the save.
- [x] `ui/ChronicleScreen.tscn`: list newest-first; reachable from the main menu («Летопись») and after death.
- [x] Test: entries appended on events; persist through save/load; screen lists them.

## 5. Glory meter
- [x] AdventureUI glory bar/label: current → threshold (`endgame-conditions` settings); updates on `glory_changed`.
- [x] Test: meter reflects a glory change.

## 6. Gate
- [x] Full suite + scenarios green; re-run the agent-run-and-debug gate; commit.

# Proposal

## Why

The current `CityScreen` is a compact legacy modal: it does not expose the campaign building catalog, 52-cell city layout, shared resource ledger, or the reasons a building is available, blocked, or productive. A campaign-city management view is needed to make those existing systems legible and buildable; the supplied Port District image is the visual target, not a source of new game rules.

## What Changes

- Replace/reshape the current city modal into a PC-first management screen: campaign resource HUD, category-filtered building cards, central 52-hex city viewport, selected-cell/building inspection, contextual help, and a compact terrain legend.
- Bind displayed values and actions to the current city, validated campaign catalog, shared resource ledger, and construction service. Show costs, effects, prerequisites, progress, and disabled reasons from live data rather than hard-coded mock values.
- Match the supplied prototype's composition, palette, visual hierarchy, and calm feedback at its actual 1920×1200 resolution; also support the written 1920×1080 design canvas and 1280×720 minimum.
- Preserve project canon: the screen uses only registered campaign resources `{food, wood, iron}`, the existing 52-hex city, and existing turn/economy rules. It does not add Gold/Stone, a Port District or city-tier progression, score-as-currency, naval/economic mechanics, or a second city mode. Prototype-only labels and values are replaced by canonical city data.
- Keep placement and construction outcomes in the campaign construction service; the UI must not spend resources or mutate buildings through a parallel path.

## Capabilities

### New Capabilities
- `campaign-city-management-ui`: player-facing campaign-city overview, catalog, placement feedback, building/ledger explanations, responsive layout, and visual acceptance against the supplied prototype.

### Modified Capabilities
- None. This adds a screen over existing campaign-city and UI contracts; it does not change city geometry, economy, construction semantics, or generic UI-widget behavior.

## Impact

- Primary UI: `game/scenes/ui/city_screen.tscn`, `game/scripts/ui/city_screen.gd`, `game/scripts/ui/world_ui_manager.gd`, and localization/theme/icon resources as needed.
- Data/services reused: `City`/`CityData`, `CityFactory`, `HexUtils`, `CampaignBuildingCatalog`, `CampaignBuildingPlacement`, `ResourceContext`, city serialization, and the campaign construction service.
- Implementation depends on the service contract in `campaign-city-construction-queue`; complete that change first or make its service available before wiring the placement-confirm action. No external UI dependency is proposed.
- The reference folder contains the supplied target `reference/port-district-tier1.webp` and a pre-change live capture of the current legacy screen, `reference/legacy-city-screen-baseline.png`; the latter is a baseline, not the target. Visual acceptance requires a real Godot window/screenshot and is not claimed by headless tests.

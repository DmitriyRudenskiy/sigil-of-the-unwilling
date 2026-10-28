# mvp-ui-flow — delta (battle-field-hud-reserve)

## MODIFIED Requirements

### Requirement: Low resolution support
The MVP SHALL support 1280x720 minimum resolution. The grid SHALL scale; main
screens SHALL have no scroll. The battle field SHALL be fitted into the viewport
minus the HUD bands it is drawn under — the top band (hero cards, initiative bar)
and the bottom action bar — and SHALL be centred in that band rather than in the
viewport. At 1280x720 the field SHALL occupy at most 0.8 of the frame height.
The reserve SHALL be read from the HUD panels themselves; it SHALL NOT be a
resolution-threshold constant.

(This replaces the C-10 wording "the battle field at 720p SHALL use scale x0.8":
a threshold multiplier cannot help 1920x1080, where the field measured 1.000 of
the frame with the action bar drawn over the last rows — T-220/D-279.)

#### Scenario: 720p scaling
- **WHEN** the game runs at 1280x720
- **THEN** the grid scales
- **AND** main screens have no scroll

#### Scenario: Field clears the action bar at Full HD
- **WHEN** a battle runs at 1920x1080
- **THEN** the bottom edge of the field lies above the top edge of the bottom action bar
- **AND** the field occupies no more than 0.8 of the frame height

#### Scenario: Editing a HUD panel moves the reserve
- **WHEN** the height of the bottom action bar changes in `scenes/ui/battle_ui.tscn`
- **THEN** the fitted field band changes by the same amount
- **AND** no code constant is edited

#### Scenario: No reserve keeps the tight fit
- **WHEN** the HUD reserve is zero
- **THEN** the field is fitted into the whole viewport and centred on the field centre

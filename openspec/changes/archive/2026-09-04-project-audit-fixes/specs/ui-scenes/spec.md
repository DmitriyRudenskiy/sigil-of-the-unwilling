# ui-scenes — delta (project-audit-fixes)

## ADDED Requirements

### Requirement: Dialog buttons are all wired to handlers
The ArtifactChestDialog SHALL connect every button present in the scene to a
handler. The "Close" (cancel) button MUST dismiss the dialog (via the existing
`_on_close` handler, which hides the dialog) so dismissing the chest dialog is
not a no-op. Dismissing via Close emits **no** `choice_made`: a cancel is not a
take/gold choice and must not consume or remove the chest from the world. A
button in the scene that is not connected to a handler is a bug.

#### Scenario: Close button dismisses the dialog
- **Given** the ArtifactChestDialog is open
- **When** the user clicks the "Close" (cancel) button
- **Then** the dialog is hidden and the chest remains available in the world (no `choice_made` is emitted)

### Requirement: BattleUI collapse button remains usable
The collapse button in BattleUI SHALL toggle the bottom bar's visibility without
hiding itself. The button MUST live outside the panel it collapses so that
toggling the panel does not remove the button's ability to expand the panel
again.

#### Scenario: Collapse toggles the panel
- **Given** BattleUI is shown with a collapsed bottom bar
- **When** the user clicks the collapse button
- **Then** the bottom bar toggles visible/invisible and the collapse button stays visible and clickable

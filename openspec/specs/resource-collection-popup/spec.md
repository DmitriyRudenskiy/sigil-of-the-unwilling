# resource-collection-popup Specification

## Purpose

Shows a small centered popup when a resource is collected on the hero's world map, displaying the resource image, the amount gained, and an OK button, so the player sees immediate feedback.

## Requirements

### Requirement: Popup shows on resource collection
When a resource is successfully collected or extracted on the hero's world map, the system SHALL display a small centered popup containing a resource image, the amount gained, and an OK button. The popup SHALL appear once per collection event and SHALL NOT block or interrupt the collection side-effects (adding to inventory, marking the node exhausted, saving).

#### Scenario: Popup after extraction
- **WHEN** a discovered resource node is extracted and yields `amount > 0`
- **THEN** a popup appears showing the resource image, the amount, and an OK button

#### Scenario: Popup does not block collection
- **WHEN** the collection side-effects complete and the popup is scheduled
- **THEN** the resource is still added to inventory and the node is still marked exhausted regardless of whether the popup has been dismissed

### Requirement: Popup content reflects the collected resource
The popup SHALL render the image/icon of the specific collected resource and the exact integer amount gained for that resource. The displayed amount SHALL match the amount delivered to inventory.

#### Scenario: Correct resource and amount shown
- **WHEN** `12 gems` are collected
- **THEN** the popup shows the gems image/icon and the number `12`

#### Scenario: Name label present
- **WHEN** the popup is shown
- **THEN** it also shows a short resource name/label alongside the image and amount

### Requirement: Popup auto-dismisses after a short time
The popup SHALL auto-dismiss after a short display duration (approximately 4 seconds) in addition to being dismissible via the OK button.

#### Scenario: Popup auto-dismisses
- **WHEN** the popup has been visible for the display duration without being dismissed
- **THEN** it hides itself automatically

### Requirement: Dismiss via OK button
The popup SHALL be dismissed when the user presses the OK button. After dismissal the popup SHALL be hidden and reusable for the next collection.

#### Scenario: OK dismisses the popup
- **WHEN** the popup is visible and the user presses OK
- **THEN** the popup is hidden and a subsequent collection shows a fresh popup

### Requirement: Popup is non-intrusive and recoverable
The popup SHALL live on a dedicated overlay layer so it never overlaps gameplay-critical controls in a way that blocks them, and it SHALL NOT interfere with saving, turning, or other UI. If the collection event carries no resolvable resource image or amount, the system SHALL still show the popup with a placeholder image and `0` (or omit the amount) rather than crash.

#### Scenario: Overlay does not block gameplay
- **WHEN** the popup is visible
- **THEN** the rest of the UI (panels, buttons, save/turn actions) remains reachable and functional

#### Scenario: Missing image/amount degrades gracefully
- **WHEN** a collection event has an unknown resource id or amount `0`
- **THEN** the popup shows a placeholder image and does not error or crash

### Requirement: Verifiability after adding the popup
After the popup is added, the game SHALL still pass the existing operability verification (`game/tools/shell/run_operability.sh`) with verdict `CLEAN` (no console errors, no unallowlisted warnings) across scenes, scenarios, and unit tests.

#### Scenario: Operability stays CLEAN
- **WHEN** the popup is implemented and `run_operability.sh` is run
- **THEN** the verdict is `CLEAN`

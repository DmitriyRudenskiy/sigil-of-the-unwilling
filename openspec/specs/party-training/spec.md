# party-training Specification

## Purpose
Канон тренировки партии (02-mechanics §3.3 [КАНОН], Q-M55→(б), D-189): единственный способ пополнения партии, три позиции K-M15, SM рекрута с паузами, резидентная модель статусов (K-A5). Источник: GDD 02-mechanics §3.3, MVP-scope (Партия и тренировка, Q18), K-канон (K-M15, K-A5, K-M5).
## Requirements
### Requirement: Training only in the city
Training SHALL be available only when the hero is in the city. If the hero is on an expedition, training SHALL be unavailable with a tooltip explaining the reason. Training is the only way to replenish the party (Q18: companions are trained, not hired).

#### Scenario: Hero away
- **WHEN** the hero is on an expedition
- **THEN** the training UI is disabled
- **AND** a tooltip explains that the hero must be in the city

### Requirement: Three MVP training positions
The MVP SHALL have 3 training positions (K-M15 basic soldiers): infantry line (fighter), archer (ranger), wizard (T-041: stats are balance config). Each position SHALL require a city network (specific buildings). The MVP class mask for training SHALL be fighter/ranger/cleric/wizard/rogue/paladin (6 classes); the 3 basic soldiers are fighter/ranger/wizard (K-M15).

#### Scenario: Position requires network
- **WHEN** the archer position requires the archery range building
- **THEN** the position is unavailable until the building is built
- **AND** the UI shows the missing building

### Requirement: Training costs and time
Training costs SHALL be deducted immediately upon request. Training time SHALL be measured in days/ticks: `progress += tick / (t * N)`. **Q-M101 → (в) (агент, D-237, 2026-10-24):**
разрешение времени в MVP — «к следующему ходу»: тик кампании = одни сутки, субсуточного
планировщика нет, а канон-время 0.6/0.5 дня при таком тике даёт `progress ≥ 1` в том же тике.
TRAINING при этом остаётся наблюдаемым состоянием (заявка до тика; пауза разрушенным зданием
удерживает его неограниченно), поэтому SM рекрута не вырожден в одну запись. The MVP basic soldier costs SHALL follow the balance config (07-balance §3); where the GDD table and code diverge (C-12: "10 weapons" vs "2 iron"), the code and K-R2 resource registry are authoritative until the owner syncs the GDD.

#### Scenario: Cost deducted at request
- **WHEN** the player requests fighter training (20 food + 2 iron in code)
- **THEN** the costs are deducted immediately
- **AND** the training progress starts

### Requirement: Recruit state machine
A recruit SHALL follow the state machine REQUESTED → TRAINING → READY → (party) or STANDING. If the party is full, the recruit SHALL go to STANDING (in MVP the pool equals the party, so STANDING is Post-MVP). If the required city network is broken (building destroyed or sold), TRAINING SHALL transition to PAUSED; PAUSED → TRAINING on recovery WITHOUT resetting the timer. Pause SHALL NOT be cancellation.

#### Scenario: Network broken pauses training
- **WHEN** a raid destroys the building required for an active training
- **THEN** the training transitions to PAUSED
- **AND** the timer is preserved, not reset

#### Scenario: Recovery resumes training
- **WHEN** the required building is rebuilt
- **THEN** the paused training resumes from its previous progress
- **AND** no additional cost is charged

### Requirement: Resident status model (K-A5)
Each resident SHALL have exactly one status (Child/Worker/Mentor/Recruit/Fighter/Hero/Party-in-field). Conscription SHALL create a vacancy (production stops for that role). Population SHALL be a continuous quantity, not a discrete pool of "units".

#### Scenario: Conscription creates vacancy
- **WHEN** a worker is conscripted into the party
- **THEN** the worker's production role becomes vacant
- **AND** the affected building's output drops until the vacancy is filled

### Requirement: Fail states and edge cases
If population is below the threshold (10 per unit [proposal]), training SHALL be unavailable. A raid on a building under training SHALL pause it (PAUSED). Selling a building with an active aura SHALL remove the aura instantly and pause dependent training (50% refund, no exploit). STANDING recruits SHALL be visible in the UI.

#### Scenario: Low population blocks training
- **WHEN** the city population is below 10 per unit threshold
- **THEN** new training requests are rejected
- **AND** the UI shows the population constraint


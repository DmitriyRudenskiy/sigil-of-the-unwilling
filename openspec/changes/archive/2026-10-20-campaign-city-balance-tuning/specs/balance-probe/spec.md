# Spec Delta

## ADDED Requirements

### Requirement: Balance reports include campaign-city economy outcomes
The deterministic balance run SHALL report the canonical city's selected building counts and construction days, cumulative costs, workers assigned, daily production and consumption by MVP resource, ending stock, and milestone attainment through day 21. A run SHALL distinguish an unaffordable plan or missed balance target from a technical simulation failure and SHALL preserve enough baseline data for a before/after comparison.

#### Scenario: Review city balance metrics
- **WHEN** a canonical campaign-city balance run completes
- **THEN** its machine-readable report contains the building plan and per-day `food`, `wood`, and `iron` flows and stocks
- **AND** its human-readable summary identifies the first farm/barracks, first raid, and day-21 economy/defense milestones
- **AND** a repeated run with the same seed and actions has identical metrics

#### Scenario: A balance target is missed
- **WHEN** the run completes technically but a stock, affordability, or milestone target is missed
- **THEN** the report records a warning with the expected and actual values
- **AND** it does not report the balance as passing or fail the test solely for a tunable target miss

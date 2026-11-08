## MODIFIED Requirements

### Requirement: Section state changes only through a decision

`docs/06-economy.md` SHALL change its `status` only with a numbered decision. A
machine check of the state machine is not part of this requirement: its carrier was
removed, so the decision entry is the evidence. A `verified` state with an unresolved
`⏳` recommendation SHALL NOT be recorded.

#### Scenario: Audit ends with all rows confirmed

- **WHEN** every table row has a carrier and no contradiction is open
- **THEN** a `D-###` entry records the verification
- **AND** the section status becomes `verified` citing that entry

#### Scenario: Audit ends with open questions

- **WHEN** at least one row remains unconfirmed
- **THEN** the section status stays `deepened`
- **AND** the open `Q-M##` entries are listed in the change summary

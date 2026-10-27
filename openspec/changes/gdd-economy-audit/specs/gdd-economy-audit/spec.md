# gdd-economy-audit Specification

## ADDED Requirements

### Requirement: Every economy table row is confirmed by a carrier

Each data row of the source/sink table and of the campaign anchor table in
`docs/06-economy.md` SHALL be confirmed either by a code or data carrier named as
`path:line`, or by a registry entry (`D-###`, `K-##`), or by an open `Q-M##` that
names the missing fact. A row without one of the three SHALL NOT be counted as
audited.

#### Scenario: Row cites a carrier

- **WHEN** a row of the source/sink table is reviewed
- **THEN** the row or its note names a `path:line` inside `game/`, or a registry id
- **AND** the named file and line exist at review time

#### Scenario: Row has no carrier

- **WHEN** a row cannot be confirmed by code or registry
- **THEN** a `Q-M##` entry is opened for exactly that gap
- **AND** the row keeps its previous state and is listed as not audited

### Requirement: Claims are cited, not restated

The audit SHALL NOT rewrite a balance number or a formula from memory. Every claim
the audit writes SHALL carry the citation of the document, code or registry entry it
came from, and a claim whose sources disagree SHALL become a question rather than a
synthesis.

#### Scenario: Two sources disagree

- **WHEN** the document and the code state different values for the same quantity
- **THEN** the divergence is recorded with both citations
- **AND** a `Q-M##` entry asks the owner which one is canon
- **AND** neither text is silently rewritten

### Requirement: Section state changes only through a decision

`docs/06-economy.md` SHALL change its `status` only with a numbered decision, and the
state machine in `scripts/gdd_gate.py` SHALL be green after the change. A `verified`
state with an unresolved `⏳` recommendation SHALL NOT be recorded.

#### Scenario: Audit ends with all rows confirmed

- **WHEN** every table row has a carrier and no contradiction is open
- **THEN** a `D-###` entry records the verification
- **AND** the section status becomes `verified` citing that entry

#### Scenario: Audit ends with open questions

- **WHEN** at least one row remains unconfirmed
- **THEN** the section status stays `deepened`
- **AND** the open `Q-M##` entries are listed in the change summary

### Requirement: The audit is bounded to one section

The audit SHALL cover `docs/06-economy.md` only, and SHALL stop after three passes or
when the owner's answer is required, whichever comes first. Findings about other
sections SHALL be recorded as registry entries and SHALL NOT be pursued in the same
pass.

#### Scenario: A contradiction is found in another section

- **WHEN** reviewing economy surfaces a conflict in, say, `docs/02-mechanics.md`
- **THEN** it is written to the registry with a link to the other section
- **AND** the audit pass does not edit that section

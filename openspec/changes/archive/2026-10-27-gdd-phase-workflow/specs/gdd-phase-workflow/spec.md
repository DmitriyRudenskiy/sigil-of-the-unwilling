# gdd-phase-workflow Specification

## ADDED Requirements

### Requirement: Phase workflow is carried by the repository

The four-phase GDD workflow SHALL be defined by files in this repository — skills,
registries and scripts — and not by a chat prompt. Every step the method names SHALL
resolve to an existing carrier: a skill file, a registry document or a runnable
command.

#### Scenario: Named step resolves to a carrier

- **WHEN** a phase names a skill or a check
- **THEN** the workflow note names the file or command that performs it
- **AND** the named path exists in the repository or in the installed skills

#### Scenario: Duplicate carrier is rejected

- **WHEN** a new skill would restate logic an existing script already runs
- **THEN** the skill links to that script instead of restating it
- **AND** no second implementation of the same check is added

### Requirement: Re-grounding reads a bounded digest

Each entry into the workflow SHALL load a generated grounding digest instead of the
whole documentation vault. The digest SHALL stay within its declared line limit and
SHALL list dropped entries by count.

#### Scenario: Digest is generated and bounded

- **WHEN** `scripts/gdd_grounding.py` runs
- **THEN** it prints section-state counters, open questions, pending and
  vision-changing decisions, and the tail of each registry
- **AND** the output does not exceed the declared limit

#### Scenario: Pending owner items come first

- **WHEN** the digest is truncated
- **THEN** entries are dropped in the order vision-flag, pending, red, other
- **AND** vision-flagged entries are never dropped while red ones are kept

#### Scenario: Owner input is applied before new work

- **WHEN** the digest reports a decision awaiting confirmation
- **THEN** the workflow applies or overrides that decision before opening new
  questions
- **AND** affected sections and tickets are re-checked afterwards

### Requirement: Section states are machine-enforced

Section lifecycle `draft → audited → deepened → verified → locked` SHALL be stored in
frontmatter and validated by the documentation gate. Unknown or unlisted states SHALL
fail the gate.

#### Scenario: New states pass the gate

- **WHEN** a section carries `status: audited`, `verified` or `locked`
- **THEN** the documentation gate accepts it

#### Scenario: Downgrade needs a recorded decision

- **WHEN** a section moves from `verified` back to `deepened`, or from `locked` back
  to `verified`
- **THEN** a decision entry names the reason
- **AND** the gate reports a downgrade that carries no decision reference

#### Scenario: Non-GDD roles are exempt

- **WHEN** a registry, audit log or bank note carries `reference`, `snapshot` or
  `archived`
- **THEN** the lifecycle check skips it

### Requirement: Registry fields are complete for new records

New question records SHALL carry type (`agent` or `human`), priority and status; new
decision records SHALL record rejected alternatives and cascade; new risk records
SHALL be numbered. Existing records are tracked as a shrinking backlog.

#### Scenario: New question without type fails

- **WHEN** a question is added without `agent` or `human`
- **THEN** the workflow gate exits non-zero and names the row

#### Scenario: Legacy rows are a backlog, not a failure

- **WHEN** the gate counts rows missing the newer fields
- **THEN** it reports the count as backlog size
- **AND** the run stays green while the count does not grow

#### Scenario: Pending recommendation is visible

- **WHEN** a `human` question is closed by applying the agent's recommendation
- **THEN** the decision entry is marked pending
- **AND** questions that change the game's vision carry the additional vision flag

### Requirement: Verification claims carry evidence

Every completed verification item SHALL cite a section and quote it. Items that
cannot be cited are reported as not done. Machine-checkable items SHALL be run by the
named scripts rather than asserted.

#### Scenario: Uncited check is not done

- **WHEN** a verification line states a mechanic is complete without a section link
  and quote
- **THEN** the item counts as incomplete and returns for rework

#### Scenario: Machine checks run instead of being asserted

- **WHEN** a phase reports verification
- **THEN** the report includes the exit status of the link, code-consistency and
  workflow gates

### Requirement: Phase completion is tagged and recorded

Each phase SHALL end with a commit and an annotated tag (`v1-audited`, `v2-deepened`,
`v4-locked`) whose message names the gate artifact. Phase results SHALL be summarized
in the changelog with counts before and after.

#### Scenario: Phase tag points at evidence

- **WHEN** a phase ends
- **THEN** the tag message references the gate artifact path
- **AND** the changelog entry states measured before/after numbers

#### Scenario: Empty grill pass does not burn an iteration

- **WHEN** a grill loop finds nothing left to close
- **THEN** the loop exits early without increasing the pass counter
- **AND** no tag is created for the empty pass

### Requirement: Blocking is not inherited from questions

A question addressed to the owner SHALL never stop work: the recommended option is
applied, the decision is recorded as pending, and production continues. Owner
overrides remain authoritative at any later time.

#### Scenario: Work continues past an owner question

- **WHEN** a red `human` question is opened mid-phase
- **THEN** the recommendation is applied and marked pending
- **AND** the phase proceeds without waiting for an answer

#### Scenario: Late override cascades

- **WHEN** the owner overrides a recorded decision
- **THEN** sections and tickets derived from it are re-derived on the next entry
- **AND** the override is recorded as a new decision, not an edit of the old one

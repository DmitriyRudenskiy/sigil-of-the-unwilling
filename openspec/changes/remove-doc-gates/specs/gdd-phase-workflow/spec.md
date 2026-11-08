## RENAMED Requirements

- FROM: `### Requirement: Section states are machine-enforced`
- TO: `### Requirement: Section states are recorded in frontmatter`

## MODIFIED Requirements

### Requirement: Section states are recorded in frontmatter

Section lifecycle `draft → audited → deepened → verified → locked` SHALL be stored in
frontmatter and SHALL be the only carrier of the state. Machine validation of the
lifecycle is not carried in this repository: the checker and its runner were removed,
so an unknown or unlisted state is a defect found at diff review, not a red verdict.

#### Scenario: New states pass

- **WHEN** a section carries `status: audited`, `verified` or `locked`
- **THEN** the frontmatter is accepted as-is and no tool output is expected

#### Scenario: Downgrade needs a recorded decision

- **WHEN** a section moves from `verified` back to `deepened`, or from `locked` back
  to `verified`
- **THEN** a decision entry names the reason
- **AND** a downgrade without a decision reference is a review finding

#### Scenario: Non-GDD roles are exempt

- **WHEN** a registry, audit log or bank note carries `reference`, `snapshot` or
  `archived`
- **THEN** the lifecycle rule does not apply to it

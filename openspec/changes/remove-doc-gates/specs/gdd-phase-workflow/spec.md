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

## REMOVED Requirements

### Requirement: Re-grounding reads a bounded digest

**Reason**: Единственным исполнителем требования был `scripts/gdd_grounding.py`
(генерировал дайджест: счётчики состояний секций, открытые вопросы, pending- и
vision-решения, хвосты реестров). Скрипт удалён вместе с
`scripts/doc_gates.sh`, ни `game/run_tests.sh`, ни CI-2 его не звали, поэтому
«дайджест не превышает лимит» и «vision-записи не выбрасываются» больше не имеет
носителя — смена `remove-doc-gates`.

**Migration**: Вход в рабочий цикл читает реестры напрямую
(`docs/DECISIONS.md`, `docs/QUESTIONS.md`, `docs/mvp/TICKETS.md`); порядок
«сначала ответ владельца, потом новая работа» остаётся правилом
`gdd-phase-workflow` и проверяется ревью диффа. Возврат дайджеста — новой сменой,
обязанной завести и исполнителя, и вызов (п. «Проверка без исполнителя»
capability `verification-naming`).

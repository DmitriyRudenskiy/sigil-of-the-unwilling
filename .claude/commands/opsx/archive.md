# /opsx:archive - Archive Completed Changes

## Purpose

Archive completed changes in the OPSX experimental workflow. This command finalizes a change by:
- Verifying all artifacts are complete via artifact graph analysis
- Checking task completion status
- Prompting for `/opsx:sync` if specs need applying
- Moving the change to `archive/YYYY-MM-DD-<name>/`
- Preserving `.openspec.yaml` schema metadata

## Usage

```bash
/opsx:archive [change-name]
```

If no change name is provided, lists available pending changes.

## Workflow

### 1. Identify Change

- If change name provided: validate it exists in pending changes
- If no name: list available pending changes and prompt user
- Load change metadata from `.openspec/changes/<change-name>/`

### 2. Verify Completion Status

Check artifact completion using artifact graph (schema-aware):

```yaml
completion_check:
  - artifact_graph_complete: true/false
  - all_specs_implemented: true/false
  - all_tasks_completed: true/false
  - schema_validated: true/false
```

**Artifact Graph Validation:**
- Traverse artifact dependency graph
- Verify each artifact has corresponding implementation
- Check schema compliance for each artifact
- Validate cross-artifact references

**Task Completion:**
- Review all tasks in change proposal
- Mark tasks as complete/incomplete
- Identify any blocked or failed tasks

### 3. Pre-Archive Sync Check

Before archiving, verify specs are applied:

```
⚠️  Some specs are not yet applied to the codebase.
   
   Run /opsx:sync before archiving? [Y/n]
```

**Do NOT programmatically apply specs.** Instead:
- Detect unapplied specs via artifact graph
- Prompt user to run `/opsx:sync` manually
- Allow user to defer sync (with warning)
- Only proceed to archive after sync confirmation

### 4. Archive Operation

Move change to archive with structured naming:

```
Source: .openspec/changes/<change-name>/
Target: .openspec/archive/YYYY-MM-DD-<change-name>/
```

**Preserved Metadata:**
- `.openspec.yaml` schema definitions
- Artifact graph structure
- Task completion records
- Spec-to-code mappings
- Change proposal document
- Timestamp of archival

### 5. Post-Archive Actions

- Update change index
- Log archival event
- Clean up temporary files (if any)
- Report success with archive location

## Error Handling

### Incomplete Artifacts

```
❌ Cannot archive: 3 artifacts incomplete
   
   Incomplete artifacts:
   - src/auth/login.ts (missing tests)
   - src/api/users.ts (schema mismatch)
   - docs/api.md (outdated spec)
   
   Run /opsx:continue to complete remaining work.
```

### Unapplied Specs

```
⚠️  Warning: 5 specs not applied to codebase
   
   Recommended: Run /opsx:sync before archiving
   
   Proceed without sync? [y/N]
```

### Missing Change

```
❌ Change '<name>' not found
   
   Pending changes:
   - auth-system
   - api-refactor
   - ui-redesign
   
   Use /opsx:list to see all changes.
```

## Output Format

### Success

```
✓ Change 'auth-system' archived successfully

   Archive location: .openspec/archive/2024-01-15-auth-system/
   Artifacts archived: 12
   Tasks completed: 8
   Schema version: 1.2.0
   
   Run /opsx:restore <name> to restore this change.
```

### Failure

```
✗ Archive failed: Incomplete artifacts detected

   Please complete the following before archiving:
   - Complete pending implementations
   - Apply specs via /opsx:sync
   - Resolve schema validation errors
   
   Use /opsx:status for detailed progress.
```

## Integration Points

### Related Commands

- `/opsx:list` - List pending and archived changes
- `/opsx:status` - Show completion status
- `/opsx:sync` - Apply specs to codebase (run before archive)
- `/opsx:continue` - Resume incomplete work
- `/opsx:restore` - Restore archived change

### Artifact Graph

Uses schema-aware artifact tracking:
- Validates artifact completeness against schema
- Checks dependency resolution
- Verifies spec-to-code mapping integrity
- Ensures all referenced artifacts exist

### Schema Preservation

Maintains `.openspec.yaml` metadata:
```yaml
schema_version: 1.2.0
artifact_count: 12
archived_at: 2024-01-15T14:30:00Z
original_change_name: auth-system
completion_status: complete
```

## Constraints

- **No auto-sync**: Must prompt user to run `/opsx:sync` manually
- **Schema-aware validation**: Use artifact graph, not just file presence
- **Preserve metadata**: Keep all `.openspec.yaml` data intact
- **Structured naming**: Use `YYYY-MM-DD-<name>` format for archives
- **Reversible**: Archive must support future restore operations

## Examples

### Archive Complete Change

```bash
/opsx:archive auth-system

→ Verifying artifact completion...
→ All 12 artifacts complete ✓
→ Checking spec sync status...
⚠️  3 specs not applied. Run /opsx:sync first? [Y/n]
→ User runs: /opsx:sync auth-system
→ Archiving change...
✓ Change 'auth-system' archived to .openspec/archive/2024-01-15-auth-system/
```

### List Available Changes

```bash
/opsx:archive

Pending changes available for archival:
1. auth-system (12 artifacts, ready)
2. api-refactor (8 artifacts, 2 incomplete)
3. ui-redesign (15 artifacts, ready)

Which change to archive? [1-3]
```

### Force Archive Without Sync

```bash
/opsx:archive api-refactor

→ Verifying artifact completion...
→ All 8 artifacts complete ✓
→ Checking spec sync status...
⚠️  5 specs not applied. Run /opsx:sync first? [y/N]
→ n
⚠️  Warning: Archiving without sync may cause inconsistencies.
   Proceed anyway? [y/N]
→ y
→ Archiving change...
✓ Change 'api-refactor' archived (warning: specs not synced)
```

## Skill Definition

```yaml
skill: opsx-archive-skill
type: slash-command
triggers:
  - /opsx:archive
  - /opsx archive
description: Archive completed changes in OPSX experimental workflow
capabilities:
  - artifact-graph-validation
  - completion-status-check
  - sync-prompt
  - metadata-preservation
  - structured-archival
workflow:
  - identify-change
  - verify-completion
  - check-sync-status
  - prompt-for-sync
  - execute-archive
  - report-result
```

# arena-model-decomposition — delta (project-audit-fixes)

## MODIFIED Requirements

### Requirement: Version-based cluster cache is correct
The cluster cache SHALL be keyed on city state; placing a building invalidates
the cached clusters so the next read recomputes from the current buildings.
Deserialization of a city (which repopulates its buildings) is a state change
too and MUST invalidate the cached clusters so a loaded city reports correct
clusters on first read.

#### Scenario: Placing a building refreshes the cache
- **WHEN** a building is added to the arena and clusters are read again
- **THEN** the result reflects the new building without a stale entry

#### Scenario: Loading a city refreshes the cache
- **WHEN** a City is deserialized (its buildings repopulated) and clusters are read
- **THEN** the result reflects the deserialized buildings without a stale entry

## Purpose

Remove the global mutable `ServiceContainer.current` singleton and replace direct reads with explicitly injected dependencies, without changing what the services provide.

## ADDED Requirements

### Requirement: No direct reads of the global service holder

Consumer code SHALL NOT read `ServiceContainer.current` directly; services SHALL be supplied through injection (constructor, `setup`, or an explicit parameter).

#### Scenario: Consumers no longer touch the global holder
- **WHEN** a service such as resource extraction is configured
- **THEN** it receives its dependencies via injection instead of `ServiceContainer.current`

### Requirement: Services keep the same behavior

Injected services SHALL provide the same lookups and behavior as before, so existing callers observe identical results.

#### Scenario: Resource lookup still works
- **WHEN** a resource is looked up through the injected registry
- **THEN** it returns the same definition as the previous global-backed lookup

### Requirement: The global holder is removed cleanly

`ServiceContainer` SHALL no longer expose a mutable `static var current` once migration is complete; remaining references in the codebase SHALL be zero.

#### Scenario: No lingering global references
- **WHEN** the source tree is searched for `ServiceContainer.current`
- **THEN** no references remain in `game/scripts/`

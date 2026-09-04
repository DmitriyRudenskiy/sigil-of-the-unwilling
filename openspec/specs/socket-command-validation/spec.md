# socket-command-validation Specification

## Purpose

Validate incoming socket command arguments before dispatch so that malformed or wrong-typed input produces a structured error instead of crashing the server.

## Requirements

### Requirement: Command arguments are validated against a schema

`SocketController` SHALL validate each command's arguments against a declared schema (required fields and expected types) before routing.

#### Scenario: Missing field is rejected
- **WHEN** a command arrives without a required field
- **THEN** the server returns an `{"error": "..."}` response and performs no side effect

#### Scenario: Wrong type is rejected
- **WHEN** a field is supplied with the wrong type (e.g. an integer where a string is expected)
- **THEN** the server returns an `{"error": "..."}` response instead of crashing

### Requirement: Malformed input never crashes the server

The routing path (including JSON parsing) SHALL guard against malformed input and always respond with a structured error.

#### Scenario: Non-string action is handled
- **WHEN** a command payload contains `{"action": 123}`
- **THEN** the server returns an error dict rather than throwing

### Requirement: Valid commands still dispatch

Well-formed commands that pass validation SHALL route and execute exactly as before.

#### Scenario: A valid command runs
- **WHEN** a command with all required, correctly-typed fields is received
- **THEN** it is routed to the correct handler and applied

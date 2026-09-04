# game-logging Specification

## Purpose

GameLogger produces human-readable console output; in headless mode that output must be plain text with no color markup so automated runners and logs stay readable.

## Requirements

### Requirement: GameLogger outputs without color markup in headless

GameLogger SHALL emit `info`/`warn`/`error`/`trace` in headless mode without any `[color=...]` markup; the tag is drawn without color wrapping.

#### Scenario: Headless output has no tags
- **WHEN** `info`/`warn`/`error`/`trace` are called in `--headless`
- **THEN** the line is emitted without any `[color=...]` markup

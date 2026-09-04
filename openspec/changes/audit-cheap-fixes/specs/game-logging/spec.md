---
description: "GameLogger output format, including headless-safe logging."
---

## MODIFIED Requirements

### Requirement: GameLogger выводит без сырых тегов в headless
GameLogger (`core/GameLogger.gd`) SHALL выводить `info`/`warn`/`error`/`trace`
в headless-режиме без `[color=...]` markup (тег рисуется без color-обвязки).

#### Scenario: headless-вывод без тегов
- **WHEN** `info`/`warn`/`error`/`trace` вызваны в `--headless`
- **THEN** строка выведена без `[color=...]` markup

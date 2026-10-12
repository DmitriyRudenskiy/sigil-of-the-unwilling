---
title: gdlint-конфиг — предложение (раунд 12 §3)
tags:
  - ci
  - process
  - gdlint
status: draft
date: 2026-10-12
---

# gdlint-конфиг — предложение владельцу (раунд 12 §3)

**Статус: report-only до утверждения** (приказ раунда 12 §2-2: «конфиг стиля —
решение владельца; до утверждения — report-only верен»). Утверждение = новый
реестровый акт; до него CI-2-шаг Lint не гейтит gdlint (только gdparse).

## Измерения (gdtoolkit 4.5.0, `game/scripts` + `game/tests`, 2026-10-12)

| Конфиг | Нарушений |
| --- | --- |
| Дефолт (без конфига) | **2444** |
| Предложенный (ниже) | **738** |

Остаток 738 по правилам:

| Правило | Кол-во | Характер | Действие |
| --- | --- | --- | --- |
| trailing-whitespace | 379 | гигиена, авто-фикс | `gdlint --fix` |
| max-line-length (>120) | 300 | стиль | решение владельца: 120 / 150 / disable |
| mixed-tabs-and-spaces | 47 | гигиена, авто-фикс | `gdlint --fix` |
| unnecessary-pass | 5 | гигиена, авто-фикс | `gdlint --fix` |
| duplicated-load | 5 | реальные (двойные preload/const) | ручной фикс, 3 файла |
| comparison-with-itself | 2 | **false positive**: осознанный NaN-чек `avg == avg` (float NaN ⇔ не равен себе) в `test_benchmarks.gd:152`, `test_memory_profile.gd:68` | замена на `is_finite()` или allowlist |

Авто-фикс-состав: 431 (trailing-whitespace + mixed-tabs-and-spaces +
unnecessary-pass) — одним `gdlint --fix`, без изменения семантики.

## Отключённые правила (с основаниями)

| Правило | Дефолт-шум | Основание отключения |
| --- | --- | --- |
| class-definitions-order | 572 | Godot-идиом: порядок `@onready`/`const`/секций — конвенция проекта, не дефект |
| unused-argument | 75 | interface-conformance (хуки/колбэки с фиксированной сигнатурой) |
| load-constant-name | 131 | проект-идиом: `_Name`-префикс preload-констант |
| function-argument-name | 47 | проект-идиом: суффиксы `name_`/`def_` (уникальность в scope) |
| class-variable-name | 36 | проект-идиом: капс для constant-like переменных |
| max-public-methods | 34 | архитектурное, не стиль |
| function-variable-name | 32 | проект-идиом: `_villages`/`traits_` |
| max-returns | 24 | архитектурное (guard-clause стиль проекта) |
| no-elif-return | 6 | мнение стиля |
| function-arguments-number | 6 | registry-паттерн (spell_registry, artifact_registry) |
| unnecessary-pass | — | **не** отключено (5, авто-фикс) |
| max-file-lines | 1 | архитектурное |
| no-else-return | 3 | мнение стиля |
| constant-name | 1 | проект-идиом (`CatalogPath`) |

## Предложенный `.gdlintrc` (вербатим)

```yaml
# .gdlintrc — минимальный набор под gdparse-зелёное дерево (раунд 12 §3).
# Шум дефолта: 2444 → остаток 738 (см. docs/mvp/GDLINT-PROPOSAL.md).
# До утверждения владельцем — report-only (не гейтит).
disable:
  - class-definitions-order
  - load-constant-name
  - function-argument-name
  - class-variable-name
  - function-variable-name
  - max-public-methods
  - max-returns
  - function-arguments-number
  - max-file-lines
  - constant-name
  - unused-argument
  - no-elif-return
  - no-else-return
max-line-length: 120
```

## Путь включения (после утверждения)

1. Владелец утверждает конфиг (реестровый акт) + решение по max-line-length.
2. `gdlint --fix` (431 авто-фикс) + ручной фикс 7 (duplicated-load ×5, NaN-чеки ×2).
3. CI-2-шаг Lint: gdlint → gate (отдельным шагом, после зелёного прогона).
4. Остаток 0 = целевое состояние.

## Связь

CI-2 (lint-шаг, раунд 10 §3.4), D-144 (не красим гейт на первом прогоне),
TICKETS CI-2 (gdlint report-only).

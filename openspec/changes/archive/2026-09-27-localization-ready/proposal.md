# Proposal: localization-ready

## Status
status: completed *(legacy backfill, верифицировано по коду 2026-09-27)*

## Summary
Подготовка проекта к локализации: все пользовательские строки вынесены в gettext-каталог, добавлены компилируемые PO-файлы для EN/RU и мастер-шаблон POT.

## Verification
- `game/locale/messages.pot` — мастер-шаблон строк.
- `game/locale/en.po`, `game/locale/ru.po` — каталоги переводов.
- Строковый API Godot (`tr()`-паттерн) используется в UI-скриптах (`game/scripts/ui/`).

## Acceptance Criteria
- [x] Каталог переводов создан и поддерживает EN/RU
- [x] POT-шаблон regenerated из исходников
- [x] Заглушки под расширение языка (новая пара .po без правок кода)

## Note
`skip_specs: true` — спецификация не требовалась. Готово к архивации без sync.

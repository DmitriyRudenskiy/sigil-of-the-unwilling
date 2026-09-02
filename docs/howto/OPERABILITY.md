# Полная проверка работоспособности (operability)

Полный прогон всех точек входа проекта: сцены, авто-сценарии, тесты.

## Запуск

```bash
bash game/tools/shell/run_operability.sh
```

Скрипт обёртывает запуск Godot через `run_godot` (sleep + kill, без `timeout` —
на macOS `timeout` недоступен), даёт каждой точке входа индивидуальный таймаут
и не зацикливается (run-and-fix — максимум 5 итераций).

## Что прогоняется

- Сцены через SceneTree-скрипты (`-s`).
- Авто-сценарии `scenario_{1..7}` через `play_scenario.sh`.
- Юнит-тесты через `run_all_ci_checks.sh --tests`.

## Интерпретация

- Итог пишется в `/tmp/operability_report.md`: точки входа, находки, вердикт
  «CLEAN (ошибок: 0, предупреждений: 0)» или «DIRTY».
- Маркеры провала — только Godot-префиксы (`SCRIPT ERROR`, `SCRIPT WARNING`).
- Известные предсуществующие предупреждения занесены в `docs/CONSOLE_ALLOWLIST.md`.

## Исправление находок

При `SCRIPT ERROR` / runtime-ошибке / предупреждении вне allowlist — см. скил
`.pi/skills/godot-run-and-fix/SKILL.md` (run → capture → scan → fix → verify).

## Полный CI

```bash
bash game/tools/shell/run_all_ci_checks.sh        # тесты + operability + sanity
```

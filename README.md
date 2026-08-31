# Sigil of the Unwilling

Godot 4.7 hex strategy prototype.

> Игровой Godot-проект — в папке `game/` (см. `game/README.md`): код `scripts/`, сцены `scenes/`, ассеты `assets/`, плюс `tests/` и `tools/` (исполняются на Godot с `--path game`).
> Dev-материалы — в корне репозитория: `docs/`, `backup_assets/`, `lair/`, `prototype/`; временные файлы — в `tmp/`.

## Checks

```bash
./game/tools/shell/run_all_ci_checks.sh
```

## Manual run

Open `game/` in Godot 4.7 and run `F5` (main scene: `game/scenes/MainMenu.tscn`).

## Tools

- `game/tools/make_grid.py`: Собирает изображения из директории в грид 4x4 (1024x1024, ячейки 256x256). Если изображений > 16, создает несколько файлов. Пустые ячейки заполняются зеленым хромакеем (#00FF00).

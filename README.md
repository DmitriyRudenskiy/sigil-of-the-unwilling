# HoMM3-like Prototype

Godot 4.7 hex strategy prototype.

## Checks

```bash
./tools/run_checks.sh
```

## Manual run

Open project in Godot 4.7 and run `scenes/MainMenu.tscn` or `scenes/World.tscn`.

## Tools

- `scripts/tools/make_grid.py`: Собирает изображения из директории в грид 4x4 (1024x1024, ячейки 256x256). Если изображений > 16, создает несколько файлов. Пустые ячейки заполняются зеленым хромакеем (#00FF00).

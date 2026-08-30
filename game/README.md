# Игра (портативная папка)

Самодостаточный проект Godot — папку можно скопировать на другой компьютер.

## Запуск

1. Установить Godot **4.7** (стандартная версия, не .NET): https://godotengine.org/download
2. Открыть проект: Godot → Import → выбрать `project.godot` из этой папки
   (или просто дважды кликнуть по `project.godot`, если Godot ассоциирован).
3. F5 — запуск. Main-сцена: `scenes/MainMenu.tscn`.

## Состав

- `project.godot`, `icon.svg` — конфиг проекта
- `scenes/` — MainMenu, World, Battle, CityArena
- `core/ city/ data/ demographics/ economy/ entities/ systems/ ui/ world/` — код
- `assets/` — спрайты, аудио, иконки
- `tilesets/` — гекс-тайлсеты
- `.godot/` — кэш импорта (можно удалить, Godot пересоздаст)

Тесты (`tests/`), утилиты (`tools/`), доки (`docs/`) и плагины — вне этой папки.

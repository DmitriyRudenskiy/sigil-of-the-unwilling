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
- `tests/` — тесты (`run_tests.gd`, `test_base.gd`, `fakes/`)
- `tools/` — утилиты и dev-скрипты (`shell/`, `spell_validation/`, `scenarios/`)
- `docs/` — документация
- `previews/` — превью биомов
- `backup_assets/` — запасные ассеты
- `prototype/` — HTML-прототипы
- `scenes/` — MainMenu, World, Battle, CityArena + BiomePreview, TestTerrain
- `lair/` — материалы лаи
- `tmp/` — черновые логи и скрипты
- `.godot/` — кэш импорта (можно удалить, Godot пересоздаст)

Это самодостаточная папка: всё (код, тесты `tests/`, утилиты `tools/`, доки `docs/`,
`previews/`, `backup_assets/`, `prototype/`, `scenes/`, `lair/`, `tmp/`) — внутри неё.

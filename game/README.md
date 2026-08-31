# Игра (портативная папка)

Самодостаточный проект Godot — папку можно скопировать на другой компьютер.

## Запуск

1. Установить Godot **4.7** (стандартная версия, не .NET): https://godotengine.org/download
2. Открыть проект: Godot → Import → выбрать `project.godot` из этой папки
   (или просто дважды кликнуть по `project.godot`, если Godot ассоциирован).
3. F5 — запуск. Main-сцена: `scenes/MainMenu.tscn`.

## Состав

- `project.godot`, `icon.svg` — конфиг проекта
- `scripts/` — весь GDScript-код: `autoload/` (10 синглтонов), `core/`, `systems/`,
  `entities/`, `world/`, `city/`, `ui/`, `economy/`, `demographics/`, `data/`
- `scenes/` — MainMenu, World, Battle, CityArena
- `assets/` — спрайты, аудио, иконки, `data/` (spells.json), `settings/` (аудиобусы),
  `tilesets/` (гекс-тайлсеты)
- `tests/` — тесты (`run_tests.gd`, `test_base.gd`, `fakes/`; раннер сканирует `res://tests/**`)
- `tools/` — утилиты и dev-скрипты (`shell/`, `spell_validation/`, `scenarios/`)
- `.godot/` — кэш импорта (можно удалить, Godot пересоздаст)

Это самодостаточная папка: всё, что нужно игре для запуска (код `scripts/`, сцены
`scenes/`, ассеты `assets/`), плюс тесты `tests/` и утилиты `tools/` (они исполняются
на Godot с `--path game`) — внутри неё.

Несвязанные с игрой dev-материалы живут в корне репозитория: `docs/`, `backup_assets/`,
`lair/`, `prototype/`; временные файлы — в корневом `tmp/`.

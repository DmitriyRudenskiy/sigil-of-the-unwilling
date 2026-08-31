# Сохранение и загрузка

Трёхуровневая система: низкоуровневый JSON-менеджер → контейнер данных →
персистентность мира.

## Слои

| Уровень | Класс | Ответственность |
| --- | --- | --- |
| JSON | `core/SaveManager.gd` | Запись/чтение `user://save_slot_1.json`, коды ошибок |
| Данные | `core/SaveData.gd` | Контейнер файла сохранения (версии, миграции) |
| Мир | `world/WorldPersistence.gd` | save/load/restart/seed/session-состояние |

## SaveManager (`core/SaveManager.gd`)

Низкоурневый уровень. Путь — `SAVE_PATH := "user://save_slot_1.json"`.
**Все ошибки возвращаются как коды** (`SaveError`), а не молчаливый null:
`FILE_NOT_FOUND`, `FILE_OPEN_FAIL`, `PARSE_FAIL`, `INVALID_DATA`, `WRITE_FAIL`, `OK`.

- `save_game(data: Variant) -> SaveError` — `data.to_dict()` → `JSON.stringify(..., "\t")`
  → `FileAccess.WRITE`.
- `load_game() -> Dictionary` — `{"error", "data", "message"}`. Парсит JSON,
  валидирует корень (`Dictionary`), собирает `SaveData` из `from_dict`.
- `load_game_legacy()`, `load_slot()`, `has_save()`, `delete_save()`.

> ⚠️ Лог «SaveManager: parse error» — **информационный** (например, при
> проверке отсутствия сейва/некорректного файла), не критическая ошибка.

## SaveData (`core/SaveData.gd`)

Контейнер файла сохранения:

| Поле | Значение |
| --- | --- |
| `version` | `CURRENT_VERSION = 3` |
| `generator_version` | `CURRENT_GENERATOR_VERSION = 1` |
| `run_seed` | Seed сессии |
| `date` | `{"month", "week", "day"}` |
| `hero` | `hero.serialize()` |
| `world` | `world_delta.serialize()` |
| `cities` | Сериализованные города (`City.serialize()`) |
| `characters` | `CharacterRegistry.serialize()` (v3) |

`to_dict()` / `from_dict()` + миграции: `_migrate_v1_to_v2` (добавляет
`hero.time_mp_spent` для персистентности маны), `_migrate_v2_to_v3` (города и
персонажи). `is_valid()` — проверка версии/седа.

## WorldPersistence (`world/WorldPersistence.gd`)

Обёртка над `SaveManager` + состояние мира:

- `save_game(hero, cities, characters) -> bool` — собирает `SaveData`
  (run_seed, дата, герой, world_delta, города, персонажи), вызывает
  `_save_manager.save_game()`. Возвращает `false`, если `session`/`hero`/
  `world_delta` null.
- `load_game() -> SaveData` / `load_game_with_error() -> Dictionary` /
  `request_load_game() -> SaveData` (через `pending_save`).
- `apply_loaded_save(data, ctx)` — десериализует `world_delta`, восстанавливает
  дату, пересоздаёт города по uid (`_restore_cities`, v2-сейв с пустыми городами
  не тронут), восстанавливает персонажи (`_restore_characters`), снимает
  побеждённых врагов.
- `set_date` / `get_date`, `get_run_seed`, `get_session_for_seed`, `restart_game`.

## Жизненный цикл

1. **Save:** `WorldController.save_game()` → `WorldPersistence.save_game(...)` →
   `SaveManager.save_game()` → JSON на диск.
2. **Load:** `request_load_game()` ставит `pending_save`; `WorldBootstrap._resolve_session`
   забирает его, инициализирует сессию по seed; `WorldController._ready` →
   `_persistence.apply_loaded_save(...)`.

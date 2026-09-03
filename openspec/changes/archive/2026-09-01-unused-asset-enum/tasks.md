## 0. Решения (приняты пользователем)
- Значения enum: семантические (BOOT/HAND/WARRIORS) для определённых + числовые (CURSOR_NN).
- Охват поиска: все неиспользуемые асеты (cursors / textures / ui / raw / audio / other).
- Формат резолвера: `%02d` (cursor_01); числовой fallback.
- Интеграция с `context-cursor`: enum `CursorSprite` — база для `CursorController`.

## 1. Поиск всех неиспользуемых асетов
### 1.1
Реализовать анализатор референсов асетов (D1). ✅ `game/tools/analyze_assets.py`
- [x] used-set = static (.gd/.tscn) ∪ data-driven
- [x] Асет неиспользуемый, если ни один used-путь не резolves его res://
- [x] `.import` игнорируется
- [x] Категоризация: cursors / textures / ui / raw / audio / other (и artifacts/tiles/units)

## 2. Enum для пронумерованных асетов
### 2.1
Создать `game/scripts/data/CursorSprite.gd` (D2). ✅
- [x] `class_name CursorSprite`, enum: семантические (BOOT/HAND/WARRIORS) + числовые (CURSOR_NN)
- [x] `path(id: int) -> String` → `res://assets/cursors/cursor_%02d.png` (числовой fallback)
- [x] `path_by_name(name)` — резолвер по семантическому/числовому имени

### 2.2
Использовать enum вместо строковых `cursor_NN.png` (D3).
- [x] Проверено: строковых `cursor_NN.png`-референсов в коде нет (курсоры ранее не
      были задействованы) — enum становится единственным типизированным доступом
      для будущих ссылок; заменять нечего.

### 2.3
Интеграция с `context-cursor` (D4): `CursorController` резолвит текстуры через
`CursorSprite.path(...)`; семантические привязки (BOOT/HAND/WARRIORS → файл) —
в `context-cursor`. ⏳ forward-looking
- [x] `CursorSprite.path()`/`path_by_name()` предоставлены как точка интеграции;
      фактическая прошивка `CursorController` (в `context-cursor`) — отдельным циклом.

### 3.2
Добавить автотесты: 32 значения enum, резолвер пути. ✅ `tests/test_cursor_sprite.gd`
- [x] Enum содержит 32 значения
- [x] `path()` резолвит в `res://assets/cursors/cursor_NN.png`
- [x] `tests/test_cursor_sprite.gd` — 0 failed

## 3. Проверка и коммит
### 3.1
Запустить `bash game/tools/shell/run_operability.sh`, убедиться в вердикте CLEAN.
- [x] `run_operability.sh` → CLEAN (0 ошибок, 0 предупреждений); SCRIPT ERROR/Parse/Run: 0
- [x] `docs/CONSOLE_ALLOWLIST.md` не требовал обновления

### 3.2
Добавить автотесты: 32 значения enum, резолвер пути.
- [x] Enum содержит 32 значения (test_cursor_sprite.gd: 45 passed, 0 failed)
- [x] `path()` резолвит в `res://assets/cursors/cursor_NN.png`

### 3.3
Комит только файлов цикла `unused-asset-enum`.
- [x] `git commit` 12043b1: analyze_assets.py + CursorSprite.gd + test_cursor_sprite.gd
- [x] Чужие файлы (D-удаления реорга, другие `??`) не вынолись в комит

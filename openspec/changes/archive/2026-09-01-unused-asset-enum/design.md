## Context

Текущее состояние асетов и референсов:

- **Курсоры**: `game/assets/cursors/cursor_01.png … cursor_32.png` (32 файла, 128×128,
  bg-removed через `game/tools/extract_cursors.py`). **Никто не использует** — нет ни
  одного референса в `.gd`/`.tscn`. Идентифицируются только порядковым номером.
- **Контекст (`context-cursor`)**: планирует `CursorController` (autoload) с картой
  `mode -> {texture, hotspot}`, но конкретные `cursor_01..32.png` unnamed — нужно
  определить, какой курсор = boot/hand/два воина.
- **Реестр асетов**: отсутствует. Ссылки на асеты — строки `res://assets/...` (напр.
  `InfoPanel.gd`: `res://assets/ui/icons/treasure.png`).
- **Поиск неиспользуемых асетов**: циклы `archive-unused-assets` описывает детектор
  (static ∪ data-driven), но он не реализован (цикл ожидает apply).

Недостаёт: enum для пронумерованных асетов (курсоры) и типизированного обращения к ним.

## Goals

- Найти неиспользуемые асеты (поиск).
- Для пронумерованных (курсоры) — enum + резолвер пути.

## Decisions

### D1: Поиск неиспользуемых асетов
Статический анализатор (напр. `game/tools/analyze_assets.py` или GDScript-скрипт),
вычисляющий used-set = static-референсы (`.gd`/`.tscn`) ∪ data-driven. Асет
неиспользуемый, если ни один used-путь не резolves в его `res://`. `.import` игнорируется.
Категоризация: cursors / textures / ui / raw / audio / other.

### D2: Enum для пронумерованных асетов
`game/scripts/data/CursorSprite.gd` (`class_name CursorSprite`): enum с семантическими
значениями (BOOT/HAND/WARRIORS) для определённых курсоров и числовыми (CURSOR_NN) для
остальных. Резолвер `path(id: int) -> String` → `res://assets/cursors/cursor_%02d.png`
(формат `%02d`; для семантических значений — конкретный номер файла через lookup-таблицу).
Числовой fallback, если нет семантического названия.

### D3: Типизированное обращение
Код обращается к курсорам через `CursorSprite` + `path()`, а не через строки
`cursor_05.png`. Это даёт типизацию и единое место именования.

### D4: Интеграция с `context-cursor`
Enum `CursorSprite` — база для `CursorController` (autoload из `context-cursor`): обращения
к текстурам курсора в `CursorController` резолвятся через `CursorSprite.path(...)` вместо
строок `cursor_NN.png`. Семантические значения (BOOT/HAND/WARRIORS) и их привязка к
конкретным файлам определяются в `context-cursor` (идентификация курсоров).

## Risks

- **Дубликат с `archive-unused-assets`**: детектор неиспользуемых асетов уже описан там.
  Митигация: D1 — переиспользовать концепцию (референс на `archive-unused-assets`);
  фокус этого цикла — enum, а не архивирование.
- **Семантика значений enum**: без `context-cursor` неизвестно, какой курсор =
  boot/hand/воины. Митигация: enum включает семантические (BOOT/HAND/WARRIORS) + числовые
  (CURSOR_NN); семантические значения и их привязка к файлам — через `context-cursor`.
- **Зависимость от `context-cursor`**: резолвер семантических значений (BOOT/HAND/WARRIORS
  → конкретный файл) определяется в `context-cursor`. Митигация: D4 — резолвер с числовым
  fallback в этом цикле; семантивные привязки — в `context-cursor`.
- **32 значения enum** — много. Митигация: допустимо (курсоры конечны); при росте —
  вынести в data-таблицу.

## Migration

1. D1: анализатор референсов (поиск).
2. D2: `CursorSprite` enum + резолвер пути.
3. D3: типизированное обращение.
4. `run_operability.sh` (CLEAN) + автотесты enum/резолвера.

## Resolved Decisions

1. **Значения enum**: семантические (BOOT/HAND/WARRIORS) для определённых + числовые
   (CURSOR_NN) для остальных. ✓
2. **Охват поиска**: все неиспользуемые асеты (cursors / textures / ui / raw / audio / other).
   ✓
3. **Формат резолвера**: `%02d` (cursor_01); числовой fallback, если нет семантического
   названия. ✓
4. **Интеграция с `context-cursor`**: enum `CursorSprite` — база для `CursorController`
   (заменить строки текстур на enum). ✓

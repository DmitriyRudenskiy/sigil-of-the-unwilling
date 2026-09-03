# unused-asset-enum Specification

## Purpose

Определяет поиск всех неиспользуемых асетов и enum для пронумерованных асетов (курсоры)
с резолвером пути.

## ADDED Requirements

### Requirement: Поиск всех неиспользуемых асетов
Анализатор референсов SHALL вычислять множество «используемых» путей асетов как union
статических референсов (`.gd`/`.tscn`) и data-driven ссылок, и считать асет
неиспользуемым, если ни один используемый путь не резolves в его `res://`-путь.

#### Scenario: Курсоры признаны неиспользуемыми
- **WHEN** анализатор проверяет `res://assets/cursors/cursor_01.png … cursor_32.png`
- **THEN** все 32 асета помечены как неиспользуемые (категория `cursors`)

#### Scenario: Поиск охватывает все категории
- **WHEN** анализатор классифицирует неиспользуемые асеты
- **THEN** категории: cursors / textures / ui / raw / audio / other

#### Scenario: `.import` не учитывается
- **WHEN** анализатор классифицирует асет
- **THEN** `.import`-файлы игнорируются (провождают源-асет)

### Requirement: Enum с семантическими значениями
Система SHALL иметь enum (`CursorSprite`) для асетов, идентифицируемых порядковым номером
(курсоры): для определённых асетов — семантические значения (BOOT/HAND/WARRIORS), для
остальных — числовые (CURSOR_NN).

#### Scenario: Enum определяет курсоры
- **WHEN** обращаются к enum курсоров
- **THEN** enum включает семантические (BOOT/HAND/WARRIORS) и числовые (CURSOR_NN) значения

#### Scenario: Значение enum именовано
- **WHEN** используется значение enum
- **THEN** оно читаемо (семантическое или числовое, но не сырой номер файла)

### Requirement: Резолвер пути
Система SHALL резолвить значение enum в `res://`-путь к файлу асета. Формат — `%02d`
(`cursor_01.png`); для семантических значений — конкретный номер файла.

#### Scenario: Резолвер курсора
- **WHEN** резолвится значение enum курсора
- **THEN** путь вида `res://assets/cursors/cursor_%02d.png`

### Requirement: Интеграция с `context-cursor`
Enum `CursorSprite` SHALL быть базой для `CursorController`: обращения к текстамам
курсора в `CursorController` используют `CursorSprite`, а не строки `cursor_NN.png`.

#### Scenario: CursorController использует enum
- **WHEN** `CursorController` устанавливает текстуру курсора
- **THEN** путь резолвится через `CursorSprite.path(...)`

### Requirement: Отсутствие регрессии
После реализации `game/tools/shell/run_operability.sh` SHALL завершаться с вердиктом
CLEAN.

#### Scenario: Проверка после реализации
- **WHEN** проверка после реализации
- **THEN** `run_operability.sh` → CLEAN

# Аудит динамического UI

Обзор всех панелей в `game/scripts/ui/` с классификацией по типу верстки,
оценкой сложности перевода на `.tscn`-сцену и приоритетом. Основа для цикла
`ui-scenes` (перевод UI на сцены с общей темой — стилизация без кода).

Клификация верстки:

- **статический скелет** — фиксированное число узлов с фиксированными
  `offset`/размерами; содержимое не меняется (окна, рамки). → **полный перевод
  в сцену**.
- **динамический список** — контейнер с плейсхолдерами; состав узлов
  пересобирается в `_refresh()`/`setup()` из данных. → **сцена-контейнер +
  наполнение в коде**.
- **гибрид** — часть узлов статична, часть динамична. → **скелет в сцене,
  данные в коде** (D1 из `openspec/changes/ui-scenes/design.md`).

---

## Классификация панелей

| # | Класс (скрипт) | Базовый тип | Тип верстки | Приоритет | Сложность | Динамическое содержимое |
|---|----------------|-------------|-------------|-----------|-----------|-------------------------|
| 1 | `ArtifactInventoryScreen` | `Control` | гибрид | **высокий** | высокая (64 `add_child`) | статы, портрет, рюкзак, слоты куклы, навыки |
| 2 | `BattleSpellbookPanel` | `Control` | динам. список | **высокий** | низкая | кнопки заклинаний из `HeroMagic`/`SpellRegistry` |
| 3 | `BattleUI` | `CanvasLayer` | гибрид | **высокий** | средняя | инициатива (VBox), кнопки действий, вложенная книга |
| 4 | `InfoPanel` | `VBoxContainer` | гибрид | **высокий** | средняя | слоты героев/городов, статус; кнопка-сетка фикс. |
| 5 | `ArtifactChestDialog` | `Control` | гибрид | **высокий** | низкая | лейблы артефакта/золота; кнопки фикс. |
| 6 | `CityPanel` | `Control` | гибрид | средний | средняя | `ItemList` населения/зданий; кнопки фикс. |
| 7 | `SettingsScreen` | `Control` | гибрид | средний | средняя | слайдеры/селекторы; каркас VBox фикс. |
| 8 | `AdventureUI` | `CanvasLayer` | скелет-координатор | средний | низкая | собирает под-панели в правую колонку |
| 9 | `ResourcesPanel` | `PanelContainer` | гибрид | средний | низкая | лейблы ресурсов (ID → Label) |
| 10 | `ArmyPanel` | `PanelContainer` | гибрид | средний | низкая | иконка+число 8 слотов (GridContainer) |
| 11 | `SkillsPanel` | `PanelContainer` | гибрид | средний | низкая | лейблы уровней навыков |
| 12 | `ToolsPanel` | `PanelContainer` | гибрид | средний | низкая | лейблы слотов инструментов |
| 13 | `ResourceBar` | `HBoxContainer` | динам. список | низкий | низкая | лейблы ресурсов (остаточный принцип) |
| 14 | `MinimapPanel` | `VBoxContainer` | динам. список + `_draw` | низкий | средняя | мини-карта (`Image` в рантайме), NSWE-кнопки |
| 15 | `MarkerLayer` | `Node2D` | `_draw`-графика | низкий | средняя | точки достижимости (`_draw`), не скелет |

Не панели (из обзора): `WorldUIManager` — менеджер инстансирования (`.new()` →
`.instantiate()`); `UIAnimator` — утилита анимаций кнопок/окон; `components/
ItemSlotUI` — компонент слота; `MainMenu.gd` — своё окно (уже в `MainMenu.tscn`,
частично переведено).

> **Приоритеты цикла `ui-scenes`:** сначала 1–5 (высокий) → инвентарь, книга,
> `BattleUI`, `InfoPanel`, `ArtifactChestDialog`; затем 6–13 (средний);
> 14–15 и `ResourceBar` — по остаточному принципу (D4).

---

## Палитра и стили (для общей темы)

Цвета переносятся в `game/assets/theme/game_theme.tres` без изменения вида
(D3). Первоисточник — константы `ArtifactInventoryScreen` (+ доп. цвета других
панелей).

### Основа (`ArtifactInventoryScreen`)

| Константа | HEX | Назначение |
|-----------|-----|------------|
| `WIN_BG` | `#4a3423` | фон окна/корня |
| `WIN_BORDER` | `#16100a` | внешняя обводка окна |
| `OUTLINE` | `#8a6a3a` | обводка/тень окна (±4px) |
| `PANEL_BG` | `#41301f` | фон под-панелей (Left/Right) |
| `PANEL_BORDER` | `#241608` | обводка под-панелей |
| `GOLD_INSET` | `#6b4e2e` | цвет тени inset |
| `RED_BG` | `#7a100c` | фон красных полос (Side/Bottom) |
| `RED_BORDER` | `#3a0806` | обводка красных полос |
| `SLOT_BG` | `#3a2415` | фон слотов |
| `SLOT_BORDER` | `#201006` | обводка слотов |
| `SLOT_INSET` | `#1a0e04` | цвет тени слотов |
| `STATVAL_BG` | `#3a281a` | фон строк значений статов |
| `TEXT_GOLD` | `#e6cf9a` | цвет золотого текста |
| `TEXT_LIGHT` | `#f0dcae` | цвет светлого текста |

### Доп. (`InfoPanel` / `ArmyPanel` / `CityPanel` / `AdventureUI` / `ResourceBar`)

| Цвет | RGB | HEX-оценка |
|------|-----|-----------|
| `C_TEXT` | `(0.95,0.89,0.72)` | `#f2e3b8` |
| `C_GOLD` | `(1.0,0.85,0.4)` | `#ffd666` |
| `C_SLOT_BG` | `(0.35,0.24,0.15)` | `#593d26` |
| `C_BORDER` | `(0.62,0.47,0.22)` | `#9e7838` |
| `C_BG` | `(0.16,0.11,0.06,0.95)` | `#291d10-f2` |

### Профиль `StyleBoxFlat` (из `_stylebox(border, radius, center, bg, inset)`)

- **panel**: border 2, radius 4, center on, inset-shadow 10 (окно) / 8 (под-панели).
- **slot**: border 1–2, radius 4–8, center on, inset-shadow 6.
- **red band**: border 1, radius 0, center on (`RED_BG`), без тени.
- **outline**: border 2, radius 6, center off (прозрачный), inset-shadow 12.

Размеры кнопок: действия инвентаря 58×46; кнопки боя 56×48 (текст 22);
кнопки `InfoPanel` 52×42; навигационные 24×18; NSWE 36×24.

---

## Ключевые размеры и позиции (инвентарь, «по макету», D5)

Root — `CenterContainer` (центрирует 942×706, мир виден сквозь прозрачность).

| Узел | Размер | Позиция (origin окна) |
|------|--------|-----------------------|
| Center | — | full rect (центрирует) |
| Window | 942×706 | (0, 0) |
| Outline | 946×710 | (−4, −4), mouse_filter=IGNORE |
| Left | 406×588 | (8, 8) |
| Right | 427×588 | (420, 8) |
| Side | 79×588 | (855, 8) |
| Bottom | 926×96 | (8, 602) |

Внутри Left: портрет 80×80 (11,11); статы — 4 иконки 46×46 по x (шаг 101, y=95);
названия (y=143); значения (y=168); строки мана/опыт/школа (y=191…); навыки 2×3,
слоты 120×70 (шаг 190/82, y=338…).

Внутри Right: figure 240×360 (97,3); 16 слотов куклы 56×56 по `_DOLL_SLOTS`;
рюкзак 427×68 (1,453) со стрелками ◀(6,9)▶(375,9) и 6 слотами 56×56 (шаг 61, x=49);
кнопки действий (6,531)/(184,531)/(362,531) 58×46.

Side: banner 62×62 (9,9); mini 62×46 (9,79); 6 слотов 62×42 (9,132+i·50); Ok 62×46 (9,542).

Bottom: 7 слотов армии 76×76 (шаг 82, x=10, y=10); formations 133×73 (783,11),
кнопки 2×2 60×32.

Позиционирование — абсолютное через `_set_offsets()` (`custom_minimum_size` +
`offset_*`). В этом цикле геометрия сохраняется 1 в 1 (D5).

---

## Точки инстансирования (для миграции `.new()` → `.instantiate()`, D2)

- `WorldUIManager` → `ArtifactInventoryScreen.new()`, `ArtifactChestDialog.new()`,
  `AdventureUI.new()`.
- `BattleUI` → `_SpellbookPanel.new()`, `_SettingsScreen.new()`.
- `AdventureUI` → `_SettingsScreen.new()` (в popup настроек).
- `MainMenu.gd` → `_SettingsScreen.new()`.

Сигналы/публичные методы, которые нужно сохранить: `ArtifactInventoryScreen.closed`
+ `set_hero()`; `BattleSpellbookPanel.spell_chosen` + `setup()`; `BattleUI.*`
(retreat/wait/attack/skip/defend/spellbook/settings + `open_spellbook`/`open_settings`);
`InfoPanel.end_turn_pressed/options_requested`; `ArtifactChestDialog.choice_made` +
`open()`; `CityPanel.closed/building_upgrade_requested`; `MinimapPanel.minimap_clicked/
camera_jump_requested`.

---

## Стилизация (единый источник)

После создания `game/assets/theme/game_theme.tres` все сцены тянут стили из темы
(`add_theme_stylebox_override("panel", theme.get_stylebox("panel","Panel"))` и т. п.)
или из инспектора сцены — без правки `.gd` (требование «Стилизация через общую
тему»). `_stylebox()` в коде больше не харкодит `StyleBoxFlat`: только чтение из
темы. Правка цвета/радиуса/отступа делается в теме или инспекторе — без кода.

# Tasks: docs-code-sync

Базлайн зафиксирован прогоном `python3 scripts/audit_docs_vs_code.py` на `main`
`1b0db8e9` (2026-10-26): автозагрузки 5/15 не названы, действия ввода 5/5, сцены
20/51, классы 246/405, битых ссылок дока — 3 (все — путь к вендорному
`GdUnitCmdTool.gd`, ложное срабатывание, правится исключением вендора).

## 1. Аудит (шаг 1)

- [x] 1.1 `scripts/audit_docs_vs_code.py`: собрать факты кода (`project.godot`
  `[autoload]`/`[input]`, `game/scenes/**/*.tscn`, `class_name` вне `game/addons/`,
  ключи `mvp_save_schema.gd`) и прогнать сверку в обе стороны. **Сделано в срезе
  аудита**, числа — в proposal.
- [x] 1.2 Исключения: `game/addons/**` (вендор), `docs/bank/**` и архивные логи
  (`STRUCTURE_AUDIT`, `CONFLICTS_REPORT`, `UNIFICATION_CHANGES`,
  `NORMALIZATION_REPORT`) — не сверяются, их текст каноничен как исторический акт.
- [x] 1.3 Таблица аудита с приоритетами: разделы, где расхождение ломает
  приёмку (управление, сейв, автозагрузки, слой событий), — P0; инвентарь
  классов — P2 (ratchet).
- [x] 1.4 Битые ссылки дока (3) обнулить: различать «имя класса» и «путь к
  вендорскому скрипту».

## 2. Карта систем (шаг 2)

- [x] 2.1 `docs/18-system-map.md`: 15 автозагрузок (`Settings`, `SoundManager`,
  `GameEventBus`, `Spellbook`, `PauseController`, `CursorController`,
  `TemplateBootstrap`, `Units`, `Artifacts`, `Spells`, `Resources`, `Services`,
  `TileAtlasCache`, `HexGrid`, `McpInteractionServer`) — ответственность + файл.
- [x] 2.2 Слои `game/scripts/` (core / systems / campaign / city / world / ui /
  probe / battle / entities / data / autoload) и границы: кто кого дёргает.
- [x] 2.3 Каналы сигналов: `GameEventBus`, `GameManager.on_day_passed` →
  `CrisisEventSystem`, `UIManager.decision_made` →
  `CrisisEventSystem.resolve_event_choice` (D-202), `battle_controller` ↔
  `BattleUI`.
- [x] 2.4 Пайплайн сцен: корневые сцены, кто их поднимает, какие генерируются
  кодом (`scripts/build/gen_inventory_scene.gd` — носитель
  `artifact_inventory_screen.tscn`, T-219).
- [x] 2.5 Сейв-пайплайн: `mvp_save_schema.gd` / `mvp_save_manager.gd` /
  `world_state_serializer.gd` / `city_serializer.gd` — кто пишет какой ключ.
- [x] 2.6 Ссылки остального инвентаря на карту; удалить дубли перечней из
  правимых заметок.

## 3. Реверс-документация (шаг 3)

- [x] 3.1 **Управление**: секция по `[input]` — `camera_up`, `camera_down`,
  `camera_left`, `camera_right`, `mute` (привязки из `project.godot`, экран,
  обработчик). Сейчас в доках нет ни одного имени действия (5/5).
- [x] 3.2 **Автозагрузки**: описать 5 отсутствующих (`SoundManager`, `Spellbook`,
  `TemplateBootstrap`, `Units`, `Spells`), остальные — сверить с кодом.
- [x] 3.3 **Сцены**: 20 не названных сцен (`battle_view.tscn`, `enemy_entity.tscn`,
  `hero_figure.tscn`, `dest_marker.tscn`, `status_orb.tscn`, `game_over_screen.tscn`
  и др.) — в карту/соответствующие UX-заметки.
- [x] 3.4 **Формат сейва**: перечислить фактические ключи схемы (`campaign`,
  `city`, `major`, `map`, `minor`, `party`, `population`, `prestige`, `resources`,
  `sign`), убрать из доков описания ключей, которых схема не пишет.
- [x] 3.5 **Слой событий**: зафиксировать работающий носитель панели (fallback
  `UIManager._create_simple_decision_panel`), а не отсутствующие
  `decision_panel.tscn` / `crisis_panel.tscn` (T-132); закрытый набор ключей
  эффектов — по `WIRED_EFFECT_KEYS` (D-197/D-200).
- [x] 3.6 **Боевой слой**: вписывание поля по размеру окна и ×0.8 при высоте
  окна ≤720 (`scripts/systems/battle_view.gd`, D-266) — в UX-заметку про бой;
  карточка врага «видна всегда» + Удача при наличии носителя (D-267, D-268).
- [x] 3.7 Каждая восстановленная секция — с указанием источника (файл и символ).
- [x] 3.8 Поведение, описанное в доках и отсутствующее в коде, — пометить и
  завести тикет (код под док не правится).

## 4. Сверка (шаг 4)

- [x] 4.1 `python3 scripts/audit_docs_vs_code.py` — пусто по автозагрузкам,
  действиям ввода, сценам, ключам сейва.
- [x] 4.2 Ratchet: `scripts/audit_docs_vs_code.allowlist` — бэклог классов,
  сокращённый относительно базлайна 246; проверка, что задокументированное имя
  из allowlist удалено.
- [x] 4.3 Имена классов/нод/сцен/хоткеев в тексте — побуквенно против кода
  (регистр, подчёркивания, `.tscn`/`.gd`).
- [x] 4.4 `python3 scripts/check_docs_links.py` — зелёный (связность графа).

## 5. Фиксация (шаг 5)

- [x] 5.1 `docs/CHANGELOG.md`: запись с числами аудита до/после и списком
  переписанных секций (почему).
- [x] 5.2 `docs/DECISIONS.md`: решение по ratchet-гейту и по «док не тянет код».
- [x] 5.3 `docs/mvp/TICKETS.md`: тикеты на вскрытые расхождения (панели событий,
  прочее из 3.8).

## 6. Приёмка (шаг 6)

- [x] 6.1 Каждый описанный класс/сцена/автолоад существует в коде под тем же
  именем — подтверждается гейтом, не чтением.
- [x] 6.2 Описаний удалённых и переименованных систем не осталось (в т.ч.
  проверенные вручную: панели решений, «мораль» как шкала (K-M14), снятые ключи
  эффектов (D-197/D-200)).
- [x] 6.3 Управление в доках = input map из `project.godot` (5/5 имён, привязки).
- [x] 6.4 Формат сейва описан по фактической схеме, лишних ключей нет.
- [x] 6.5 Все изменения отражены в CHANGELOG; `check_docs_links.py` зелёный.
- [x] 6.6 Ревью диффа владельцем в треде (D-224): «мерджи» от владельца 2026-10-26 —
  срез принят и опубликован (`main 4c947b5c`, fast-forward; игровой код в срезе не менялся).

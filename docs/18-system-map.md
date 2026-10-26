---
title: Карта систем
tags:
  - reference
  - architecture
status: reference
date: 2026-10-26
---

# Карта систем

Инвентарь собран **из кода**, а не из памяти: `game/project.godot`
(`[autoload]`, `[input]`, `run/main_scene`), `game/scripts/**`, `game/scenes/**`,
`scripts/campaign/save/mvp_save_schema.gd`. Это канон перечней: остальные заметки
ссылаются на эту страницу ([[18-system-map]]), а не пересказывают её — повторение
одного перечня в трёх местах даёт три места расхождения.

Сверяется машиной: `python3 scripts/audit_docs_vs_code.py` (exit ≠ 0, если
автозагрузка, действие ввода, сцена или ключ сейва не названы в `docs/`, или если
док ссылается на несуществующий файл).

## 1. Автозагрузки (`project.godot [autoload]`, 15)

| Автозагрузка | Файл | Ответственность |
| --- | --- | --- |
| `McpInteractionServer` | `tools/mcp/mcp_interaction_server.gd` | отладочный сервер взаимодействия для MCP e2e (4-й уровень верификации); инжектится вендорным аддоном, в релизной сборке не нужен |
| `Settings` | `scripts/autoload/settings.gd` | настройки: режим окна (`apply_display_mode`), зум карты (`get_zoom`, `step_zoom`), флаг взрослого контента |
| `SoundManager` | `scripts/autoload/sound_manager.gd` | `play_sfx` / `play_music` и cue-варианты (`play_sfx_cue`, `play_music_cue`) по `AudioCues`; слушает действие `mute` (см. §7) |
| `GameEventBus` | `scripts/autoload/game_event_bus.gd` | событийная шина игры, 38 сигналов (см. §4) |
| `Spellbook` | `scripts/autoload/spellbook_registry.gd` | реестр книг заклинаний: `ensure_definitions`, загрузка из JSON с `_load_fallback` |
| `PauseController` | `scripts/autoload/pause_controller.gd` | пауза со **счётом ссылок**: несколько систем могут независимо просить паузу, игра разматывается, когда отпущен последний владелец; снимается при смене сцены |
| `CursorController` | `scripts/autoload/cursor_controller.gd` | курсор: меняет форму по контексту, подписывается на `GameEventBus.hero_moving_changed` |
| `TemplateBootstrap` | `scripts/autoload/template_bootstrap.gd` | инициализация шаблонов/контента на старте (24 строки, только `_ready`) |
| `Units` | `scripts/autoload/unit_registry.gd` | реестр юнитов: `get_definition(key) → UnitStats`, `make_stack(key, rng, size_mult)` |
| `Artifacts` | `scripts/autoload/artifact_registry.gd` | реестр артефактов: `get_by_id`, `_register`, моды эффектов (в т.ч. `luck`, D-268) |
| `Spells` | `scripts/autoload/spell_registry.gd` | реестр заклинаний: `_reg(id, name, school, lvl, mana, target…)`, `get_spell` |
| `Resources` | `scripts/autoload/resource_registry.gd` | реестр ресурсов: городские (`_add_city` с ёмкостью), иконки (`get_icon`) |
| `Services` | `scripts/autoload/services.gd` | DI-реестр (см. §2): `resolve(key)`, `register_singleton(key, service)`, `clear_session()` |
| `TileAtlasCache` | `scripts/autoload/tile_atlas_cache.gd` | кэш `TileSet` гекс-тайлов (`build_hex_tileset`) — сборка атласа один раз за сессию |
| `HexGrid` | `scripts/autoload/hex_grid.gd` | калибровка координатной сетки по `TileMapLayer` (`calibrate(tm)`, 12 строк) |

## 2. Services — DI-реестр

`scripts/autoload/services.gd` регистрирует ключи: `event_bus`, `settings`,
`units`, `artifacts`, `spells`, `resources`, `persistence`, `service_registry`.
Смысл слоя: системы получают зависимости через `Services.resolve(&"persistence")`,
а не держат друг друга напрямую; `clear_session()` вызывается при выходе из
сессии, чтобы синглтоны не течли между кампаниями. Потребители записи о
сейв-сервисе: `scripts/ui/save_load_screen.gd`, `scripts/world/world_bootstrap.gd`,
`scripts/world/world_persistence.gd`.

## 3. Слои `game/scripts/`

Количество `.gd` на 2026-10-26 (мера, не оценка): `data` 66, `ui` 51, `world` 50,
`systems` 36, `city` 34, `entities` 34, `core` 25, `battle` 27, `campaign` 19,
`autoload` 17, `probe` 9, `build` 8, `constants` 8, `settlement` 6,
`demographics` 6, `balance` 5, `economy` 4, `managers` 2, `theme` 2, `utils` 1.

- **`core/`** — правила без состояния (`battle_rules.gd`, `hex_utils.gd`,
  `save_data.gd`): арифметика боёв по лестнице (D-222), геометрия гексов.
- **`systems/`** — оркестрация боя и мира: `battle_state.gd` (+ вложенный класс
  `BattleUnit`), `battle_state_builder.gd`, `battle_controller.gd`,
  `battle_view.gd`, `crisis_event_system.gd`.
- **`campaign/`** — кампанийный ход: `turn_driver.gd`, `region_map.gd`,
  `party_system.gd`, `population_system.gd`, `threat_system.gd`,
  `chronicle_log.gd`, `sign_system.gd`, `save/`.
- **`city/`** — город: строительство, районы, обучение, экономика хода.
- **`world/`** — карта: `map_generator.gd`, `map_renderer.gd`, `map_roads.gd`,
  `map_threat.gd`, `world_camera.gd`, `world_persistence.gd`.
- **`ui/`** — экраны и панели; **`ui_kit/`** пуст (0 `.gd`) — общие виджеты живут in
  `ui/` (FormRow/FormStack) и в теме.
- **`probe/`** — балансовые роли-разведчики (`CollectorRole.gd`, `SurvivalRole.gd`,
  `ScenarioPilot.gd`), не игровой контент.
- **`build/`** — генераторы ассетов и сцен; сгенерированные сцены обязаны правиться
  здесь же (T-219: `gen_inventory_scene.gd` — носитель
  `artifact_inventory_screen.tscn`).

## 4. Событийная шина `GameEventBus`

38 сигналов (все — `scripts/autoload/game_event_bus.gd`), по группам:

- **бой**: `battle_started`, `battle_completed(winner, enemy_cell)`,
  `battle_won(enemy_cell)`, `battle_lost(enemy_cell)`;
- **ход и мир**: `turn_ended(turn, month)`, `hero_moving_changed(moving)`,
  `hero_died(cause)`, `hero_successor(hero)`, `weather_changed(new_weather)`,
  `game_ended(result, reason, summary)`;
- **ресурсы и производство**: `resource_discovered`, `resource_extracted`,
  `resource_exhausted`, `resource_depleted`, `production_completed`,
  `upkeep_failed`, `trade_completed`;
- **город и здания**: `building_constructed`, `scale_shift`, `zone_violation`,
  `city_level_up`, `city_event_occurred`, `relocation_completed`;
- **демография и отношения**: `character_born`, `character_died`,
  `character_need_critical`, `disease_outbreak`, `migration_occurred`,
  `relationship_stage_changed`, `romance_event`, `follower_betrayal`, `marriage`;
- **прогресс и кризисы**: `glory_earned`, `reputation_changed`, `raid_occurred`,
  `faith_milestone`, `chronicle_entry_added`, `village_captured`.

Кампанийный путь выбора события (D-202): `UIManager.decision_made` →
`GameManager._on_decision_made` → `CrisisEventSystem.resolve_event_choice`.
Ход дня: `main.gd._advance_day()` → `GameManager.on_day_passed()` →
`crisis_event_system.gd` (триггеры событий и кризисов).

**Работающий носитель панели события** — fallback
`UIManager._create_simple_decision_panel` / `_create_simple_crisis_panel`;
сцен `assets/ui/panels/decision_panel.tscn` и `crisis_panel.tscn` в репо нет
(Q-M83/T-132), класс `scripts/ui/decision_panel.gd` никем не instantiated.

## 5. Пайплайн сцен

- Корневая сцена: `run/main_scene = res://scenes/main_menu.tscn`.
- Переходы меню (`scripts/ui/main_menu.gd`): «Продолжить» → `SCENE_CONTINUE`,
  «Новая игра» → `character_creation.tscn`, отдельная точка входа в арену —
  `res://scenes/city_arena.tscn`.
- Корневые сцены: `main_menu.tscn`, `main/main.tscn` (кампания/мир),
  `battle.tscn` (бой), `city_arena.tscn`, `battle_view.tscn` (поле боя),
  `world/map_generator.tscn` (генерация карты), `probe/balance_probe.tscn` и
  `probe/ScenarioPilot.tscn` (балансовые прогоны).
- **Все 51 сцена репо к чему-то подвешены** (замер 2026-10-26: сцен, не
  загружаемых и не инстансируемых ни из одного `.gd`/`.tscn`, — 0). «Мёртвых»
  сцен в списке нет; расхождение доков с кодом — это пробел в описаниях, а не
  мусор в игре.
- Панели боя и HUD (`ui/battle_ui.tscn`, `ui/battle_spellbook_panel.tscn`,
  `ui/damage_number.tscn`, `ui/status_orb.tscn`, `ui/retaliation_arrow.tscn`)
  поднимаются сценой боя; юнит-сущности — `entities/*.tscn`
  (`enemy_entity.tscn`, `hero_visuals.tscn`, `resource_node.tscn`,
  `dest_marker.tscn` и др.).
- Кто поднимает отдельные сцены (замер по вызовам `load`/`instantiate`):
  `world_spawner.gd` — объекты карты `entities/village_entity.tscn`,
  `entities/chest_entity.tscn`, `entities/scroll_entity.tscn`,
  `entities/resource_entity.tscn`; `battle_view.gd` — бой: `entities/hero_figure.tscn`,
  `ui/floating_text.tscn`, `ui/obstacle_label.tscn`; `endgame_controller.gd` —
  `ui/game_over_screen.tscn`; `ui/resource_collect_popup.tscn` инстансируется
  сценой `ui/adventure_ui.tscn`.
- Сгенерированная сцена: `ui/artifact_inventory_screen.tscn` из
  `scripts/build/gen_inventory_scene.gd` — правка сцены без правки генератора
  расходится (T-219).

## 6. Сейв-пайплайн

- **Носитель**: `scripts/campaign/save/mvp_save_manager.gd` (`class_name
  MvpSaveManager`), путь `user://mvp_save_slot_%d.json`
  (`PATH_TEMPLATE`), `SLOT_COUNT = 3`, кампанийный слот — `CAMPAIGN_SLOT = 1`.
- **Конверт**: `{"version": {"major", "minor"}, "state": {...}}`
  (`MvpSaveSchema.current_version()`, `CURRENT_MAJOR = 1`, `CURRENT_MINOR = 0`).
- **Секции `state`** (`MvpSaveSchema.SECTIONS`, тип проверяется при загрузке):

| Ключ | Тип | Что внутри (комментарий схемы) |
| --- | --- | --- |
| `campaign` | Dictionary | `{turn, seed, phase}` |
| `resources` | Dictionary | `{food, wood, iron, …}` |
| `population` | Dictionary | `{count, housing}` |
| `party` | Array | `[{id, class, race, level, xp, stats{}, luck}]` |
| `city` | Dictionary | здания, районы, гексы (T-030) |
| `map` | Dictionary | регион, туман, узлы |
| `prestige` | Dictionary | `{ledger: [{turn, source, amount}]}` — **только ledger** |
| `sign` | Dictionary | состояние Знака (R1) |

- **Запрещённые ключи** (`MvpSaveSchema.DERIVED_KEYS` — производные, в сейве быть
  не может): `ladder`, `prestige_balance`, `effective_stats`, `morale`.
  Пункт `morale` — то же основание, что и у снятия шкалы «морали» (K-M14):
  производное состояние не хранится, а пересчитывается.
- **Проверка**: `MvpSaveSchema` валидирует наличие секций, их типы и отсутствие
  производных ключей; тесты — `tests/campaign/test_mvp_save.gd`,
  `tests/campaign/test_campaign_victory.gd`, `tests/campaign/test_turn_driver.gd`.
- **Хроника** (`chronicle_log.gd`) — отдельный писатель, секции `chronicle` в
  схеме нет; описание хроники в [[08-tech]] обязано это отражать.

## 7. Ввод (из `project.godot [input]`)

В игре **пять** именованных действий. Всё остальное — прямые клавиши UI-сцен
(Tab/Esc/H и т. п.), они в `InputMap` не объявлены и описаны в
[[07-ui-ux#Управление (по input map)]].

| Действие | Привязки | Обработчик |
| --- | --- | --- |
| `camera_up` | `W`, `↑` | `scripts/world/world_camera.gd` (`Input.is_action_pressed`) |
| `camera_down` | `S`, `↓` | `scripts/world/world_camera.gd` |
| `camera_left` | `A`, `←` | `scripts/world/world_camera.gd` |
| `camera_right` | `D`, `→` | `scripts/world/world_camera.gd` |
| `mute` | `M` | `scripts/autoload/sound_manager.gd` (`_unhandled_input` → `is_action_pressed(&"mute")`) |

## 8. Как сверять

```bash
python3 scripts/audit_docs_vs_code.py          # текст; exit 1 — есть расхождение
python3 scripts/audit_docs_vs_code.py --json   # машиночитаемо
python3 scripts/check_docs_links.py            # связность wikilink-графа
```

# Tasks: post-review-fixes

All 25 audit items (numbered per the audit summary table). Phase order:
High → Medium → Low → Architecture → Verification (see design.md).

## 1. High-priority bug fixes (audit #1–#4)

- [x] 1.1 [#1] `CityArenaView.gd`: re-signature `_on_cell_input` to `(viewport: Node, event: InputEvent, shape_idx: int, pos: Vector2, normal: Vector2)`; fix the stale Godot-3 comment; extend `tests/test_city_arena_view.gd` with a left-click → selection-changed test
- [x] 1.2 [#2] `SaveManager.gd`: `delete_save()` → `DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))` (применено также к `_write`/`_read`); extend `tests/test_save_roundtrip.gd`: save exists → delete → file gone on disk, delete-when-missing returns false
- [x] 1.3 [#3] `City.gd`: `can_build_building` rejects a cell occupied by a `WORKER` pop unit (изменение было в дереве); GUT-кейс добавлен в `tests/test_city_events_relocation.gd` (build fails, worker unaffected)
- [x] 1.4 [#4] `SettingsScreen.gd`: snapshot volumes in `_ready`; `_on_cancel` restores via `Settings` setters + `_apply_audio`, no save; тест в `tests/test_settings_persist.gd`
- [x] 1.5 Full GUT run green after Phase 1 (1155/1155)
  - Побочные правки: `_first_free_r1` в `test_city_arena_view.gd` пропускает клетки с рабочими (следствие #3); сид RNG в `test_unit_abilities.gd::test_first_strike` (флейка: первый удар мог вырезать всю атакующую группу → пустой результат → флаг теряется)

## 2. Medium priority (audit #5–#11)

- [x] 2.1 [#5] Split `mcp_interaction_server.gd` into per-command-group `RefCounted` modules (network/input, game-state, physics/animation, UI, 3D/2D, audio, resources); server keeps transport + `_handle_command` delegation; no protocol change; unit tests per module (final phase, separate commit)
- [x] 2.2 [#6] `Settings.gd`: `ZOOM_LEVELS` becomes a const alias of `GameSettings.ZOOM_LEVELS` (single literal); verify `test_zoom_levels` + `test_camera_clamp` pass
- [x] 2.3 [#7] Rename `ENDGAME_GlORY_VICTORY` → `ENDGAME_GLORY_VICTORY` in `GameSettings.gd`, `EndgameController.gd`, `AdventureUI.gd`; compile clean
- [x] 2.4 [#8] Move `TemplateEngine.TemplateHandlers` to one `RefCounted` file per template in `scripts/data/templates/`; `TemplateBootstrap` registers by name; engine dispatches only; test executes every registered template with unchanged output (final phase, separate commit)
- [ ] 2.5 [#9] Extract `MinHeap` → `scripts/core/MinHeap.gd` and pathfinding (`bfs_path`, `dijkstra`, `dijkstra_path`, `bfs_reachable`) → `scripts/core/HexPathfinding.gd`; update all call sites; split `tests/test_hex_utils.gd` to match (final phase, separate commit)
- [x] 2.6 [#10] `EnemyTurnProcessor.process`: cache Dijkstra results per turn keyed by `(cell, budget)`; extend `tests/test_enemy_world_ai.gd` (repeated query computed once / correct paths)
- [x] 2.7 [#11] `BattleState.gd`: include `_board_version` in `_reachable_cache` key; extend a battle test: query → move → query reflects new board
- [x] 2.8 Full GUT run green after Phase 2 (1157/1157; 2.1/2.4/2.5 — архитектура, исполняется в §4)

## 3. Low priority (audit #12–#25)

- [x] 3.1 — прямые `Input.`-вызовы (standalone parse-check noise: autoload-глобалы в `-s`-скрипте; CI compile_all и GUT green)[#12] `CursorController.gd`: replace `Engine.get_singleton("Input")` with direct `Input` calls; drop the `_input` workaround and its comment
- [x] 3.2 — `Button.new()`/`Label.new()` напрямую, `_add_styled` упрощён[#13] `CharacterCreationUI.gd`: delete `_instantiate` match factory; call constructors directly
- [x] 3.3 — guard + `push_warning` + `return null`[#14] `BattleFX.play_attack_sequence`: replace `assert(is_inside_tree())` with a guard + `push_warning`
- [x] 3.4 — `_cached_texture(key, builder)` кэш на спавнере (village/chest/scroll — константные изображения)[#15] `WorldSpawner.gd`: replace per-spawn `Image.create` + `fill_rect` sprites with cached textures (cache keyed by sprite spec)
- [ ] 3.5 [#16] (исполняется в 4.4 — архитектура)  Split `GameSettings.gd` into `BattleConfig` / `MapConfig` / `UIConfig` / `EndgameConfig`; `GameSettings` keeps only general constants (`INF`, `SAVE_MAGIC`); update all references
- [x] 3.6 — `is_connected`-гарды + именованные хендлеры вместо лямбд; `test_double_setup_does_not_duplicate_counters`[#17] `EndgameController.setup`: `is_connected` guards on every `connect`; extend `tests/test_endgame.gd` with a double-setup test
- [x] 3.7 — опц. аргументы `map_size`/`occupied_cells` (backwards-compat); `test_relocate_rejects_out_of_bounds_and_other_city`[#18] `City.relocate`: reject new center outside map bounds or on another city's cell; extend `tests/test_city_events_relocation.gd`
- [x] 3.8 — порядок autoload: Settings → SoundManager; lookup `/root/Settings` (голый идентификатор не резолвится на compile-time для autoload-скриптов)[#19] Mute sync: reorder `[autoload]` in `project.godot` (`Settings` before `SoundManager`); remove the `AudioServer` fallback from `SoundManager.toggle_mute`
- [x] 3.9 — `ArenaDemoScenario` (class_name, RefCounted); вызовщик — только `CityArenaModel`[#20] Move `ArenaTurnRunner` `score` / `demo_plan` / `run_demo_plan` → `scripts/city/ArenaDemoScenario.gd` (statics); update callers (`CityArenaModel.gd`, tuner if any)
- [x] 3.10 — early return в headless[#21] `ParticlePresets.spawn_burst`: headless guard (`OS.has_feature("headless")` → return early)
- [x] 3.11 — `_resolve_bus()` + кэш; `test_chronicle_append_without_bus_does_not_crash`[#22] `Chronicle.append`: emit `chronicle_entry_added` only when the event bus is present; extend `tests/test_legend_chronicle.gd` with a no-bus case
- [x] 3.12 — `excluded`-набор (стаки/ресурсы/сундуки) + `_occupied_map_cells`; `test_place_excludes_occupied_cells`; спавнер опционален в partial-bootstrap (guard null)[#23] `WorldBootstrap._place_in_hero_component`: exclude cells occupied by enemy stacks / resources / chests; add a placement test (implement on top of in-flight WorldBootstrap changes)
- [x] 3.13 — `save()` в `toggle_mute`/`reset_to_defaults` + персист `muted` в `_load`/`save`[#24] `Settings.gd`: `save()` in `toggle_mute` and `reset_to_defaults`
- [x] 3.14 — save только на Apply[#25] `SettingsScreen._on_zoom_selected`: remove immediate `save()` (save only on Apply — covered by 1.4 semantics)
- [x] 3.15 — 1161/1161 passing, 0 SCRIPT ERROR, «All tests passed!» (mcp-dir GUT ERROR из gutconfig не влияет на CI: CI гоняет с явным `-gdir=res://tests`)Full GUT run green after Phase 3 (including demographics/hero/worldcontroller suites — in-flight files)

## 4. Architecture (final phase, separate commits)

- [x] 4.1 Commit for #5: mcp server command modules + delegation + per-module unit tests; smoke: server routing unchanged
- [x] 4.2 Commit for #8: templates extraction + registration + all-templates test
- [ ] 4.3 Commit for #9: MinHeap/HexPathfinding extraction + split tests
- [ ] 4.4 Commit for #16: GameSettings domain configs + reference updates

## 5. Verification

- [ ] 5.1 Full GUT suite: 0 failing
- [ ] 5.2 `bash game/tools/shell/run_all_ci_checks.sh --fast` → exit 0
- [ ] 5.3 `bash game/tools/lint.sh` → ALL STATIC CHECKS PASSED
- [ ] 5.4 Acceptance (audit §Критерии): arena clicks handled; `delete_save` removes file; worker-cell build rejected; "Cancel" restores volume — each covered by a test from §1

---
title: Regression suite — критический путь боя
tags: [battle-demo, tests, regression]
status: reference
date: 2026-10-25
---

# Регрессионный набор (`battle-demo`)

Задача 10.5. Два списка: **критический путь** (шаг за шагом, чем закрыт) и
**закрытые отклонения** (чем закреплён, чтобы не вернулось). Имена тестов —
дословные `func test_*` из `battle-demo/tests/`; запускаются все одним гейтом,
`battle-demo/run_tests.sh` (GdUnit4, headless).

Слово «проверено» ниже означает только «есть исполняемый тест». Визуальная
приёмка — отдельная процедура (см. `ui-review-*.md`, `ui-read-judge-*.md`), она
не заменяет тест и тестом не называется.

## 1. Критический путь боя

| # | Шаг игрока или правило | Тест |
| --- | --- | --- |
| 1 | Ядро боя живёт без сцены и без дисплея | `test_battle_runs_without_touching_scene_tree`, `test_combat_layer_has_no_display_references` |
| 2 | Данные юнитов и двух наборов грузятся и проходят валидацию | `test_all_units_load`, `test_real_data_passes_validation`, `test_rosters_are_the_designed_pair`, `test_rosters_differ_symmetrically`, `test_every_pool_unit_plays`, `test_enemy_is_not_in_the_pool` |
| 3 | Плохие данные падают на валидации, а не в бою | 12 тестов `tests/unit/data/test_data_validation.gd` (юнит без способности, чужой юнит в наборе, набор не того размера, дубль, одинаковые наборы и т. д.) |
| 4 | Экран выбора набора: оба описаны, выбор переводится, выбор доходит до потока | `test_both_rosters_are_described_before_choice`, `test_selection_moves_between_cards`, `test_choice_is_written_to_the_flow` |
| 5 | Очередь: инициатива по убыванию, ничья — за игроком, внутри стороны — по слоту, порядок не зависит от порядка входа | `test_order_by_initiative_descending`, `test_tie_gives_player_side_first`, `test_tie_within_side_ordered_by_slot`, `test_order_independent_of_input_order` |
| 6 | Мёртвый очереди не имеет | `test_dead_units_are_skipped` |
| 7 | Одно действие за ход; «Ждать» доступен всегда; цель обязательна | `test_one_action_per_turn`, `test_pass_is_always_available`, `test_ability_without_target_is_unavailable` |
| 8 | Способность: фокус, стоимость, кулдаун, сброс кулдауна | `test_ability_requires_focus`, `test_ability_goes_on_cooldown`, `test_cooldown_expires`, `test_focus_grows_only_after_first_turn`, `test_focus_is_capped`, `test_focus_pips_match_the_active_unit` |
| 9 | Урон: целое, ≥ 1, воспроизводим по сиду, в коридоре разброса, защита уменьшает (и игнорирует часть защиты) | `test_damage_is_integer_and_at_least_one`, `test_damage_reproducible_for_same_seed`, `test_variance_stays_in_band`, `test_defense_reduces_damage`, `test_defense_ignores_part_of_defense` |
| 10 | Статусы: кровотечение по ход, оглушение блокирует действие и проходит, ослабление, регенерация до потолка, обновление вместо стека, неизвестный статус отвергнут | `test_bleed_ticks_damage_on_owner_turn`, `test_stun_blocks_action`, `test_stun_leaves_only_pass_available`, `test_stun_is_gone_next_turn`, `test_status_expires_after_its_duration`, `test_weaken_multiplies_attack`, `test_regen_heals_up_to_cap`, `test_same_status_refreshes_instead_of_stacking`, `test_unknown_status_is_rejected` |
| 11 | Смертельный удар обнуляет HP и помечает мёртвым | `test_lethal_hit_zeroes_hp_and_marks_dead` |
| 12 | Противник ходит сам, без ввода игрока: готовая способность, откат на атаку, выбор слабого, пропуск оглушённым | `test_enemy_acts_without_player_input`, `test_enemy_uses_ready_ability`, `test_enemy_falls_back_to_attack_without_focus`, `test_enemy_targets_weakest_player_unit`, `test_stunned_enemy_passes` |
| 13 | Исход: победа/поражение/пат, очередь после конца останавливается | `test_victory_when_no_enemies_left`, `test_defeat_when_no_player_units_left`, `test_queue_stops_after_battle_ended`, `test_stalemate_guard_reports_no_result` |
| 14 | Экран результата появляется и закрывает ввод боя | `test_result_screen_appears_with_the_outcome`, `test_no_battle_actions_after_the_result` |
| 15 | Один и тот же бой двумя наборами идёт по одним правилам | `test_same_battle_with_two_rosters`, `test_designed_pair_plays_by_the_same_rules` |
| 16 | Тот же сид — тот же бой целиком; другой сид — другие броски | `test_same_seed_reproduces_the_whole_battle`, `test_different_seed_changes_damage_draw`, `test_battle_actually_happened` |
| 17 | Пока игрок выбирает, мир стоит; меняется только по подтверждённому выбору | `test_world_frozen_while_choosing`, `test_world_changes_only_on_confirmed_choice` |
| 18 | Полосы HP синхронны с моделью после каждого действия | `test_bars_match_the_model_after_every_action`, `test_dead_unit_keeps_an_empty_bar` |
| 19 | Анимация: трек по состоянию, зеркало у противника, удар по кадру контакта, смерть стоп-кадром | `test_state_selects_the_track`, `test_enemy_side_is_mirrored`, `test_attack_is_played_once`, `test_hit_starts_on_the_contact_frame_not_before`, `test_action_signal_from_the_core_lands_on_the_contact_frame`, `test_death_stops_on_the_last_frame_and_desaturates`, `test_contact_delay_is_the_contact_frame_over_track_speed` |
| 20 | У каждого юнита четыре дорожки по четыре кадра; кадры в формате | `test_every_unit_has_four_tracks_of_four_frames`, 5 тестов `tests/unit/helpers/test_sprite_asserts.gd` |

## 2. Закрытые отклонения — чем закреплены

Отклонение снимается с руки только тестом, который падает на возврате.

| Отклонение (задача) | Тест-замок |
| --- | --- |
| Полоса HP лежала на корпусе спрайта (10.10) | `test_hp_bar_clears_the_row_above` — зазор считается от `UNIT_SCALE`/`BAR_LIFT`/радиуса сетки, а не с кадра |
| Гибель не читалась; багряная полоса читалась как залитый HP (10.11 → 10.15) | `test_fallen_unit_is_marked_with_a_cross` — у мёртвого ширина заполнения 0, дорожка штатно-серая, крест виден; у живого креста нет |
| Метка активного юнита читалась как чужой HP-бар (10.12) | `test_active_cell_follows_the_queue` — обведённая клетка идёт за очередью, после конца боя снимается |
| «Ждать»/«Меню» ложились на сетку (10.13) | `test_commands_stand_clear_of_the_field` |
| Счётчик раунда и подпись активного юнита на гексах (10.14) | `test_the_top_band_holds_the_counter_and_the_name` |
| Полоса противника не отличалась от своей (10.16) | `test_enemy_bars_are_a_different_colour` |
| Отметка карточки текущего юнита нечем было читать (10.18) | `test_the_current_card_is_outlined_in_gold` |
| Полоса порядка не убирала павших; команды жили после конца боя | `test_dead_units_leave_the_order_strip`, `test_no_commands_once_the_battle_is_over` |
| Клик цели попадал по рамке карточки, а не по спрайту (10.16) | `test_click_on_the_figure_hits_the_figure_not_the_frame` |
| Кадр приёмки был 1920×1027 вместо 1920×1080 (10.17) | `test_the_frame_is_exactly_the_specified_size` |
| Подпись команды шире кнопки — текст лез на рамку (10.19) | `test_commands_stand_clear_of_the_field` (ширина надписи влезает в `BUTTON_SIZE` с полями) |
| Обесцвечивание спрайта запаздывало на кадр от полосы (10.20) | `test_the_fallen_sprite_is_desaturated_at_once` |
| После конца боя у края висела сирота «бой окончен» (10.21) | `test_no_commands_once_the_battle_is_over` (команд 0 и `reason` скрыт) |
| UI получал ход противника | `test_the_ui_never_gets_an_enemy_turn` |
| Панель поверженного командира исчезала | `test_defeated_commander_stays_on_his_panel` |
| Юниты вставали в одну клетку | `test_units_stand_on_distinct_hexes_of_their_own_flank` |
| Полоса порядка расходилась с составом | `test_strip_has_one_card_per_unit` |
| Кулдаун способности не гасил кнопку | `test_ability_button_goes_dark_on_cooldown` |
| Счётчик раунда отставал от очереди | `test_round_counter_follows_the_queue` |

## 3. Что не закрыто (на 2026-10-25)

| Пробел | Чем не является | Что нужно |
| --- | --- | --- |
| Ветка «мало воли» в панели команд (`cost` → кнопка недоступна) | кулдаун-ветка закрыта `test_ability_button_goes_dark_on_cooldown`, `test_ability_requires_focus` закрывает модель | тест на `legal_actions`/панель при `focus < cost` — одна кнопка, тот же механизм, что у кулдауна |
| Раскладка кадров (пересечения, обрезка) | тестом не проверяется: это свойство кадра, а не модели | процедура: `tools/capture_screens.tscn` → `tools/ui_read_judge.py` → вердикт в тред. Геометрия, вынесенная в константы, при этом закреплена тестами из §2 |
| Звук, playtest, «ощущение» | нечем снять на этой машине | отложено владельцем (D-185): кадр — да, звук — нет |

## 5. Леджер тестов (было → стало)

Число кейсов `^func test` в `battle-demo/tests/` по коммитам (`git grep -c`).
Удалённых тестов нет ни на одном шаге; падений нет; карантин не заводился.

| Состояние | Кейсов | Прибавление |
| --- | --- | --- |
| `4b6ab499` — до фазы 9 (боевое ядро, данные, спрайты) | 83 | — |
| `7e67a529` — гекс-поле + интерфейс боя (фаза 9) | 88 | +5 |
| `95589ad2` — враг-волк, пять треков | 88 | 0 |
| `74fe0668` — путь игрока + приёмка UI (10.10–10.14) | 98 | +10 |
| `889ab6d3` — панель поверженного, метка после боя, размер кадра (10.15–10.17) | 100 | +2 |
| рабочее дерево (10.18–10.21) | **106** | **+6** |

Нетто фазы 9–10: **+23 / −0** (83 → 106). Каждый новый кейс закрывает
конкретное отклонение read-агента или слепую зону smoke-прогона (см. §2).

## 6. Как прогонять

```sh
battle-demo/run_tests.sh                 # GdUnit4 headless, весь набор
```

Одиночный файл: `godot --headless --path battle-demo --script res://addons/gdunit4/bin/GdUnitCmdTool.gd -a res://tests/unit/combat/test_battle_screen.gd`.

Кадры приёмки (не тест): `godot --path battle-demo res://tools/capture_screens.tscn`
(нужен дисплей, `--headless` отдаёт пустой текстурный канал), затем
`python3 battle-demo/tools/ui_read_judge.py`.

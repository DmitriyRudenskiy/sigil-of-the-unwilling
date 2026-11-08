# Покрытие тестами — `turn-battle-core`

Задача 4.11 (`test-evidence-review`): каждая AC спеки
`openspec/changes/battle-demo-two-rosters/specs/turn-battle-core/spec.md` обязана
иметь тест. Вердикт: **ADEQUATE — 17/17 сценариев покрыты**.

Тесты — GdUnit4, `battle-demo/tests/unit/combat/` и `tests/unit/data/`.
Прогон: `battle-demo/run_tests.sh` → `Executed test cases: (68/68)`, GATE=GREEN.

| # | Requirement / Scenario | Тест (файл::функция) | Вердикт |
| --- | --- | --- | --- |
| 1 | Бой только пошаговый · Вне активного хода мир не меняется | `test_stepwise_only.gd::test_world_frozen_while_choosing`, `::test_world_changes_only_on_confirmed_choice` | PASS |
| 2 | Очередь хода по инициативе · Более быстрый юнит ходит раньше | `test_turn_queue.gd::test_order_by_initiative_descending` (+ `::test_tie_gives_player_side_first`, `::test_tie_within_side_ordered_by_slot`, `::test_order_independent_of_input_order`) | PASS |
| 3 | Очередь хода по инициативе · Детерминированный повтор | `test_determinism.gd::test_same_seed_reproduces_the_whole_battle`, `test_damage.gd::test_damage_reproducible_for_same_seed` | PASS |
| 4 | Очередь хода по инициативе · Мёртвый юнит выпадает из очереди | `test_turn_queue.gd::test_dead_units_are_skipped` | PASS |
| 5 | Одно действие за ход · Пропуск хода | `test_action_legality.gd::test_pass_is_always_available` | PASS |
| 6 | Одно действие за ход · Второе действие за ход невозможно | `test_action_legality.gd::test_one_action_per_turn` | PASS |
| 7 | Формула урона · Урон не ниже единицы | `test_damage.gd::test_damage_is_integer_and_at_least_one` | PASS |
| 8 | Формула урона · Смертельный удар | `test_damage.gd::test_lethal_hit_zeroes_hp_and_marks_dead` | PASS (тест добавлен в 4.11) |
| 9 | Статусы · Статус сгорает за длительность | `test_status_effects.gd::test_status_expires_after_its_duration` (+ `::test_stun_is_gone_next_turn`, `::test_bleed_ticks_damage_on_owner_turn`) | PASS |
| 10 | Статусы · Один и тот же статус не складывается бесконечно | `test_status_effects.gd::test_same_status_refreshes_instead_of_stacking` | PASS |
| 11 | Условия победы и поражения · Победа по последнему врагу | `test_battle_outcome.gd::test_victory_when_no_enemies_left` | PASS |
| 12 | Условия победы и поражения · Поражение по последнему юниту игрока | `test_battle_outcome.gd::test_defeat_when_no_player_units_left` | PASS |
| 13 | Условия победы и поражения · Ничьей нет | `test_battle_outcome.gd::test_stalemate_guard_reports_no_result` | PASS |
| 14 | Ход противника не требует игрока · Противник ходит сам | `test_enemy_ai.gd::test_enemy_acts_without_player_input` (+ `::test_enemy_uses_ready_ability`, `::test_enemy_falls_back_to_attack_without_focus`, `::test_enemy_targets_weakest_player_unit`, `::test_stunned_enemy_passes`) | PASS |
| 15 | Ход противника не требует игрока · Один и тот же seed даёт тот же выбор | `test_determinism.gd::test_same_seed_reproduces_the_whole_battle`, `::test_different_seed_changes_damage_draw` | PASS |
| 16 | Модель не зависит от отображения · Бой без сцены | `test_combat_without_scene.gd::test_battle_runs_without_touching_scene_tree`, `::test_combat_layer_has_no_display_references` | PASS |
| 17 | Смена набора не меняет правил · Один и тот же бой двумя наборами | `test_roster_invariance.gd::test_same_battle_with_two_rosters`, `::test_designed_pair_plays_by_the_same_rules` | PASS (тесты добавлены в 4.11) |

## Что добавлено в 4.11 и почему без этого было неполно

- `test_stepwise_only.gd` — сценарий 1 держался только на косвенных тестах:
  нигде не проверялось, что чтение (`legal_actions`, `alive`, `ability_state`) не
  меняет мир и что у модели нет собственного шага по времени.
- `test_damage.gd::test_lethal_hit_zeroes_hp_and_marks_dead` — сценарий 8 требовал
  «HP становится 0 и юнит помечается мёртвым»; раньше проверялся только исход боя
  целиком, а не клампинг HP и флаг `died` на смертельном ударе.
- `test_roster_invariance.gd` — сценарий 17 не проверялся вовсе: бой одним и тем
  же seed и скриптованным вводом (пропуск) двумя наборами даёт идентичный порядок
  ходов и идентичные числа урона; боевая пара из данных (`a`, `b`) доигрывается, а
  её очередь ходов отсортирована по инициативе.

## Тесты сверх AC (страховка, не покрытие)

- `test_damage.gd::test_variance_stays_in_band`, `::test_defense_reduces_damage`,
  `::test_defense_ignores_part_of_defense`, `::test_weaken_lowers_attack` —
  границы формулы.
- `test_status_effects.gd::test_unknown_status_is_rejected`, `::test_focus_is_capped`,
  `::test_focus_grows_only_after_first_turn` — инварианты модели.
- `test_battle_outcome.gd::test_queue_stops_after_battle_ended` — идемпотентность
  конца боя.
- `test_determinism.gd::test_battle_actually_happened` — краснеет, если детерминизм
  «достигнут» пустым боем.
- `tests/unit/data/*` — 16 тестов загрузчика и валидатора данных (задача 5.5),
  к AC `turn-battle-core` отношения не имеют.

## Вне охвата 4.11

AC спек `battle-demo-ui`, `battle-demo-sprites`, `roster-lineups` здесь не
размечены: у них свои задачи покрытия (7.x, 8.x, 9.x).

# Матрица покрытия AC — 70 сценариев четырёх спек

`tasks.md` 11.6 требует «по каждой AC спеки PASS/FAIL с указанием теста или
отчёта». AC здесь = каждый `#### Scenario:` четырёх спек изменения
`battle-demo-two-rosters` (ядро 17, наборы 9, UI 12, спрайты 32 = **70**).
Требования без сценариев в матрицу не попадают; случаи, где **тело**
требования противоречит носителю, вынесены в §5 отдельно.

Прогон, на который ссылается матрица: `battle-demo/run_tests.sh`,
`Executed test cases: (107/107) | 0 errors | 0 failures`, GATE=GREEN
(GdUnit exit 0), 2026-10-26; пофайловый аудит комплекта —
`python3 battle-demo/tools/audit_sprites.py`, «196 проверено, 196 принято, 0 брака,
0 отсутствует», отчёт `battle-demo/artifacts/sprite-audit.json` (тот же день).

Итог: **56 PASS, 11 CONCERNS, 3 FAIL**. Три FAIL — AC 21, 22, 26 (наборы и
спрайт-поле), все три упираются в §5. AC 50 и 61 (нейминг и отчёт аудита)
закрыты 2026-10-26 перерезкой комплекта под форму спеки — ADR-008.

## Как читать статус

| Статус | Значение |
| --- | --- |
| PASS | есть тест, или есть сохранённый в репо отчёт/артефакт с мерой по этому сценарию |
| CONCERNS | поведение есть, но держится не доказательством: проводка без теста, мера не по всем объектам, носитель вне git |
| FAIL | сценарий не выполняется, либо выполняется иначе, чем написано |

## 1. `turn-battle-core` — 17 сценариев

Разметка по сценариям ведётся с задачи 4.11 в `docs/test-evidence.md`
(вердикт ADEQUATE, 17/17); ниже — те же строки, сверенные с текущим набором
тестов (107 кейсов вместо 68 на момент 4.11).

| № | Сценарий | Статус | Доказательство |
| --- | --- | --- | --- |
| 1 | Вне активного хода мир не меняется | PASS | `test_stepwise_only.gd::test_world_frozen_while_choosing`, `::test_world_changes_only_on_confirmed_choice` |
| 2 | Более быстрый юнит ходит раньше | PASS | `test_turn_queue.gd::test_order_by_initiative_descending` (+ `::test_tie_gives_player_side_first`, `::test_tie_within_side_ordered_by_slot`, `::test_order_independent_of_input_order`) |
| 3 | Детерминированный повтор | PASS | `test_determinism.gd::test_same_seed_reproduces_the_whole_battle`, `test_damage.gd::test_damage_reproducible_for_same_seed` |
| 4 | Мёртвый юнит выпадает из очереди | PASS | `test_turn_queue.gd::test_dead_units_are_skipped` |
| 5 | Пропуск хода | PASS | `test_action_legality.gd::test_pass_is_always_available` |
| 6 | Второе действие за ход невозможно | PASS | `test_action_legality.gd::test_one_action_per_turn` |
| 7 | Урон не ниже единицы | PASS | `test_damage.gd::test_damage_is_integer_and_at_least_one` |
| 8 | Смертельный удар | PASS | `test_damage.gd::test_lethal_hit_zeroes_hp_and_marks_dead` |
| 9 | Статус сгорает за длительность | PASS | `test_status_effects.gd::test_status_expires_after_its_duration` (+ `::test_stun_is_gone_next_turn`, `::test_bleed_ticks_damage_on_owner_turn`) |
| 10 | Один статус не складывается бесконечно | PASS | `test_status_effects.gd::test_same_status_refreshes_instead_of_stacking` |
| 11 | Победа по последнему врагу | PASS | `test_battle_outcome.gd::test_victory_when_no_enemies_left` |
| 12 | Поражение по последнему юниту игрока | PASS | `test_battle_outcome.gd::test_defeat_when_no_player_units_left` |
| 13 | Ничьей нет | PASS | `test_battle_outcome.gd::test_stalemate_guard_reports_no_result` |
| 14 | Противник ходит сам | PASS | `test_enemy_ai.gd::test_enemy_acts_without_player_input` (+ 4 теста выбора врага) |
| 15 | Тот же seed — тот же выбор | PASS | `test_determinism.gd::test_same_seed_reproduces_the_whole_battle`, `::test_different_seed_changes_damage_draw` |
| 16 | Бой без сцены | PASS | `test_combat_without_scene.gd::test_battle_runs_without_touching_scene_tree`, `::test_combat_layer_has_no_display_references` |
| 17 | Один и тот же бой двумя наборами | PASS | `test_roster_invariance.gd::test_same_battle_with_two_rosters`, `::test_designed_pair_plays_by_the_same_rules` |

## 2. `roster-lineups` — 9 сценариев

| № | Сценарий | Статус | Доказательство |
| --- | --- | --- | --- |
| 18 | Враг не выбирается игроком | PASS | `test_data_library.gd::test_enemy_is_not_in_the_pool` (ни в одном наборе) + кадры `a_start`/`b_mid` (справа один волк) |
| 19 | Набор из шести отклонён | PASS | `test_data_validation.gd::test_roster_of_wrong_size_is_reported` |
| 20 | Повтор юнита в наборе отклонён | PASS | `test_data_validation.gd::test_duplicate_unit_in_roster_is_reported` |
| 21 | Покрытие обоих наборов | **FAIL** | покрытие = 9 юнитов пула, пересечение A∩B = 5 (спека ждёт 8 и 6). Тест слабее спеки: `test_rosters_differ_symmetrically` требует лишь `only_a > 0` и симметричности. См. §5-А |
| 22 | Различие наборов | **FAIL** | у каждого набора по **два** юнита, отсутствующих в другом (A: `knight`, `spearman`; B: `priest`, `stormmage`), спека ждёт один. См. §5-А |
| 23 | Выбранный набор попал в бой | PASS | `test_roster_select.gd::test_choice_is_written_to_the_flow` + кадры `a_start` (есть `knight`) и `b_mid` (его нет, есть целитель) |
| 24 | Смена набора между боями | CONCERNS | проводка есть: `battle_result.change_roster` → `battle_screen.gd:60` → `change_scene_to_file(DemoFlow.ROSTER_SCENE)`; тестом переход не проверяется. Съёмка меняет набор в одном процессе, но через `start_roster`, минуя экран результата |
| 25 | Новый набор без правок кода | CONCERNS | валидатор принимает любой набор из семи (12 тестов `test_data_validation.gd` собраны на синтетических наборах); набора, добавленного **в данные** и сыгранного обоими способами, в тесте нет |
| 26 | Юнит без спрайта | **FAIL** | у `UnitStats` нет поля спрайта: дорожка ищется по имени `assets/sprites/<id>.sprite_frames.tres` (`battle_unit_view.gd:98`), при отсутствии — `push_warning` и юнит «без картинки». Требование «запуск завершается ошибкой» не выполняется ни чем. См. §5-В |

## 3. `battle-demo-ui` — 12 сценариев

| № | Сценарий | Статус | Доказательство |
| --- | --- | --- | --- |
| 27 | Обновление полосы после урона | PASS | `test_battle_screen.gd::test_bars_match_the_model_after_every_action` |
| 28 | Мёртвый юнит | PASS | `test_battle_screen.gd::test_dead_unit_keeps_an_empty_bar`, `::test_the_fallen_sprite_is_desaturated_at_once`, `::test_fallen_unit_is_marked_with_a_cross` |
| 29 | Очередь следует за боем | PASS | `test_battle_hud.gd::test_strip_has_one_card_per_unit`, `::test_round_counter_follows_the_queue`, `::test_the_current_card_is_outlined_in_gold` |
| 30 | Смерть юнита в очереди | PASS | `test_battle_hud.gd::test_dead_units_leave_the_order_strip` |
| 31 | Недоступная способность | PASS | `test_battle_hud.gd::test_ability_button_goes_dark_on_cooldown`, `::test_focus_pips_match_the_active_unit` |
| 32 | Смена активного юнита | PASS | `test_battle_hud.gd::test_focus_pips_match_the_active_unit`, `::test_the_current_card_is_outlined_in_gold` |
| 33 | Выбор без мыши доступен | PASS | `test_roster_select.gd::test_selection_moves_between_cards` (события `ui_right`/`ui_left`), `::test_choice_is_written_to_the_flow` |
| 34 | Победа на экране результата | PASS | `test_battle_result.gd::test_result_screen_appears_with_the_outcome` + кадры `a_result`, `b_result` |
| 35 | Действие после результата игнорируется | PASS | `test_battle_result.gd::test_no_battle_actions_after_the_result`, `::test_action_after_the_result_changes_nothing` (второй — guard вместо `assert`, найден ревью диффа 11.2) |
| 36 | Проверка синхронности после серии ходов | PASS | `test_battle_screen.gd::test_bars_match_the_model_after_every_action` (серия = весь прогон до финала) |
| 37 | Комплект кадров для обоих наборов | PASS | носитель — съёмка: `tools/capture_screens.tscn` → 8 строк `→ OK (1920x1080)`; отчёт `docs/ui-read-judge-2026-10-26.md` с md5 всех восьми |
| 38 | Нечитаемый интерфейс | PASS | тот же отчёт: по восьми кадрам fail-кейсов нет; числа с кадров сверены со строкой модели, а не с памятью агента |

## 4. `battle-demo-sprites` — 32 сценария

Носитель большинства — не GdUnit, а инструменты конвейера и их отчёты:
`tools/gen_clip.py` (мерный аудит клипа), `artifacts/clips-apose/**/report.json`
(23 отчёта), `artifacts/verdicts.json` (57 визуальных вердиктов),
`artifacts/generation-manifest.json` (184 записи: путь, md5, seed, модель,
промпт), `docs/generation-log.md`, `docs/known-issues.md`.

| № | Сценарий | Статус | Доказательство |
| --- | --- | --- | --- |
| 39 | Полнота комплекта | CONCERNS | `test_sprite_tracks.gd::test_every_unit_has_four_tracks_of_four_frames` держит 10 юнитов × 5 дорожек × 4 кадра с одной карантиной строкой (`priest/hit`, уезд ступней 65 px при пороге 8 px); с 2026-10-26 полноту мерит и `tools/audit_sprites.py` — ожидаемое множество строится из `data/units/`, absent-файлы попадают в `missing` отчёта. Листов **10**, а не девять: волк — десятый носитель, его требует `roster-lineups`. См. §5-Г |
| 40 | Кадр без альфы | PASS | `tools/audit_sprites.py` проверяет режим PNG (RGBA) по **каждому** файлу комплекта, вердикт — в `artifacts/sprite-audit.json` (196 строк, 196 принято); приёмник `tests/helpers/sprite_asserts.gd::check_frame` и 5 тестов на него остались |
| 41 | Персонаж обрезан по краю | PASS | мера — bounding box альфы (`audit_sprites.py`: касание края = брак). Первый прогон нашёл обрезанный кадр `char_enemy_wolf_attack_02.png` (0..512 по ширине); сборка ограничила силуэт ещё и по ширине (`EDGE_MARGIN = 8`), перерезанный кадр проходит. Read-агент раундов r1–r4 обрезку ловил, но числа не давал |
| 42 | После ункея остался хромакей | PASS | мера `chroma_share` / `chroma_pixels_kept` в `gen_clip.py:376`, порог 0.0005; замеры в 23 `report.json` и в `docs/known-issues.md` №6 |
| 43 | Гибель не требует отдельной анимации | PASS | `test_sprite_tracks.gd` (дорожек `death` нет ни у кого) + `test_battle_unit_view.gd::test_death_stops_on_the_last_frame_and_desaturates` |
| 44 | Недостаточная длина анимации | PASS | длина держится тестом `test_sprite_tracks.gd` (ровно 4 кадра), а отсутствие кадра в дорожке мерит `tools/audit_sprites.py`: ожидаемое множество — 4 кадра на дорожку, недостающий файл идёт в `missing` отчёта (сейчас пусто, кроме карантинной `priest/hit`) |
| 45 | Полный набор анимаций | PASS | `test_sprite_tracks.gd` — пять дорожек `idle/walk/attack/hit/turn` по 4 кадра у всех десяти юнитов |
| 46 | Разный масштаб между листами | CONCERNS | масштаб сводит сборка (силуэт → 384 px холста 512, ступни в (256, 448); на экран попадает с `ENGINE_SCALE = 0.25`), тест `test_battle_unit_view.gd::test_turn_keeps_scale_and_pivot` держит масштаб в движке; кросс-листовой меры «10 листов в одном масштабе» нет |
| 47 | Кадры одного клипа разъехались по pivot | PASS | меры `pivot_slide_x`, `pivot_sway_x`, `contact_slide_x` (`gen_clip.py:372–375`, пороги 24 px / 8 px), 23 `report.json` |
| 48 | Юниты игрока идут вправо | PASS | `test_battle_unit_view.gd::test_walk_moves_player_right_and_enemy_left` |
| 49 | Разворот не меняет масштаб | PASS | `test_battle_unit_view.gd::test_turn_keeps_scale_and_pivot` |
| 50 | Кадр с именем вне схемы | PASS | комплект перерезан под схему (ADR-008): `assets/sprites/<id>/char_<side>_<name>_<anim>_<NN>.png`, `NN` с единицы; `audit_sprites.py` сверяет имя с регуляркой, каталог — с id в имени, а побайтовые дубликаты кадров отклоняет. 196/196 имён в схеме |
| 51 | Кадр не похож на источник | PASS | `artifacts/verdicts.json` — 57 вердиктов по кадрам `artifacts/gen/`, реестр прогонов `docs/generation-log.md`, источник и id — таблица `docs/asset-spec.md` |
| 52 | Источник не соответствует id | CONCERNS | соответствие ведёт реестр `docs/asset-spec.md` (10 строк «файл-источник → id»); автоматической проверки «файл источника ↔ id юнита ↔ лист» нет |
| 53 | Кадр исказил внешность или стиль | PASS | те же 57 вердиктов по чек-листу `docs/art-bible.md`; отклонённое возвращалось на переген (см. №57) |
| 54 | Повторный прогон не тратит генерацию зря | PASS | манифест `artifacts/generation-manifest.json` (md5 каждого принятого кадра) + пропуск готового в `gen_frames.py`/`gen_clip.py` (`--reaudit` пересчитывает меру без перегенерации) |
| 55 | Сбой инструмента генерации | CONCERNS | сбои пишутся в `artifacts/*.log` (`clip-batch.log`, `kit.log`, `a-pose.log`) и не проглатываются; тест на «сбой виден» не написан, часть логов — gitignored |
| 56 | Анимация не двинулась | PASS | мера `motion_first_last` с порогом 2.0 (`gen_clip.py:360`) в тех же 23 отчётах |
| 57 | Скелет взятого не у того персонажа | CONCERNS | скелет извлекается из кадра своего же персонажа (`tools/dwpose_cli.py`, `tools/make_poses.py`, `assets/poses/`); автоматической проверки «поза A-pose ↔ id» нет, держится порядком вызова |
| 58 | Правленый скелет сломал пропорции | CONCERNS | ловит read-агент и машинная мера силуэта; случаи и исходы — `docs/known-issues.md` №1–№2. Пофайлового отчёта правки скелета нет |
| 59 | Четыре одинаковых позы в одном листе | PASS | тот же `motion_first_last`: одинаковые кадры дают движение ≈ 0 < 2.0 → лист бракуется (`gen_clip.py:360`) |
| 60 | Поза кадра не совпала с поданной картой | CONCERNS | сверка — визуальная (read-агент по кадру и по карте позы); числовой меры «поза на кадре = поданная DWPose-карта» нет |
| 61 | Отчёт покрывает все файлы | PASS | `tools/audit_sprites.py` (названный в контракте фазы 7 аудитор) прогоняется по всему комплекту: `artifacts/sprite-audit.json` содержит строку-вердикт на каждый из 196 файлов и итоговые счётчики `checked` / `accepted` / `rejected` / `missing`. См. §5-Б (закрыт) |
| 62 | Отклонение ведёт к регенерации | PASS | `docs/generation-log.md` (итерации по строкам «персонаж/анимация/кадр/seed/вердикт»), новые seed в `generation-manifest.json`, четыре раунда правок в `docs/ui-read-judge-2026-10-25*.md` |
| 63 | Потолок итераций | PASS | правило «три правки → в известный дефект» отработано: `priest/hit` зафиксирован в `docs/known-issues.md` и в `INCOMPLETE` теста, работа по остальным шла дальше |
| 64 | Контактный лист всех персонажей | PASS | `tools/gen_contact_sheet.py` → `artifacts/contact-sheet.jpg` (в git), стилевая сверка — `docs/art-bible.md` |
| 65 | Разворот не в ту сторону | PASS | `test_battle_unit_view.gd::test_enemy_side_is_mirrored` (враг — зеркало, не отдельная генерация) + `tools/mirror_anim.py` |
| 66 | Оружие «плавает» или кисть мимо рукояти | CONCERNS | лист экипировки и его итерации (`tools/gen_kit.py`, `assets/kit/`, `artifacts/kit/`) — **вне git** (0 отслеживаемых файлов): вердикт есть, воспроизводимого носителя нет |
| 67 | Поза запрошена без собранного кадра | CONCERNS | конвейер требует собранный A-pose-кадр (`tools/gen_a_pose*.py` → `gen_clip_apose.py`), отказа «позы нет — стой» как отдельной проверки нет |
| 68 | Модель вернула кадр на белом фоне | PASS | мера `flat_white_share` (порог 0.25) + ункей; история дефекта и его снятия — `docs/known-issues.md`, комментарий `test_sprite_tracks.gd` (угол зелёный → 31 принят из 33) |
| 69 | Фон не залился | PASS | в каждый `report.json` пишется `corner_before_clip` (цвет угла до кейя) — «белый вместо хромакея» видно по отчёту |
| 70 | Реакция не держит ступни | PASS | мера `contact_slide_x` с порогом 8 px (`gen_clip.py:374`); именно она забраковала `priest/hit` (65 px) |

## 5. Конфликты «спека ↔ носитель» (тело требования, не сценарий)

Это не «недоделано», а расхождение текста спеки с тем, что лежит в репо. Кроме
случая Б — он решён 2026-10-26 записью ADR-008 (носитель перерезан под спеку).
Остальные ни одним решением не оформлены, поэтому gate-check считает их
блокерами: править надо или спеку, или носитель.

### А. Размер пула и сдвиг наборов

Спека `roster-lineups`: пул = **восемь** юнитов, A = позиции 1–7, B = 2–8,
пересечение 6, по одному уникальному юниту в наборе (Purpose той же спеки
говорит «пул из девяти» — спека противоречит сама себе).
Носитель: `data/units/*.tres` — **девять** юнитов пула + волк; A = 1–7,
B = 3–9; пересечение 5, по два уникальных. `docs/design-brief.md` («Маг грозы
вернулся в пул девятой позицией, составы наборов от этого не изменились»)
описывает B как 2–8 — то есть расходится с данными тоже.
Тест `test_rosters_differ_symmetrically` намеренно слабее обеих версий
(`only_a > 0` + симметричность), поэтому гейт зелёный при любом из трёх чтений.

### Б. Техническая форма кадра и нейминг (закрыт 2026-10-26, ADR-008)

Спека (и `proposal.md`, и `docs/asset-spec.md`, и `docs/art-bible.md`): кадр
**512×512** RGBA, имя `char_<side>_<name>_<anim>_<NN>.png`, программный аудит по
каждому файлу с отчётом и счётчиками. Носителем был комплект **128×128** с
именами `<id>/<anim>/00..03.png`, аудитор `tools/audit_sprites.py` отсутствовал.
Владелец выбрал закрытие перерезкой (не правкой спеки): комплект собран заново в
512×512 со ступнями в (256, 448) и именами по схеме в `assets/sprites/<id>/`,
аудитор написан, отчёт — в `artifacts/sprite-audit.json`. Записи-решения до этой
даты не было; теперь это ADR-008. Остаток — только пересъёмка карантинной
`priest/hit` (известная проблема, не часть этого случая).

### В. Спрайт как поле данных

Спека требует, чтобы отсутствие спрайта у юнита набора останавливало запуск с
именем юнита и отсутствующим полем. В модели спрайта нет как поля: связь id →
дорожка — соглашение пути в слое отображения, отсутствие — `push_warning`.

### Г. Девять листов против десяти

Спека `battle-demo-sprites` считает девять листов «по одному на персонажа
источника» и требует отсутствия лишних. Комплекту десять листов требует
`roster-lineups` (волк — постоянный враг). Обе спеки в одном изменении;
примиряющей записи нет.

## 6. Что закрывает CONCERNS дёшево

| Строка | Минимальное действие |
| --- | --- |
| 40, 44, 46, 50, 61 | один прогон `sprite_asserts.check_frame` по 196 файлам комплекта + проверка схемы имён + отчёт в `artifacts/` (счётчики принятых/отклонённых). Это закрывает и §5-Б, если число кадра там же зафиксировать как решение |
| 21, 22 | либо правка спеки под design-brief и данные, либо наборов до сдвига в одну позицию; тест — точное число уникальных |
| 24 | тест: `change_roster` → активная сцена = `roster_select.tscn` |
| 25 | третий набор в тестовых данных + прогон обоими путями выбора |
| 26 | проверка наличия дорожки в `DataLibrary.validate` (id → файл) |
| 66 | Строки листа экипировки (предмет, seed, вердикт) в `docs/generation-log.md`; пиксели остаются в gitignore (`assets/kit/` — 21 МБ, пересобирается `tools/gen_kit.py`) |

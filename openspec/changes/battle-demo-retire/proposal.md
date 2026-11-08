## Why

Судьба `battle-demo/` была последней позицией реестра корня, внесённой туда как
«ждёт решения» (Q-M139, `[human]`). Владелец решил её 2026-11-09: перенести
наработки в основной проект и папку удалить. Факты на момент решения (замерено,
не «по ощущению»):

- на диске 153 МБ, в индексе 1075 файлов; после D-320 конвейер кадров живёт в
  `scripts/character_kit/`, и в стенде от него осталась одна `.gd`-сериализация
  `.sprite_frames` плюс то, что он читает;
- игрой стенд не исполняется: `git grep battle-demo -- game/scripts game/tests`
  даёт четыре комментария и ни одной загрузки ресурса, в `ci2.yml`, в гейты
  `scripts/` и в `test_compile_all` он не заходит ни одним шагом;
- **двойники, которым нечего переносить**: `addons/gdunit4` — 517 файлов,
  побайтово равных `game/addons/gdunit4` (обе 6.2.1); 176 кадров спрайтов
  (26,4 МБ) побайтово равны копиям в `game/assets/sprites/`;
- **уникальное, что и есть наработки**: 10 портретов (8,4 МБ), 20 кадров
  `cutthroat` (3,2 МБ) — девятого персонажа комплекта, которого в игре нет, —
  кадр-образец `reference/walk-sample.png` (0,36 МБ), `tools/build_sprite_frames.gd`
  (единственный шаг конвейера, обязанный идти из-под Godot) и запись самого
  демо-проекта: 21 документ + его `CHANGELOG.md`;
- цена ожидания: второй `project.godot`, `run_tests.sh`, `addons/` и 111 МБ
  кэша `.godot/` в корне, открытая строка в закрытом иначе реестре и две живые
  спек-способности, названные в честь каталога, который предлагается удалить.

## What Changes

Разделение по одному признаку — **есть ли у носителя потребитель в основном
проекте**:

- переезжает уникальное: портреты и девятый лист → в носитель конвейера
  (`scripts/character_kit/portraits/`, `scripts/character_kit/sprites/cutthroat/`),
  `build_sprite_frames.gd` → в `game/tools/` (шаг работает с `res://assets/sprites/…`,
  то есть с деревом игры), образец и запись демо-проекта → в архив
  (`scripts/character_kit/runs/`, `docs/archive/battle-demo/`);
- удаляется всё остальное: боёвка и UI стенда, её 42 теста, её сцены и `.tres`,
  `project.godot`, `run_tests.sh`, аддон-двойник, дубли кадров. Боевая модель
  стенда в игру не переносится сознательно: она расходится с каноном
  `docs/02d-combat-core.md` (бескубиковая лестница K2), а собственный
  `design-brief.md` стенда открещивается от чисел основной игры. Восстановление —
  `git show HEAD~1:battle-demo/<путь>`;
- `scripts/character_kit/` теряет корень `STAND`: портреты и листы читаются из
  носителя конвейера, список персонажей для аудита берётся из `spec.json`, а не
  из `battle-demo/data/units/*.tres`. Строка `battle-demo` остаётся только в
  исторических носителях;
- способность `battle-demo-ui` выводится (6 требований REMOVED с миграцией на
  живые `battle-hud` / `battle-ui` / `battle-unit-figures`), в
  `battle-demo-sprites` правится одно требование: реестр `INCOMPLETE` теряет
  носителя в тесте стенда и остаётся в `scripts/character_kit/audit_sprites.py`;
- реестр корня теряет строку `battle-demo` (12 носителей вместо 13), Q-M139
  закрывается решением владельца, живые упоминания носителя переадресовываются.

## Capabilities

### New Capabilities

Нет: изменение ничего не вводит — оно выводит лишний носитель и перекладывает
уникальное.

### Modified Capabilities

- `battle-demo-ui`: способность выводится целиком — её шесть требований описывают
  интерфейс стенда, носитель которого удаляется. Мигрируют на живые `battle-hud`,
  `battle-ui`, `battle-unit-figures`; чек-лист судьи `ui_read_judge.py` переезжает
  в README конвейера, чтобы судья не остался без текста приёмки.
- `roster-lineups`: выводится целиком (шесть требований) — два набора A/B живут в
  `battle-demo/data/rosters/*.tres`, персонажи пула как носители кадров переезжают,
  а сам инвариант состава без стенда некому держать.
- `battle-demo-sprites`: одно требование («Первый кадр клипа входит в I2V на
  залитом хромакее») ссылается на `INCOMPLETE` в тесте стенда — носитель
  реестра меняется на `scripts/character_kit/audit_sprites.py`.

`turn-battle-core` (9 требований доканонного пошагового боя) эта смена **не
трогает**: она не называет ни одного файла стенда и спорит с каноном
`dnd-battle-ladder` независимо от судьбы папки. Вопрос выносится отдельным
`[human]` (Q-M140) — см. design.md.

## Impact

`battle-demo/` (удаляется, 1075 файлов), `scripts/character_kit/` (носители +
`paths.py` + `spec.json` + `audit_sprites.py` + `gen_kit.py` + README),
`game/tools/build_sprite_frames.gd` (новый шаг), `docs/archive/battle-demo/`
(новый архивный носитель, вне графа доков по прецеденту `docs/bank/`, D-102),
`scripts/check_repo_layout.py` (реестр корня), `scripts/check_docs_links.py` и
его потребители (исключение архивной зоны), `openspec/specs/battle-demo-ui/`
(удаляется при синхронизации), живые упоминания: `README.md`,
`docs/18-system-map.md`, `docs/mvp/HERO-ANIM.md`,
`game/scripts/entities/character_frames.gd`, `game/assets/PROVENANCE.md`,
`game/tests/unit/ui/test_battle_figures_animated.gd`, `openspec/changes/README.md`,
`docs/QUESTIONS.md` (Q-M139 закрывается, поднимается Q-M140 про `turn-battle-core`),
`docs/DECISIONS.md` (D-321), `docs/CHANGELOG.md`.

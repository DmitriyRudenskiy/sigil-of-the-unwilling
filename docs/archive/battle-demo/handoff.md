# Handoff — что делать дальше с `battle-demo`

Документ для следующей сессии (или для человека, который решит запустить демо
руками). Всё, что нужно знать, чтобы не читать 437 строк `tasks.md`.

## Запустить

```
/Applications/Godot.app/Contents/MacOS/Godot --path battle-demo
```

Стартовая сцена — `res://scenes/roster_select.tscn` (`project.godot`,
`run/main_scene`): выбор набора стрелками ←/→ и Enter → бой. Мышью: кнопки
команд в HUD («Атака», способности, «Ждать», «Меню»); на экране результата —
«Повтор» (он же Enter) и «Сменить набор». Победа достигается на 19–21-м ходу в
обоих наборах.

## Гейт и smoke

```
battle-demo/run_tests.sh          # GdUnit4 headless; артефакт — artifacts/gate.log
godot --headless --path battle-demo -s res://tools/smoke_battle.gd
```

Ожидаемый зелёный прогон на сегодня: `Executed test cases: (107/107) |
0 errors | 0 failures`, GdUnit exit 0, GATE=GREEN. Smoke:
`набор a: … ходов=21`, `набор b: … ходов=19`. Коды выхода GdUnit: `0` — pass,
`101` — только orphan-предупреждения (гигиена, не падение), `100` — реальные
падения.

## Съёмка кадров приёмки

```
godot --path battle-demo res://tools/capture_screens.tscn   # поднимает GUI-окно
```

Восемь кадров в `tmp/shots/` (пиксели в git не идут, D-185): `a_select`,
`a_start`, `a_mid`, `a_result`, `b_select`, `b_start`, `b_mid`, `b_result`.
После съёмки — `md5 -q`, хэши в `docs/ui-read-judge-<дата>.md`.

## Где что лежит

| Что | Место |
| --- | --- |
| Правила боя (без нод) | `scripts/combat/` + `scripts/data/` |
| Отображение | `scripts/view/` (юнит, HUD, экран результата, выбор набора) |
| Данные | `data/units/*.tres` (10 юнитов), `data/rosters/{a,b}.tres` |
| Спрайты | `assets/sprites/<id>/<anim>/00..03.png` → `*.sprite_frames.tres` |
| Конвейер генерации | `tools/gen_frames.py`, `gen_a_pose*.py`, `gen_kit.py`, `gen_clip_apose.py`, `gen_clip.py`, `dwpose_cli.py`, `make_poses.py`, `build_sprite_frames.py`, `mirror_anim.py`, `gen_contact_sheet.py` |
| Тесты | `tests/unit/`, `tests/integration/`, `tests/functional/`, хелперы `tests/helpers/` |
| Отчёты вердиктов | `artifacts/verdicts.json`, `artifacts/generation-manifest.json`, `artifacts/clips-apose/**/report.json`, `artifacts/gate.log` |
| Документация фаз | `docs/` (контракт фаз — `docs/agent-skills.md`) |

## Что не сделано и почему

1. **Два блокера ворот** (`docs/gate-check.md` §4): форма кадра 128×128 и схема
   имён против SHALL-текста `battle-demo-sprites`; пул 9 юнитов и сдвиг наборов
   1–7/3–9 против «8 и 2–8» в `roster-lineups`. Оба — «спека ↔ носитель»,
   кода почти не касаются. Решение за владельцем: запись в `docs/decisions.md`
   и правка спеки, либо перерезка комплекта/данных.
2. **Пофайловый аудит комплекта** (AC 40/44/46/50/61): `tests/helpers/sprite_asserts.gd`
   умеет проверять размер, альфу, пустые и отсутствующие кадры, но по 196 файлам
   не запускался; мерный отчёт есть по 23 дорожкам из 45. Это один скрипт-прогон.
   → закрыто 2026-10-26 (`7e6e733f`): `tools/audit_sprites.py` меряет все 196
   файлов, отчёт `artifacts/sprite-audit.json` (196 принято, 0 брака).
3. **Три дешёвых теста**: переход по «Сменить набор» (AC 24), третий набор в
   данных (AC 25), проверка наличия спрайт-пути в `DataLibrary.validate` (AC 26).
   → снято 2026-10-26 (`ed8d442b`) два из трёх: AC 24 и AC 26. Остаётся AC 25 —
   третьего набора в данных нет, `ROSTERS` по-прежнему `["a", "b"]`.
4. **`priest/hit`** — карантин: уезд ступней 65 px при пороге 8 px, три итерации
   правок не помогли (`docs/known-issues.md` №6, правило трёх итераций).
   Нужен отдельный «поверженный» кадр ассета, иначе четвёртая итерация — та же
   трата генерации.
5. **Звено «поза без собранного кадра» и «скелет не того персонажа»** (AC 57, 60,
   67) держатся порядком вызова конвейера и глазом read-агента, числовой проверки
   нет.
6. **Звук и playtest** — отложены: нечем снимать (AGENTS.md).

## Правила, которые легко нарушить

- Работа только в `main`; push — только по явному «мержи» владельца; CI не поллится.
- Пиксели в git не коммитятся; отчёты, хэши и манифесты — коммитятся.
- `game/` в этом проекте не трогается: демо — отдельный Godot-проект со своим
  `addons/gdunit4` и своим `run_tests.sh`.
- Тесты не должны зависеть от порядка: каждый создаёт бой себе через
  `tests/helpers/battle_factory.gd`, общий `ProjectSettings` тесты не меняют.
- В тестах не `assert` (он вырезается в release-сборке) — `guard`/`add_info`.

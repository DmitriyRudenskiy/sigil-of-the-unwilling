# Конвейер кадров персонажа

Портрет → A-pose → скелет позы этого же персонажа → лист кадров → `.sprite_frames`.
С 2026-11-09 живёт здесь; до этого — в `battle-demo/tools/`, внутри демо-стенда,
который ничем в конвейере не управлял, а только был его пропиской (перенос —
смена `battle-demo-donor-transfer`, запись в `docs/DECISIONS.md`).

## Чем отличается от `scripts/concept_art/`

Второй ComfyUI-путь репозитория, и он про другое: `concept_art/` печатает
**концепт-арт и экраны** (один кадр по промпту, webp, для UI и документов), этот
пакет печатает **анимацию персонажа** — цепочку шагов, где каждый следующий
редактирует кадр предыдущего и позу задаёт скелет, извлечённый из кадра того же
персонажа (D13, D14 в `spec.json`). Графы непересекающиеся: общие ключи у двух
`spec.json` — только адрес сервера. Слияния не было сознательно: за каждым
прогоном стоят принятые кадры, переписывать их под общий конфиг нечем.

## Где что лежит

| Что | Где | В git |
|-----|-----|-------|
| Код, графы (`workflows/`), `spec.json` | `scripts/character_kit/` | да |
| Скелеты DWPose (`poses/`), A-pose v2, звери | `scripts/character_kit/` | да |
| Портреты девяти персонажей (`portraits/`) | `scripts/character_kit/portraits/` | да |
| Девятый лист `cutthroat` — кадр, которого в игре нет (`sprites/`) | `scripts/character_kit/sprites/` | да |
| Запись прогонов: манифесты, вердикты, аудиты, логи, contact sheet, образец похода (`runs/`) | `scripts/character_kit/runs/` | да |
| **Вывод прогонов**: клипы Wan 2.2, генерация, A-pose, зеркала (~1,7 ГБ) | `character_kit/` в корне репо | **нет** |
| Принятые кадры, которые грузит игра | `game/assets/sprites/` | да |
| Шаг сериализации `.sprite_frames` (Godot) | `game/tools/build_sprite_frames.gd` | да |
| Запись самого демо-стенда (21 документ + его `CHANGELOG.md`) | `docs/archive/battle-demo/` | да |

Вывод вне дерева по той же причине, по какой в git нет пикселей (D-185): он
воспроизводим прогоном, а весит больше, чем весь остальной репозиторий. Пути
задаёт `spec.json` (относительные — от корня репо) и `paths.py` (пять корней:
`REPO`, `PKG`, `OUT`, `RUNS`, `SPRITES`). Больше нигде путь не зашивается: до
переноса `ROOT` значил то корень стенда, то корень репозитория, а строка
`"battle-demo"` была вшита в двенадцати местах.

## Прогон

Из корня репозитория, сервер генерации по умолчанию `http://192.168.0.230:8188`
(`spec.json` → `comfy`):

```bash
python3 scripts/character_kit/make_portraits.py            # портрет → крой
python3 scripts/character_kit/gen_a_pose.py                # портрет → A-pose
python3 scripts/character_kit/dwpose_cli.py кадр.png --out кадр.json
python3 scripts/character_kit/make_poses.py --character knight --animation walk
python3 scripts/character_kit/gen_frames.py --character knight --workers 3
python3 scripts/character_kit/gen_clip.py --char knight --anim idle
python3 scripts/character_kit/build_sprite_frames.py --char knight
python3 scripts/character_kit/audit_sprites.py             # код 0 = комплект чист
python3 scripts/character_kit/gen_log.py                   # реестр прогонов
bash    scripts/character_kit/comfy_check.sh               # сервер жив
```

Шаги связаны файлами, не вызовами: `gen_frames.py` пишет манифест, `gen_clip.py`
читает его и пишет вердикты, `build_sprite_frames.py` пишет план, а
`game/tools/build_sprite_frames.gd` по этому плану сериализует ресурс —
единственная часть конвейера, которая обязана идти из-под Godot:

```bash
godot --headless --path game --import
godot --headless --path game --script res://tools/build_sprite_frames.gd
```

## Зависимости

Ни одна не объявлена в репозитории — манифеста зависимостей у проекта нет ни для
одного инструмента. Проверено на машине владельца, Python 3.12:

- `Pillow`, `numpy` — обычные, из PyPI.
- `dwpose` **1.0.1** (`pip show dwpose`: PyPI, <https://github.com/nicehero/dwpose>) —
  `python3 -m pip install dwpose==1.0.1`. Веса детектора (`yolox_l.onnx`,
  `dw-ll_ucoco_384.onnx`) пакет тянет сам при первом вызове. Это единственная
  зависимость, без которой шаг не заведётся, и единственная, что тянет за собой
  сотни мегабайт; в git она не едет ни в каком виде.
- `ffmpeg`/`ffprobe` — для разбора клипов (`gen_clip.py`, `mirror_anim.py`).
- ComfyUI-сервер `192.168.0.230:8188` и MCP-сервер `192.168.0.230:9000` — чужие
  машины в локальной сети, их нет ни в каком клоне.

## Что осталось от стенда

Стенд `battle-demo/` выведен из репозитория 2026-11-09 (Q-M139 закрыт, смена
`battle-demo-retire`). Из его папки сюда переехали портреты, девятый лист
`cutthroat` и образец похода; запись самого демо-проекта — в
`docs/archive/battle-demo/` (вне графа живых документов, по образцу `docs/bank/`).

- Ключи в `runs/verdicts.json` — вида `battle-demo/artifacts/clips/<персонаж>/<анимация>`.
  Это идентификаторы записей, а не пути: переписывать их означало бы открепить
  уже вынесенные вердикты.
- `ui_read_judge.py` остаётся, но новых кадров больше не появится: съёмку вели
  `capture_*.gd` стенда. Он пересматривает снятое в
  `character_kit/artifacts/screenshots/`. Его чек-лист был в спеке
  `battle-demo-ui`, та выведена, поэтому текст приёмки живёт здесь:
  читается ли имя и число за 3 фута, не сливаются ли два соседних значения,
  видно ли чей ход, отличим ли выбранный юнит, читаются ли подписи кнопок на
  фоне боя, не перекрывает ли что-нибудь здоровье активного юнита.
- `a_pose_v2/` — десять кадров, и все десять в git: их читают
  `gen_clip_apose.py` и `mirror_anim.py` как источник, а перегенерация стоит
  оплаченной GPU-сессии. Девять из них жили в дереве и не в индексе (один волк
  был) — это единственный экземпляр, поэтому дописан, а не выкинут.
- Девятый персонаж (`cutthroat`) в игру не едет: силуэта в
  `CharacterFrames.ANIMATED` нет, как и записи в реестре юнитов. Аудит его
  проверяет (`audit_sprites.py` берёт его из `sprites/`), вердикты — в `runs/`.

## Проверка

`python3 scripts/character_kit/test_character_kit.py` — что ни один корень
пакета не смотрит путями в выведенный стенд, вывод закрыт `.gitignore`, и что
приёмка на сломанном входе возвращает `fail` с причиной. Гоняется в
`scripts/doc_gates.sh`.

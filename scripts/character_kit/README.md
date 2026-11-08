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
| Запись прогонов: манифесты, вердикты, аудиты, логи, contact sheet (`runs/`) | `scripts/character_kit/runs/` | да |
| **Вывод прогонов**: клипы Wan 2.2, генерация, A-pose, зеркала (~1,7 ГБ) | `character_kit/` в корне репо | **нет** |
| Портреты и готовые спрайты, которые читает движок | `battle-demo/assets/` | да |

Вывод вне дерева по той же причине, по какой в git нет пикселей (D-185): он
воспроизводим прогоном, а весит больше, чем весь остальной репозиторий. Пути
задаёт `spec.json` (относительные — от корня репо) и `paths.py` (четыре корня:
`REPO`, `PKG`, `OUT`, `RUNS`, `STAND`). Больше нигде путь не зашивается: до
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
`battle-demo/tools/build_sprite_frames.gd` по этому плану сериализует ресурс —
единственная часть конвейера, которая обязана идти из-под Godot.

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

## Что осталось при стенде

- `assets/portraits` и `assets/sprites` читаются из `battle-demo/`: их требует
  рантайм стенда по `res://`, а у игры уже своя копия кадров. Куда кладать
  финальные спрайты, скажет `spec.json`; пока жив стенд — `paths.STAND`.
- Ключи в `runs/verdicts.json` — вида `battle-demo/artifacts/clips/<персонаж>/<анимация>`.
  Это идентификаторы записей, а не пути: переписывать их под новый дом означало
  бы открепить уже вынесенные вердикты.
- Девять A-pose-кадров в `a_pose_v2/` лежат в дереве и не в git — единственный
  экземпляр. Так было и в стенде; что с ними делать (в git, перегенерировать,
  увести в вывод), решается вместе с судьбой стенда (Q-M139).

## Проверка

`python3 scripts/character_kit/test_character_kit.py` — что пакет больше не
смотрит путями в стенд и что приёмка на сломанном входе возвращает `fail` с
причиной. Гоняется в `scripts/doc_gates.sh`.

#!/usr/bin/env python3
"""Программный аудит комплекта кадров (спека `battle-demo-sprites`, задачи фазы 7).

Проверяет по **каждому** файлу комплекта то, что требует спека, и пишет отчёт с
вердиктом на файл и итоговыми счётчиками:

* имя по схеме `char_<side>_<name>_<anim>_<NN>.png` и кадр в каталоге своего
  юнита («Нейминг файлов»);
* PNG с альфа-каналом и размером 512×512 («Техническая форма кадра»);
* кадр не пустой, силуэт не касается края («Персонаж обрезан по краю»);
* в углу нет непрозрачного хромакея («После ункея остался хромакей»);
* кадры не повторяют друг друга побайтово («дубликаты имён, под которые подпали
  разные кадры»);
* комплект полон: у каждого юнита пять дорожек по четыре кадра, лишних файлов нет
  («Полнота комплекта», «Отчёт покрывает все файлы»).

Схема имени, холст и число кадров берутся из `tools/build_sprite_frames.py` —
единственного писателя комплекта, чтобы аудит и сборка не разъехались.

    python3 battle-demo/tools/audit_sprites.py            # код 0 = комплект чист
    python3 battle-demo/tools/audit_sprites.py --report /tmp/a.json

Карантин `priest/hit` (ступни уезжают за цикл, `docs/known-issues.md`) — зеркало
`INCOMPLETE` из `tests/unit/view/test_sprite_tracks.gd`: отсутствующая дорожка из
этого списка не падение, отсутствующая вне списка — падение.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

from PIL import Image

import build_sprite_frames as kit

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets/sprites"
UNITS = ROOT / "data/units"
ANIMS = ("idle", "walk", "attack", "hit", "turn")
INCOMPLETE = {"priest": {"hit"}}
CHROMA = (0, 255, 0)
CHROMA_TOLERANCE = 40

NAME_RE = re.compile(
    r"^char_(player|enemy)_(.+)_(idle|walk|attack|hit|turn)_(\d{2})\.png$"
)


def unit_ids() -> list[str]:
    return sorted(path.stem for path in UNITS.glob("*.tres"))


def expected() -> dict[str, Path]:
    """Имя файла → ожидаемый путь. Карантинные дорожки в ожидание не входят."""
    want = {}
    for id in unit_ids():
        for anim in ANIMS:
            if anim in INCOMPLETE.get(id, ()):
                continue
            for index in range(kit.FRAME_COUNT):
                name = kit.frame_name(id, anim, index)
                want[name] = SPRITES / id / name
    return want


def check_chroma(image: Image.Image) -> str | None:
    """Непрозрачный пиксель хромакея в одном из четырёх углов кадра."""
    width, height = image.size
    for x, y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        r, g, b, a = image.getpixel((x, y))
        if a > 200 and all(abs(v - c) <= CHROMA_TOLERANCE for v, c in ((r, 0), (g, 255), (b, 0))):
            return f"хромакей в углу ({x}, {y}): {(r, g, b, a)}"
    return None


def fill_share(path: Path) -> list[int]:
    """Заполнение кадра альфа-боксом, в процентах: [высота, ширина].

    Мера, а не вердикт: полоса «78–92 % высоты» из `docs/art-bible.md` —
    приёмка, а не SHALL спеки; комплект её пока не попадает (см. ADR-008),
    поэтому число пишется в отчёт, а не в брак.
    """
    image = Image.open(path)
    box = image.getchannel("A").getbbox()
    if not box:
        return [0, 0]
    return [round(100 * (box[3] - box[1]) / image.size[1]),
            round(100 * (box[2] - box[0]) / image.size[0])]


def check_file(path: Path) -> tuple[list[str], str]:
    """(список нарушений, md5 содержимого)."""
    problems: list[str] = []
    digest = hashlib.md5(path.read_bytes()).hexdigest()
    image = Image.open(path)
    if image.mode != "RGBA":
        problems.append(f"нет альфа-канала: режим {image.mode}")
        return problems, digest
    if image.size != (kit.CANVAS, kit.CANVAS):
        problems.append(f"размер {image.size[0]}×{image.size[1]}, надо "
                        f"{kit.CANVAS}×{kit.CANVAS}")
    box = image.getchannel("A").getbbox()
    if box is None:
        problems.append("пустой кадр: альфа нулевая во всех пикселях")
        return problems, digest
    if box[0] == 0 or box[1] == 0 or box[2] >= image.size[0] or box[3] >= image.size[1]:
        problems.append(f"силуэт касается края кадра: bounding box {box}")
    chroma = check_chroma(image)
    if chroma:
        problems.append(chroma)
    return problems, digest


def _summarize(rows: list[dict], want: dict[str, Path]) -> dict:
    present = {row["file"] for row in rows if row["ok"]}
    missing = sorted(str(path.relative_to(SPRITES))
                     for name, path in want.items()
                     if str(path.relative_to(SPRITES)) not in present)
    rejected = [row for row in rows if not row["ok"]]
    heights = [row["fill"][0] for row in rows if row["fill"][0]]
    return {
        "canvas": f"{kit.CANVAS}x{kit.CANVAS}",
        "frames_per_track": kit.FRAME_COUNT,
        "checked": len(rows),
        "accepted": len(rows) - len(rejected),
        "rejected": len(rejected),
        "missing": missing,
        "quarantine": [f"{id}/{anim}" for id, anims in INCOMPLETE.items() for anim in anims],
        "fill_height_pct": {"min": min(heights), "max": max(heights)},
        "files": rows,
    }


def audit() -> dict:
    files = sorted(SPRITES.glob("*/*.png"))
    want = expected()
    rows: list[dict] = []
    by_digest: dict[str, str] = {}

    for path in files:
        problems = []
        match = NAME_RE.match(path.name)
        if not match:
            problems.append("имя вне схемы char_<side>_<name>_<anim>_<NN>.png")
        elif path.name not in want:
            problems.append("файл не входит в ожидаемый комплект (лишний лист, "
                            "анимация или кадр)")
        elif match.group(2) != path.parent.name:
            problems.append(f"кадр юнита {match.group(2)} лежит в каталоге "
                            f"{path.parent.name}")
        found, digest = check_file(path)
        problems += found
        twin = by_digest.get(digest)
        if twin:
            problems.append(f"побайтовый дубликат {twin}")
        elif not problems:
            by_digest[digest] = path.name
        rows.append({"file": str(path.relative_to(SPRITES)),
                     "ok": not problems, "problems": problems,
                     "fill": fill_share(path)})

    return _summarize(rows, want)

    present = {row["file"] for row in rows if row["ok"]}
    missing = sorted(str(path.relative_to(SPRITES))
                     for name, path in want.items()
                     if str(path.relative_to(SPRITES)) not in present)
    rejected = [row for row in rows if not row["ok"]]
    return {
        "canvas": f"{kit.CANVAS}x{kit.CANVAS}",
        "frames_per_track": kit.FRAME_COUNT,
        "checked": len(rows),
        "accepted": len(rows) - len(rejected),
        "rejected": len(rejected),
        "missing": missing,
        "quarantine": [f"{id}/{anim}" for id, anims in INCOMPLETE.items() for anim in anims],
        "files": rows,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", default=str(ROOT / "artifacts/sprite-audit.json"))
    args = parser.parse_args()
    report = audit()
    Path(args.report).write_text(json.dumps(report, ensure_ascii=False, indent=2))
    print(f"аудит кадров: проверено {report['checked']}, принято {report['accepted']}, "
          f"брак {report['rejected']}, отсутствует {len(report['missing'])}")
    for row in report["files"]:
        if not row["ok"]:
            print(f"  брак: {row['file']}: {'; '.join(row['problems'])}", file=sys.stderr)
    for name in report["missing"]:
        print(f"  нет файла: {name}", file=sys.stderr)
    return 0 if not report["missing"] and not report["rejected"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

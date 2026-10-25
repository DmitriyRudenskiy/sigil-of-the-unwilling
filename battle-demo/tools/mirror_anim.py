#!/usr/bin/env python3
"""Анимация **отзеркаленному** персонажу, не трогая принятый комплект.

`gen_clip.py` берёт референс по фиксированному порядку (kit → a_pose → портрет)
и пишет в `artifacts/clips/<char>/<anim>`, где лежат принятые клипы. Чтобы
прогнать зеркальный источник и не перезаписать принятый вердикт, здесь подменяются
три вещи: источник (`upload_portrait`), каталог клипов и реестры вердиктов —
всё в `artifacts/clips-mirror/`. Сам `gen_clip.py` не редактируется.

    python3 tools/mirror_anim.py --char knight --anim idle
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

import comfy
import gen_clip

ROOT = comfy.ROOT / "battle-demo"
MIRROR = ROOT / "artifacts/clips-mirror"


def mirrored(char: str) -> Path:
    """Зеркало нового A-pose: персонаж развёрнут влево (как враг в бою)."""
    src = ROOT / "assets/a_pose_v2" / f"{char}.png"
    if not src.exists():
        raise SystemExit(f"нет {src}")
    out = ROOT / "artifacts/mirror-src" / f"{char}_left.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    Image.open(src).convert("RGB").transpose(Image.FLIP_LEFT_RIGHT).save(out)
    return out


def strip(frames: list[Path], out: Path) -> None:
    w = 300
    tiles = []
    for path in frames:
        im = Image.open(path).convert("RGB")
        tiles.append(im.resize((w, round(im.height * w / im.width)), Image.LANCZOS))
    sheet = Image.new("RGB", (len(tiles) * (w + 8) + 8, tiles[0].height + 26), (25, 25, 25))
    for n, tile in enumerate(tiles):
        sheet.paste(tile, (8 + n * (w + 8), 26))
        ImageDraw.Draw(sheet).text((10 + n * (w + 8), 8), frames[n].name, fill=(230, 230, 230))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--char", required=True)
    parser.add_argument("--anim", default="idle")
    parser.add_argument("--comfy", default="http://192.168.0.230:8188")
    args = parser.parse_args()

    source = mirrored(args.char)
    MIRROR.mkdir(parents=True, exist_ok=True)
    (MIRROR / "clip-manifest.json").write_text("[]")
    (MIRROR / "verdicts.json").write_text("{}")
    gen_clip.CLIPS = MIRROR
    gen_clip.MANIFEST = MIRROR / "clip-manifest.json"
    gen_clip.VERDICTS = MIRROR / "verdicts.json"
    gen_clip.upload_portrait = lambda spec, char, url: comfy.upload(
        url, source, f"sotu-{char}-mirror.png")

    sys.argv = ["gen_clip", "--char", args.char, "--anim", args.anim, "--comfy", args.comfy]
    gen_clip.main()

    out_dir = MIRROR / args.char / args.anim
    frames = sorted(out_dir.glob("sprite_*.png"))
    if not frames:
        raise SystemExit("кадров нет")
    sheet = ROOT / "artifacts/mirror-src" / f"{args.char}_{args.anim}_strip.jpg"
    strip(frames, sheet)
    gif = sheet.with_suffix(".gif")
    big = [Image.open(p).convert("RGB").resize((256, 256), Image.LANCZOS) for p in frames]
    big[0].save(gif, save_all=True, append_images=big[1:], duration=180, loop=0)
    print(json.dumps({"frames": [str(p.relative_to(ROOT.parent)) for p in frames],
                      "strip": str(sheet.relative_to(ROOT.parent)),
                      "gif": str(gif.relative_to(ROOT.parent))}, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())

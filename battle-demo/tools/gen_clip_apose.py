#!/usr/bin/env python3
"""A-pose → 81 кадров без переделки кадра-источника (процесс VIDEO_1.json владельца).

Отличия от принятого конвейера `gen_clip.py`: нет шага 01b (первым кадром лежит
сам A-pose, модель его только оживляет), нет DWPose-скелета, длина 81.
Разрешённые владельцем точки вмешательства — три: входное изображение, промпт,
префикс выхода. Больше в графе ничего не двигается.

Источник — `assets/a_pose_v2/<char>.png` как есть; зеркало включается только для
тех, кто развёрнут влево (глазами по сетке ног и корпуса).
"""
import argparse
import json
import shutil
from pathlib import Path

from PIL import Image, ImageOps

import comfy
import gen_clip as gc

ROOT = comfy.ROOT
WF = "06_apose_i2v_81_frames"
OUT = ROOT / "battle-demo/artifacts/clips-apose"
# Развёрнуты влево → зеркалим источник (владелиц подтвердил на варваре: смотрит
# влево). Критерий — куда смотрит голова, а не куда смотрят носки.
FACES_LEFT = {"barbarian", "wizard", "sorcerer", "stormmage", "priest"}


def source_image(char: str, mirror: bool, out_dir: Path) -> Path:
    path = ROOT / f"battle-demo/assets/a_pose_v2/{char}.png"
    image = Image.open(path).convert("RGB")          # зелёный фон уже в пикселях
    if mirror:
        image = ImageOps.mirror(image)
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / "first_raw.png"
    image.save(target)
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--char", required=True)
    parser.add_argument("--anim", required=True)
    parser.add_argument("--mirror", choices=["auto", "yes", "no"], default="auto")
    parser.add_argument("--prompt", default=None,
                        help="промпт вместо spec.clip_prompt: у зверей он свой "
                             "(`the character ... same weapon` модель доставляет "
                             "оруженосца рядом с волком)")
    parser.add_argument("--length", type=int, default=81, help="кадров клипа, 4n+1")
    parser.add_argument("--frames", type=int, default=4, help="кадров после прорежки")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--comfy", default="http://192.168.0.230:8188")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--reuse", action="store_true",
                        help="взять raw/, что уже лежит, и только пересобрать кадры/вердикт")
    args = parser.parse_args()

    spec = comfy.load_spec()
    seed = args.seed or gc.character_of(spec, args.char)["seed"]
    mirror = args.mirror == "yes" or (args.mirror == "auto" and args.char in FACES_LEFT)
    out_dir = OUT / args.char / args.anim
    raw_dir = out_dir / "raw"

    prompt = args.prompt or spec["clip_prompt"][args.anim]
    graph = gc.load_workflow(WF)
    gc.set_inputs(graph, "6", text=prompt)
    gc.set_inputs(graph, "8", length=args.length, batch_size=1)
    gc.set_inputs(graph, "13", noise_seed=seed)
    gc.set_inputs(graph, "18", filename_prefix=f"sotu/{args.char}-{args.anim}/03_frames/frame")
    if args.dry_run:
        print(f"--- {WF}: узлов {len(graph)}, зеркало={mirror}, seed={seed}")
        print(graph["6"]["inputs"]["text"])
        return 0

    first = source_image(args.char, mirror, out_dir)
    corner = Image.open(first).convert("RGB").getpixel((0, 0))
    raw = sorted(p for p in raw_dir.glob("*") if p.suffix.lower() in gc.IMAGE_SUFFIXES)
    seconds = 0.0
    if not (args.reuse and raw):
        shutil.rmtree(raw_dir, ignore_errors=True)      # старые кадры не должны смешаться
        for stale in (*out_dir.glob("frame_*.png"), *out_dir.glob("sprite_*.png")):
            stale.unlink()
        gc.set_inputs(graph, "5", image=comfy.upload(args.comfy, first,
                                                     f"sotu-{args.char}-{args.anim}-apose.png"))
        images, seconds = gc.run(args.comfy, graph, "06", timeout=3600)
        raw = gc.fetch(args.comfy, images, raw_dir)

    keyed = []
    for index, image in enumerate(gc.register([gc.unkey(path) for path in raw])):
        image.thumbnail((512, 512), Image.LANCZOS)
        target = out_dir / f"frame_{index + 1:02d}.png"
        image.save(target)
        keyed.append(target)

    window = gc.loop_window(keyed, args.frames)[0] if args.anim in gc.LOOP_ANIMS else keyed
    picked = gc.subsample(window, args.frames)
    for index, path in enumerate(picked):
        Image.open(path).save(out_dir / f"sprite_{index + 1:02d}.png")

    report = {"char": args.char, "anim": args.anim, "seed": seed, "mirror": mirror,
              "prompt": prompt,
              "length": args.length, "seconds": round(seconds, 1),
              "corner_before_clip": list(corner),
              "audit": gc.measure(keyed), "subsampled": [str(p) for p in picked]}
    report["verdict"] = gc.verdict(report)
    (out_dir / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=1),
                                         encoding="utf-8")
    print(json.dumps({"verdict": report["verdict"], "seconds": report["seconds"],
                      "frames": len(keyed), "sprites": [str(p.relative_to(ROOT))
                                                        for p in picked]},
                     ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

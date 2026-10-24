#!/usr/bin/env python3
"""A-pose первого кадра (D16): портрет → персонаж в A-pose на хромакее.

Воркфлоу владельца `workflows/00_a_pose_reference.json`: вырезание фона
(`birefnet`) → заливка `#00FF00` → Qwen Image 2.1 edit. **Промпт и сид не
трогаем** (владелец, 2026-10-24): `seed` всегда 43, правка промпта даёт другого
человека вместо персонажа источника.

Только stdlib + PIL. Кадр кладётся в `battle-demo/assets/a_pose/<char>.png`;
наличие файла = шаг сделан (возобновляемость без манифеста).
"""
import argparse
import json
import sys
import time
from pathlib import Path

from PIL import Image

import comfy

HERE = Path(__file__).resolve().parent
WF = HERE / "workflows" / "00_a_pose_reference.json"
A_POSE_DIR = comfy.ROOT / "battle-demo/assets/a_pose"
SEED = 43


def load_graph() -> dict:
    with open(WF, encoding="utf-8") as handle:
        graph = json.load(handle)
    return {nid: {"class_type": n["class_type"], "inputs": n["inputs"]}
            for nid, n in graph.items() if "class_type" in n}


def run_one(comfy_url: str, char: str, out: Path, timeout: int = 1200) -> dict:
    portrait = comfy.ROOT / comfy.load_spec()["portraits_dir"] / f"{char}.png"
    if not portrait.exists():
        raise SystemExit(f"нет портрета {portrait}")
    graph = load_graph()
    graph["11"]["inputs"]["image"] = comfy.upload(comfy_url, portrait, f"sotu-{char}-portrait.png")
    graph["8"]["inputs"]["seed"] = SEED
    graph["10"]["inputs"]["filename_prefix"] = f"sotu-a-pose/{char}"
    started = time.time()
    entry = comfy.wait(comfy_url, comfy.submit(comfy_url, graph), timeout=timeout, interval=5)
    images = comfy.outputs_of(entry)
    if not images:
        raise SystemExit(f"{char}: прогон без изображений")
    comfy.save_output(comfy_url, images[0], out)
    corner = Image.open(out).convert("RGB").getpixel((0, 0))
    box = Image.open(out).convert("RGB").getbbox()
    # Порог — тот же кей, что у `unkey` в gen_clip.py: генерация красит хромакей
    # «почти зелёным» (прогон 2026-10-24: угол (5,231,12)), точное совпадение с
    # (0,255,0) было бы ложным браком.
    keyed = corner[1] - max(corner[0], corner[2]) > 60
    verdict = ("годен" if keyed else
               f"брак: угол кадра {tuple(corner)} не зелёный (g−max(r,b)="
               f"{corner[1] - max(corner[0], corner[2])} ≤ 60) — хромакей не залит")
    report = {"char": char, "seed": SEED, "seconds": round(time.time() - started, 1),
              "size": list(Image.open(out).size), "bbox": list(box) if box else None,
              "corner": list(corner), "verdict": verdict}
    print(f"[{char}] {verdict}; {report['seconds']} с, {report['size'][0]}×{report['size'][1]}",
          flush=True)
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--char", help="один персонаж (id из spec.json)")
    parser.add_argument("--all", action="store_true", help="все персонажи спека")
    parser.add_argument("--force", action="store_true", help="перегенерировать готовые")
    parser.add_argument("--comfy", default="http://192.168.0.230:8188")
    args = parser.parse_args()

    if not (args.char or args.all):
        parser.error("нужны --char или --all")
    spec = comfy.load_spec()
    chars = [c["id"] for c in spec["characters"]] if args.all else [args.char]
    A_POSE_DIR.mkdir(parents=True, exist_ok=True)
    bad = 0
    for char in chars:
        out = A_POSE_DIR / f"{char}.png"
        if out.exists() and not args.force:
            print(f"[skip] {char}: уже есть {out.relative_to(comfy.ROOT)}", flush=True)
            continue
        if not run_one(args.comfy, char, out)["verdict"].startswith("годен"):
            bad += 1
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())

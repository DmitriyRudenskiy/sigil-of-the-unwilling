#!/usr/bin/env python3
"""Собранный кадр персонажа: оружие вырезается и вклеивается моделью (D17).

Цепочка владельца (2026-10-25, `WEAPON_*.json` / `MERGE_WEAPON_*.json`):

1. `04_weapon_extract` — с портрета вырезается **один** предмет на белом фоне
   («Extract ONLY the …, game item card asset»): персонаж, кисти и фон удаляются,
   скрытые руками части рукояти достраиваются.
2. `05_weapon_merge` — предмет с белого фона ставится на A-pose-кадр: модель
   **перерисовывает кисти** в захват, белый фон снимает, зелёный фон кадра,
   лицо, одежду и материалы предмета сохраняет.

Предметов несколько — несколько прогонов подряд, базой второго кадра становится
результат первого (иначе модель склеивает предметы в один). Хромакея в цепочке
нет: предмет живёт на белом, кадр — на зелёном. Позицию, масштаб и захват
задаёт промпт, а не пиксельная раскладка, поэтому `place` из спеки снят.

    python3 gen_kit.py --char knight          # вырезка + склейка
    python3 gen_kit.py --char knight --merge  # только склейка (листы на диске)
    python3 gen_kit.py --all
"""
from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

from PIL import Image

import comfy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
WORKFLOWS = HERE / "workflows"
KIT = ROOT / "battle-demo" / "assets" / "kit"
POSES = ROOT / "battle-demo" / "assets" / "a_pose"
PORTRAITS = ROOT / "battle-demo" / "assets" / "portraits"
SHOTS = ROOT / "tmp" / "shots"
DEFAULT_SEED = 43


def run(graph: dict, server: str, label: str, out: Path) -> Path:
    started = time.time()
    pid = comfy.submit(server, graph)
    entry = comfy.wait(server, pid, timeout=1800)
    images = comfy.outputs_of(entry)
    if not images:
        raise RuntimeError(f"{label}: пустой выход")
    out.parent.mkdir(parents=True, exist_ok=True)
    comfy.save_output(server, images[0], out)
    print(f"[kit ] {label} → {out.name} {Image.open(out).size} "
          f"за {time.time() - started:.0f} c", flush=True)
    return out


def graph(workflow: str, server: str, prompt: str, seed: int, prefix: str,
          images: list[tuple[str, Path]]) -> dict:
    """Собирает граф: картинки грузятся на сервер, промпт вставляется в 7-й узел."""
    spec = json.loads((WORKFLOWS / f"{workflow}.json").read_text(encoding="utf-8"))
    for index, (node, path) in enumerate(images, start=1):
        spec[node]["inputs"]["image"] = comfy.upload(server, path, f"kit-{path.stem}.png")
        spec["7"]["inputs"][f"images.image_{index}"] = [node, 0]
    spec["7"]["inputs"]["prompt"] = prompt
    spec["8"]["inputs"]["seed"] = seed
    spec["10"]["inputs"]["filename_prefix"] = prefix
    return spec


def extract(server: str, char: str, name: str, prompt: str, seed: int) -> Path:
    return run(graph("04_weapon_extract", server, prompt, seed, f"sotu-kit/{char}",
                     [("23", PORTRAITS / f"{char}.png")]),
               server, f"extract {char}/{name}", KIT / f"{char}_{name}.png")


def merge(server: str, char: str, base: Path, sheet: Path, prompt: str,
          seed: int, step: int) -> Path:
    return run(graph("05_weapon_merge", server, prompt, seed, f"sotu-kit/{char}",
                     [("23", base), ("24", sheet)]),
               server, f"merge {char} шаг {step}", KIT / f"{char}_merge{step}.png")


def build(spec: dict, char: str, server: str,
          sheets_only: bool = False, merge_only: bool = False) -> Path:
    """Портрет → листы предметов → A-pose с предметом в руке."""
    kit = spec["kit"][char]
    seed = kit.get("seed", DEFAULT_SEED)
    base = POSES / f"{char}.png"
    if not merge_only:
        for name, item in kit["extract"].items():
            extract(server, char, name, item["prompt"], seed)
        if sheets_only:
            return base
    for step, (name, item) in enumerate(kit["merge"].items(), start=1):
        base = merge(server, char, base, KIT / f"{char}_{name}.png", item["prompt"],
                     seed, step)
    composed = KIT / f"{char}_composed.png"
    composed.parent.mkdir(parents=True, exist_ok=True)
    Image.open(base).convert("RGB").save(composed)
    SHOTS.mkdir(parents=True, exist_ok=True)
    left, right = Image.open(POSES / f"{char}.png"), Image.open(composed)
    right = right.resize((left.width, int(right.height * left.width / right.width)))
    pair = Image.new("RGB", (left.width * 2 + 8, left.height), "#ffffff")
    pair.paste(left.convert("RGB"), (0, 0))
    pair.paste(right, (left.width + 8, 0))
    pair.save(SHOTS / f"kit-{char}.png")
    print(f"[comp] {char} {composed.name} → {SHOTS / f'kit-{char}.png'}", flush=True)
    return composed


def main() -> int:
    global server_
    ap = argparse.ArgumentParser()
    ap.add_argument("--char")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--sheets-only", action="store_true", help="только вырезка листов")
    ap.add_argument("--merge", action="store_true", help="только склейка, листы на диске")
    ap.add_argument("--dry-run", action="store_true", help="собрать графы, сервер не трогать")
    ap.add_argument("--spec", default=str(HERE / "spec.json"))
    args = ap.parse_args()

    spec = comfy.load_spec(args.spec)
    if not args.char and not args.all:
        ap.error("нужно --char <id> либо --all")
    chars = [c for c in spec["kit"] if not c.startswith("_")] if args.all else [args.char]
    for char in chars:
        kit = spec["kit"][char]
        if args.dry_run:
            for name in kit["extract"]:
                print(f"[dry ] {char}/{name} extract {len(kit['extract'][name]['prompt'])} симв.")
            for step, name in enumerate(kit["merge"], start=1):
                print(f"[dry ] {char}/{name} merge шаг {step}")
            continue
        build(spec, char, spec["comfy"], sheets_only=args.sheets_only, merge_only=args.merge)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

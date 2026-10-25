#!/usr/bin/env python3
"""A-pose воркфлоу владельца `A-pose_improved-2.json` — прогон всех персонажей.

Правило владельца (2026-10-25): из графа меняются **только** входной файл
(`LoadImage.image`) и выходной (`SaveImage.filename_prefix`). Промпт, сид 43,
модели, шаги, cfg, `GrowMask`, порядок узлов — как в файле владельца, ни одного
изменения. Поэтому граф читается как есть (litegraph-формат фронтенда) и
перекладывается в API-форму без правок значений: этот файл — сериализатор, а не
редактор.

Выход — `battle-demo/assets/a_pose_v2/<char>.png`. Старый комплект
`assets/a_pose/` не трогается: из него сделаны первые кадры принятых клипов.

    python3 tools/gen_a_pose_v2.py --char knight
    python3 tools/gen_a_pose_v2.py --all
"""
import argparse
import json
import sys
import time
from pathlib import Path

from PIL import Image

import comfy

HERE = Path(__file__).resolve().parent
WORKFLOW = Path("/Users/user/Downloads/A-pose_improved-2.json")
OUT_DIR = comfy.ROOT / "battle-demo/assets/a_pose_v2"
IN_NODE, OUT_NODE = "11", "10"        # LoadImage, SaveImage (владелец их не менял)

# Виджет в /object_info — примитивный тип или список опций; всё остальное — связь.
PRIMITIVE = {"INT", "FLOAT", "STRING", "BOOLEAN", "COMBO", "INT64"}
# Служебный виджет фронтенда за seed'ом; в определении узла его нет, а в
# widgets_values он лежит — без пропуска сдвигались бы steps/cfg/sampler.
CONTROL = {"fixed", "randomize", "increment", "decrement"}


def is_widget(spec) -> bool:
    kind = spec[0]
    if isinstance(kind, list):
        return True
    return str(kind).split("[")[0] in PRIMITIVE


def to_api(graph: dict, defs: dict) -> dict:
    """litegraph (nodes + links) → API-форма {id: {class_type, inputs}}.

    Значения не переопределяются: виджеты расходуются из `widgets_values` по
    порядку виджетов определения узла (связанные виджеты остаются в своей
    ячейке — EmptyImage.width/-height залиты из GetImageSize), связи — из
    `links` по id связи, и они всегда главнее виджета.
    """
    links = {row[0]: row for row in graph["links"] if row}
    api = {}
    for node in graph["nodes"]:
        if node.get("mode", 0) in (2, 4):        # muted / bypass → не в прогоне
            continue
        spec = defs[node["type"]]
        ordered = {}
        ordered.update(spec.get("input", {}).get("required", {}))
        ordered.update(spec.get("input", {}).get("optional", {}))
        values = list(node.get("widgets_values") or [])
        inputs = {}
        for name, widget in ordered.items():
            if not is_widget(widget) or not values:
                continue
            while values and isinstance(values[0], str) and values[0] in CONTROL:
                values.pop(0)
            if values:
                inputs[name] = values.pop(0)
        for slot in node.get("inputs", []):
            if slot.get("link") is not None:
                _, src, src_slot, _, _, _ = links[slot["link"]]
                inputs[slot["name"]] = [str(src), src_slot]
        api[str(node["id"])] = {"class_type": node["type"], "inputs": inputs}
    return api


def free(comfy_url: str) -> None:
    """Сброс VRAM между персонажами: сервер держит UNet+CLIP+birefnet в кэше и на
    втором прогоне падал `torch.OutOfMemoryError` (RTX 4080 SUPER, 16 ГБ, свободных
    5.4). Это уборка сервера, а не правка графа — воркфлоу владельца не тронут."""
    comfy._request(f"{comfy_url}/free", data=json.dumps(
        {"unload_models": True, "free_memory": True}).encode(),
        headers={"Content-Type": "application/json"}, timeout=120)


def run_one(comfy_url: str, char: str, api: dict, out: Path, timeout: int = 1200) -> dict:
    portrait = comfy.ROOT / comfy.load_spec()["portraits_dir"] / f"{char}.png"
    if not portrait.exists():
        raise SystemExit(f"нет портрета {portrait}")
    graph = json.loads(json.dumps(api))
    graph[IN_NODE]["inputs"]["image"] = comfy.upload(
        comfy_url, portrait, f"sotu-{char}-portrait.png")
    graph[OUT_NODE]["inputs"]["filename_prefix"] = f"sotu-a-pose-v2/{char}"
    started = time.time()
    entry = comfy.wait(comfy_url, comfy.submit(comfy_url, graph), timeout=timeout, interval=5)
    images = comfy.outputs_of(entry)
    if not images:
        raise SystemExit(f"{char}: прогон без изображений")
    comfy.save_output(comfy_url, images[0], out)
    size = list(Image.open(out).size)
    print(f"[{char}] {out.relative_to(comfy.ROOT)} · {round(time.time() - started, 1)} с"
          f" · {size[0]}×{size[1]}", flush=True)
    return {"char": char, "seconds": round(time.time() - started, 1), "size": size}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--char", help="один персонаж (id из spec.json)")
    parser.add_argument("--all", action="store_true", help="все персонажи спека")
    parser.add_argument("--force", action="store_true", help="перегенерировать готовые")
    parser.add_argument("--dry-run", action="store_true", help="тогда только API-граф в stdout")
    parser.add_argument("--comfy", default="http://192.168.0.230:8188")
    args = parser.parse_args()

    graph = json.loads(WORKFLOW.read_text(encoding="utf-8"))
    types = sorted({node["type"] for node in graph["nodes"]})
    defs, missing = {}, []
    for node_type in types:
        try:
            defs.update(json.loads(
                comfy._request(f"{args.comfy}/object_info/{node_type}", timeout=60)))
        except Exception:      # noqa: BLE001 - 404 = сервер не знает узла
            missing.append(node_type)
    if missing:
        raise SystemExit(f"ComfyUI не знает узлов {missing} — воркфлоу не пройдёт")
    api = to_api(graph, defs)
    if args.dry_run:
        print(json.dumps(api, ensure_ascii=False, indent=1))
        return 0

    spec = comfy.load_spec()
    chars = [c["id"] for c in spec["characters"]] if args.all else [args.char]
    if not chars:
        parser.error("нужны --char или --all")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for char in chars:
        out = OUT_DIR / f"{char}.png"
        if out.exists() and not args.force:
            print(f"[skip] {char}: уже есть {out.relative_to(comfy.ROOT)}", flush=True)
            continue
        run_one(args.comfy, char, api, out)
        free(args.comfy)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Клип-путь кадров анимации (D15, задачи 6.11–6.15).

Цепочка: 01b первый кадр (идентичность + поза через Union ControlNet) →
02 хромакей `#00FF00` → 03 Wan 2.2 I2V (512×512, length=4n+1) → снятие хромакея
локально (те же пороги, что `04_unkey_frames.json`) → прореживание до N кадров.

Workflow'ы — копия скилла `wan22-i2v-character-clip` (см. `workflows/README.md`).
Только stdlib + PIL.
"""
import argparse
import json
import statistics
import time
from pathlib import Path

from PIL import Image, ImageFilter
import comfy

HERE = Path(__file__).resolve().parent
ROOT = comfy.ROOT
WF = HERE / "workflows"
CLIPS = ROOT / "battle-demo/artifacts/clips"
MANIFEST = ROOT / "battle-demo/artifacts/clip-manifest.json"
GREEN = (0, 255, 0)


def load_workflow(name: str) -> dict:
    with open(WF / f"{name}.json", encoding="utf-8") as handle:
        graph = json.load(handle)
    # API-форма: узлы без внутренностей редактора браузера.
    return {nid: {"class_type": n["class_type"], "inputs": n["inputs"]}
            for nid, n in graph.items() if "class_type" in n}


def set_inputs(graph: dict, node: str, **values) -> None:
    graph[node]["inputs"].update(values)


def run(comfy_url: str, graph: dict, label: str, timeout: int = 1800) -> tuple[list[dict], float]:
    started = time.time()
    prompt_id = comfy.submit(comfy_url, graph)
    entry = comfy.wait(comfy_url, prompt_id, timeout=timeout)
    return comfy.outputs_of(entry), time.time() - started


IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp"}


def fetch(comfy_url: str, images: list[dict], out_dir: Path) -> list[Path]:
    """Скачивает кадры. SaveVideo тоже попадает в outputs — не-картинки пропускаем."""
    return sorted(
        comfy.save_output(comfy_url, image, out_dir / Path(image["filename"]).name)
        for image in images
        if Path(image["filename"]).suffix.lower() in IMAGE_SUFFIXES
    )


def unkey(frame: Path, threshold: int = 60, grow: int = 2) -> Image.Image:
    """Снимает зелёный фон: `g - max(r,b) > threshold` → прозрачный, край разрастается.

    Повторяет `MaskFromColor+ (0,255,0) threshold=60` → `GrowMask expand=2` из
    `04_unkey_frames.json` (там нужен абсолютный путь на сервере, здесь — пиксели).
    """
    image = Image.open(frame).convert("RGB")
    red, green, blue = (channel.load() for channel in image.split())
    width, height = image.size
    mask = Image.new("L", (width, height), 0)
    pixels = mask.load()
    for y in range(height):
        for x in range(width):
            if green[x, y] - max(red[x, y], blue[x, y]) > threshold:
                pixels[x, y] = 255
    if grow:
        mask = mask.filter(ImageFilter.MaxFilter(2 * grow + 1))
    alpha = Image.eval(mask, lambda value: 255 - value)
    image.putalpha(alpha)
    return image


def measure(paths: list[Path]) -> dict:
    """Машинная проверка клипа (6.13 в миниатюре): движение, резкость, pivot, хромакей.

    На входе — кадры **после ункея** (RGBA): альфа даёт силуэт и pivot, RGB — то,
    что не закрыто альфой, то есть зелёный кант внутри силуэта.
    """
    import numpy as np

    frames = [np.asarray(Image.open(path).convert("RGB"), dtype="int16") for path in paths]
    alphas = [Image.open(path).getchannel("A") for path in paths]
    grays = [np.asarray(Image.open(path).convert("L"), dtype="float64") for path in paths]
    sharpness = [
        float(((g[:, 2:] - g[:, :-2])**2).mean() + ((g[2:, :] - g[:-2, :])**2).mean())
        for g in grays
    ]
    # Движение: средний модуль разности первого и последнего кадра (0–255).
    motion = float(abs(frames[0] - frames[-1]).mean())
    # Pivot: низ центра альфы. Дрейф — максимум расхождения по кадрам.
    pivots = []
    for image in alphas:
        box = image.getbbox()
        if box:
            pivots.append(((box[0] + box[2]) / 2, box[3]))
    drift_x = max(p[0] for p in pivots) - min(p[0] for p in pivots) if pivots else 0.0
    drift_y = max(p[1] for p in pivots) - min(p[1] for p in pivots) if pivots else 0.0
    # Хромакей после ункея: сколько зелёного осталось внутри силуэта.
    residue = 0
    for path, alpha in zip(paths, alphas):
        rgb = Image.open(path).convert("RGB")
        kept = alpha.point(lambda v: 255 if v > 200 else 0)
        r, g, b = (np.asarray(channel, dtype="int16") for channel in rgb.split())
        a = np.asarray(kept, dtype="bool")
        residue += int((((g - r > 60) & (g - b > 60)) & a).sum())
    return {
        "frames": len(paths),
        "motion_first_last": round(motion, 1),
        "sharpness_min": round(min(sharpness), 1),
        "sharpness_median": round(statistics.median(sharpness), 1),
        "pivot_drift_x": round(drift_x, 1),
        "pivot_drift_y": round(drift_y, 1),
        "chroma_pixels_kept": residue,
    }


def subsample(paths: list[Path], count: int) -> list[Path]:
    """Равномерная прорежка; для петли ход вперёд и обратно делает 6.14."""
    if count >= len(paths):
        return list(paths)
    step = (len(paths) - 1) / (count - 1)
    return [paths[round(i * step)] for i in range(count)]


def self_test() -> int:
    """Минимальная проверка кеинга и прорежки без сервера (запускается с --self-test)."""
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        frame = Path(tmp) / "f.png"
        Image.new("RGB", (64, 64), GREEN).save(frame)
        image = Image.open(frame).convert("RGB")
        image.paste((20, 30, 40), (24, 24, 40, 40))
        image.save(frame)
        keyed = unkey(frame)
        assert keyed.getpixel((0, 0))[3] == 0, "фон не стал прозрачным"
        assert keyed.getpixel((32, 32))[3] == 255, "фигура стала прозрачной"
        paths = [Path(tmp) / f"{i}.png" for i in range(9)]
        picked = [p.name for p in subsample(paths, 4)]
        assert picked == ["0.png", "3.png", "5.png", "8.png"], picked
        assert len(subsample(paths, 40)) == 9
    print("self-test OK")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--char")
    parser.add_argument("--anim")
    parser.add_argument("--pose", default=None, help="DWPose-скелет позы первого кадра")
    parser.add_argument("--prompt", default=None, help="одно простое действие (D15)")
    parser.add_argument("--length", type=int, default=33, help="кадров клипа, 4n+1")
    parser.add_argument("--frames", type=int, default=4, help="кадров после прорежки")
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--comfy", default="http://192.168.0.230:8188")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--reuse", action="store_true",
                        help="не перегенерировать: взять first_raw/first_chroma/raw/, что уже лежат")
    parser.add_argument("--self-test", action="store_true", help="проверить кеинг и прорежку без сервера")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if not (args.char and args.anim):
        parser.error("нужны --char и --anim")

    spec = comfy.load_spec()
    character = character_of(spec, args.char)
    seed = args.seed or character["seed"]
    if (args.length - 1) % 4:
        parser.error(f"length={args.length} не 4n+1")
    out_dir = CLIPS / args.char / args.anim
    prefix = f"sotu/{args.char}-{args.anim}"

    first_graph = load_workflow("01b_first_frame_pose_controlnet")
    set_inputs(first_graph, "14", image=upload_portrait(spec, args.char, args.comfy))
    set_inputs(first_graph, "5", image=upload_pose(spec, args, args.comfy))
    set_inputs(first_graph, "8", seed=seed)
    set_inputs(first_graph, "10", filename_prefix=f"{prefix}/01_first")

    chroma_graph = load_workflow("02_chromakey_first_frame")
    set_inputs(chroma_graph, "7", filename_prefix=f"{prefix}/02_chroma")

    clip_graph = load_workflow("03_wan22_i2v_512_frames")
    set_inputs(clip_graph, "6", text=args.prompt or spec["clip_prompt"][args.anim])
    set_inputs(clip_graph, "8", length=args.length)
    set_inputs(clip_graph, "13", noise_seed=seed)
    set_inputs(clip_graph, "17", filename_prefix=f"{prefix}/03_video/clip")
    set_inputs(clip_graph, "18", filename_prefix=f"{prefix}/03_frames/frame")

    if args.dry_run:
        for name, graph in (("01b", first_graph), ("02", chroma_graph), ("03", clip_graph)):
            print(f"--- {name}: узлов {len(graph)}")
        print(f"out: {out_dir}")
        return 0

    out_dir.mkdir(parents=True, exist_ok=True)
    timings: dict[str, float] = {}
    first = out_dir / "first_raw.png"
    chroma = out_dir / "first_chroma.png"
    raw_dir = out_dir / "raw"
    reuse = args.reuse

    if not (reuse and first.exists()):
        images, timings["first_frame"] = run(args.comfy, first_graph, "01b")
        comfy.save_output(args.comfy, images[0], first)

    if not (reuse and chroma.exists()):
        set_inputs(chroma_graph, "1", image=comfy.upload(args.comfy, first, f"sotu-{args.char}-{args.anim}-start.png"))
        images, timings["chromakey"] = run(args.comfy, chroma_graph, "02")
        comfy.save_output(args.comfy, images[0], chroma)
    corner = Image.open(chroma).convert("RGB").getpixel((0, 0))

    raw = sorted(path for path in raw_dir.glob("*")
                 if path.suffix.lower() in IMAGE_SUFFIXES) if reuse else []
    if not raw:
        set_inputs(clip_graph, "5", image=comfy.upload(args.comfy, chroma, f"sotu-{args.char}-{args.anim}-chroma.png"))
        images, timings["clip"] = run(args.comfy, clip_graph, "03", timeout=3600)
        raw = fetch(args.comfy, images, raw_dir)

    keyed = []
    for index, path in enumerate(raw):
        image = unkey(path)
        image.thumbnail((512, 512), Image.LANCZOS)
        target = out_dir / f"frame_{index + 1:02d}.png"
        image.save(target)
        keyed.append(target)
    picked = subsample(keyed, args.frames)
    for index, path in enumerate(picked):
        Image.open(path).save(out_dir / f"sprite_{index + 1:02d}.png")

    report = {
        "char": args.char, "anim": args.anim, "seed": seed, "length": args.length,
        "corner_before_clip": list(corner),
        "seconds": {k: round(v, 1) for k, v in timings.items()},
        "total_seconds": round(sum(timings.values()), 1),
        "audit": measure(keyed),
        "subsampled": [str(path.relative_to(ROOT)) for path in picked],
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else []
    manifest = [row for row in manifest
                if not (row["char"] == args.char and row["anim"] == args.anim)]
    manifest.append(report)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0


def character_of(spec: dict, char_id: str) -> dict:
    for character in spec["characters"]:
        if character["id"] == char_id:
            return character
    raise SystemExit(f"персонажа {char_id} нет в spec.json")


def upload_portrait(spec: dict, char: str, comfy_url: str) -> str:
    portrait = ROOT / spec["portraits_dir"] / f"{char}.png"
    if not portrait.exists():
        raise SystemExit(f"нет кадра-источника {portrait}")
    return comfy.upload(comfy_url, portrait, f"sotu-{char}.png")


def upload_pose(spec: dict, args, comfy_url: str) -> str:
    name = args.pose or f"{args.anim}_01.png"
    pose = Path(name)
    if not pose.is_absolute():
        pose = ROOT / spec["poses_dir"] / args.char / name
    if not pose.exists():
        raise SystemExit(f"нет карты позы {pose} — сгенерируй tools/make_pose_maps.py")
    return comfy.upload(comfy_url, pose, f"sotu-pose-{args.char}-{pose.stem}.png")


if __name__ == "__main__":
    raise SystemExit(main())

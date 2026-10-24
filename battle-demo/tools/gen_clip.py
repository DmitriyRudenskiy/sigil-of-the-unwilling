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
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter
import comfy

HERE = Path(__file__).resolve().parent
ROOT = comfy.ROOT
WF = HERE / "workflows"
CLIPS = ROOT / "battle-demo/artifacts/clips"
MANIFEST = ROOT / "battle-demo/artifacts/clip-manifest.json"
VERDICTS = ROOT / "battle-demo/artifacts/verdicts.json"
GREEN = (0, 255, 0)
# Анимации, которые в движке крутятся по кругу (D9): для них ищется стык петли.
LOOP_ANIMS = {"idle", "walk"}
# Походка — не клипом: Wan ведёт персонажа через кадр (снос 31 px за цикл),
# сдвигом кадра это не выпрямляется. Решение владельца 2026-10-24: `walk` —
# покадровый фолбэк D5 (`gen_frames.py`), клипами идут остальные четыре.
PER_FRAME_ANIMS = {"walk"}


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
    # Градиент считаем только внутри силуэта, на 2 px от края: граница силуэта о
    # край кадра — это не резкость, а артефакт кадрирования.
    masks = [np.asarray(alpha.filter(ImageFilter.MinFilter(5)), dtype="float64") / 255
             for alpha in alphas]
    def sharpness(gray, mask):
        """Средний квадрат градиента внутри силуэта (пара пикселей — оба под маской)."""
        total = 0.0
        for a, b, ma, mb in ((gray[:, :-2], gray[:, 2:], mask[:, :-2], mask[:, 2:]),
                             (gray[:-2, :], gray[2:, :], mask[:-2, :], mask[2:, :])):
            keep = ma * mb
            if keep.sum():
                total += float((((b - a) ** 2) * keep).sum() / keep.sum())
        return total

    sharp = [sharpness(gray, mask) for gray, mask in zip(grays, masks)]
    # Движение: средний модуль разности первого и последнего кадра внутри силуэта
    # (0–255); по всему кадру меру съел бы неподвижный фон.
    keep = np.clip(masks[0] + masks[-1], 0.0, 1.0)
    motion = float((abs(frames[0] - frames[-1]) * keep[..., None]).sum() / max(keep.sum() * 3, 1))
    # Дрейф корпуса: разброс центра тяжести **верха** силуэта (голова, плечи) — того,
    # что по полу ездить не должно. Разброс нижне-центра альфа-бокса (ступней) в
    # шаге двигается сам — это и есть анимация, поэтому feet_* только сообщается.
    def body_x(alpha: Image.Image) -> float:
        mask = np.asarray(alpha, dtype="float64")[:max(int(alpha.height * 0.4), 1), :]
        total = mask.sum()
        if not total:
            return 0.0
        return float((np.arange(mask.shape[1]) * mask.sum(axis=0)).sum() / total)

    bodies = [body_x(alpha) for alpha in alphas]
    # За вердикт отвечает снос: насколько уехал корпус за цикл (первый ↔ последний
    # кадр). Размах по всем кадрам — часть шага (корпус качается), он только
    # сообщается. Порог на размахе валил честный walk: прогон 2026-10-24 показал
    # качание 11 px при сносе 0.
    slide_x = abs(bodies[-1] - bodies[0]) if bodies else 0.0
    sway_x = max(bodies) - min(bodies) if bodies else 0.0
    pivots = []
    for image in alphas:
        box = image.getbbox()
        if box:
            pivots.append(((box[0] + box[2]) / 2, box[3]))
    drift_x = max(p[0] for p in pivots) - min(p[0] for p in pivots) if pivots else 0.0
    drift_y = max(p[1] for p in pivots) - min(p[1] for p in pivots) if pivots else 0.0
    # Хромакей после ункея: сколько зелёного осталось в удержанных пикселях.
    # Порог — не «чистый зелёный», а «зелёный перевешивает оба других канала на 25»:
    # спил на ботинках рыцаря (прогон 2026-10-24, кадры 16 и 24) — бледно-зелёный,
    # правило «g-r > 60» его не видело и вердикт врал.
    residue = 0
    kept_total = 0
    for path, alpha in zip(paths, alphas):
        rgb = Image.open(path).convert("RGB")
        kept = alpha.point(lambda v: 255 if v > 20 else 0)
        r, g, b = (np.asarray(channel, dtype="int16") for channel in rgb.split())
        a = np.asarray(kept, dtype="bool")
        residue += int((((g - np.maximum(r, b)) > 25) & a).sum())
        kept_total += int(a.sum())
    return {
        "frames": len(paths),
        "motion_first_last": round(motion, 1),
        "sharpness_min": round(min(sharp), 1),
        "sharpness_median": round(statistics.median(sharp), 1),
        "pivot_slide_x": round(slide_x, 1),
        "pivot_sway_x": round(sway_x, 1),
        "feet_drift_x": round(max(p[0] for p in pivots) - min(p[0] for p in pivots), 1)
        if pivots else 0.0,
        "feet_drift_y": round(max(p[1] for p in pivots) - min(p[1] for p in pivots), 1)
        if pivots else 0.0,
        "chroma_pixels_kept": residue,
        # Доля зелёного в удержанных пикселях: силуэты кадров разного размера,
        # поэтому порог — доля, а не число пикселей.
        "chroma_share": round(residue / max(kept_total, 1), 6),
    }


def register(images: list[Image.Image]) -> list[Image.Image]:
    """Сводит кадры клипа по X к первому кадру (6.14).

    Wan держит позу, но не привязку к полу: в `walk` корпус уехал на 31 px
    (known-issues 5). Якорь — максимум взаимной корреляции профилей столбцов
    альфы (целочисленный сдвиг, при котором силуэт кадра лучше всего налаживается
    на первый). Центр тяжести силуэта для этого не годится: на прогоне 2026-10-24
    он снял из 31 px только 8. По Y не трогаем: покачивание и есть анимация.
    """
    import numpy as np

    def profile(image: Image.Image):
        mask = np.asarray(image.getchannel("A"), dtype="float64")
        # Только верх силуэта (голова и плечи): в шаге ноги ездят, корпус — нет.
        profile = mask[:max(int(image.height * 0.4), 1), :].sum(axis=0)
        return profile - profile.mean()

    reference = profile(images[0])
    spectrum = np.fft.rfft(reference)
    aligned = []
    for image in images:
        current = profile(image)
        correlation = np.fft.irfft(np.fft.rfft(current) * np.conj(spectrum), n=image.width)
        peak = int(np.argmax(correlation))
        # Пик на k означает «кадр = первый кадр, сдвинутый вправо на k» → на место
        # его ставит сдвиг -k.
        shift = peak - image.width if peak > image.width // 2 else peak
        shift = -shift
        if not shift:
            aligned.append(image)
            continue
        canvas = Image.new("RGBA", image.size, (0, 0, 0, 0))
        canvas.paste(image, (shift, 0), image)
        aligned.append(canvas)
    return aligned


def loop_window(paths: list[Path], count: int) -> tuple[list[Path], dict]:
    """Окно клипа под петлю: последний кадр — ближайший по позе к первому (6.14).

    Если стык не найден (последний кадр всё равно далёк от первого), петля
    собирается в движке как `ping-pong` (D9) — об этом говорит флаг `ping_pong`.
    """
    import numpy as np

    small = [np.asarray(Image.open(path).convert("L").resize((128, 128), Image.LANCZOS),
                        dtype="int16") for path in paths]

    def distance(a, b) -> float:
        return float(abs(a - b).mean())

    seam_of = {k: distance(small[0], small[k]) for k in range(len(paths) // 2, len(paths))}
    best = min(seam_of, key=seam_of.get)
    typical = statistics.median(
        [distance(small[i], small[min(i + count, len(small) - 1)])
         for i in range(0, len(small) - 1, count)] or [1.0]) or 1.0
    seam = seam_of[best]
    return paths[:best + 1], {
        "window": best + 1,
        "seam": round(seam, 2),
        "frame_step": round(typical, 2),
        "ping_pong": bool(seam > 1.5 * typical),
    }


def subsample(paths: list[Path], count: int) -> list[Path]:
    """Равномерная прорежка; для петли ход вперёд и обратно делает 6.14."""
    if count >= len(paths):
        return list(paths)
    step = (len(paths) - 1) / (count - 1)
    return [paths[round(i * step)] for i in range(count)]


def verdict(report: dict) -> str:
    """Машинная проверка клипа (6.13) — до просмотра. Пороги по замерам 6.11."""
    audit = report["audit"]
    faults = []
    if tuple(report["corner_before_clip"]) != GREEN:
        faults.append("хромакей не залит: угол первого кадра не (0,255,0)")
    if audit["motion_first_last"] < 2.0:
        faults.append("анимация не двинулась")
    if audit["sharpness_min"] < 0.7 * audit["sharpness_median"]:
        faults.append("есть смазанные кадры")
    if audit["pivot_slide_x"] > 8:
        faults.append(f"корпус уехал по полу ({audit['pivot_slide_x']} px за цикл)")
    if audit["chroma_share"] > 0.0005:
        faults.append(f"остался хромакей ({audit['chroma_pixels_kept']} px, "
                      f"{audit['chroma_share'] * 100:.3f}% удержанных пикселей)")
    if faults:
        return "брак: " + "; ".join(faults)
    loop = report.get("loop")
    seam = "" if not loop else (
        " — петля ping-pong (стык не найден)" if loop["ping_pong"]
        else f" — петля замыкается (стык {loop['seam']} при шаге {loop['frame_step']})")
    return (f"годен: движение {audit['motion_first_last']}, резкость "
            f"{audit['sharpness_min']}/{audit['sharpness_median']}, снос "
            f"{audit['pivot_slide_x']} px, хромакей {audit['chroma_pixels_kept']}{seam}")


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

        # Сведение по X: кадр, сдвинутый на 7 px, обязан вернуться на место.
        figure = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        ImageDraw.Draw(figure).rectangle((20, 10, 30, 50), fill=(9, 9, 9, 255))
        moved = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        moved.paste(figure, (7, 0), figure)
        aligned = register([figure, moved])
        boxes = [image.getchannel("A").getbbox() for image in aligned]
        assert boxes[0][0] == boxes[1][0], f"сведение не сработало: {boxes}"
    print("self-test OK")
    return 0


def batch(args: argparse.Namespace) -> int:
    """Пакетный режим 6.12: все клипы из spec.json, уже годные не трогаем.

    Каждый клип — отдельным процессом этого же файла: сбой одного клипа (таймаут
    сервера, неудачный seed) не роняет двухчасовую очередь, а возобновление —
    это повторный запуск: манифест помнит, что уже принято.

    Ось перебора — персонажи × анимации: `clip_prompt` в спеке ключуется
    анимацией, а не персонажом (первая версия пакета перепутала их местами и
    наслала бы `--char idle --anim t`).
    """
    spec = comfy.load_spec()
    accepted = set()
    if MANIFEST.exists():
        accepted = {(row["char"], row["anim"])
                    for row in json.loads(MANIFEST.read_text())
                    if row.get("verdict", "").startswith("годен")}
    ok = skipped = failed = 0
    queue = [(character["id"], anim) for character in spec["characters"]
             for anim in spec["clip_prompt"]]
    for char, anim in queue:
        if anim in PER_FRAME_ANIMS:
            print(f"[skip] {char}/{anim}: покадрово, D5 (походка клипом не собирается)",
                  flush=True)
            skipped += 1
            continue
        if (char, anim) in accepted:
            print(f"[skip] {char}/{anim}: уже годен", flush=True)
            skipped += 1
            continue
        if args.dry_run:
            print(f"[dry ] {char}/{anim}", flush=True)
            continue
        command = [sys.executable, str(Path(__file__).resolve()),
                   "--char", char, "--anim", anim, "--comfy", args.comfy]
        print(f"[run ] {char}/{anim}", flush=True)
        if subprocess.run(command, check=False).returncode == 0:
            ok += 1
        else:
            failed += 1
    print(f"ИТОГ ok={ok} skip={skipped} fail={failed}", flush=True)
    return 0 if not failed else 1


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
    parser.add_argument("--all", action="store_true",
                        help="пакетный режим: все клипы из spec.json, пропуская уже годные (6.12)")
    parser.add_argument("--self-test", action="store_true", help="проверить кеинг и прорежку без сервера")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if args.all:
        return batch(args)
    if not (args.char and args.anim):
        parser.error("нужны --char и --anim (или --all)")

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
        shutil.rmtree(raw_dir, ignore_errors=True)
        set_inputs(clip_graph, "5", image=comfy.upload(args.comfy, chroma, f"sotu-{args.char}-{args.anim}-chroma.png"))
        images, timings["clip"] = run(args.comfy, clip_graph, "03", timeout=3600)
        raw = fetch(args.comfy, images, raw_dir)

    keyed_images = register([unkey(path) for path in raw])
    keyed = []
    for index, image in enumerate(keyed_images):
        image.thumbnail((512, 512), Image.LANCZOS)
        target = out_dir / f"frame_{index + 1:02d}.png"
        image.save(target)
        keyed.append(target)
    window = keyed
    loop = None
    if args.anim in LOOP_ANIMS and len(keyed) > args.frames:
        window, loop = loop_window(keyed, args.frames)
    picked = subsample(window, args.frames)
    for index, path in enumerate(picked):
        Image.open(path).save(out_dir / f"sprite_{index + 1:02d}.png")

    report = {
        "char": args.char, "anim": args.anim, "seed": seed, "length": args.length,
        "corner_before_clip": list(corner),
        "seconds": {k: round(v, 1) for k, v in timings.items()},
        "total_seconds": round(sum(timings.values()), 1),
        "audit": measure(keyed),
        "loop": loop,
        "subsampled": [str(path.relative_to(ROOT)) for path in picked],
    }
    report["verdict"] = verdict(report)
    print(json.dumps(report, ensure_ascii=False, indent=2))

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else []
    manifest = [row for row in manifest
                if not (row["char"] == args.char and row["anim"] == args.anim)]
    manifest.append(report)
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    verdicts = json.loads(VERDICTS.read_text(encoding="utf-8")) if VERDICTS.exists() else {}
    verdicts[f"battle-demo/artifacts/clips/{args.char}/{args.anim}"] = report["verdict"]
    VERDICTS.write_text(json.dumps(verdicts, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
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

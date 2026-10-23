#!/usr/bin/env python3
"""Поиск объектов по текстовому запросу во всём дереве картинок и листы 3×3.

Стадии разделены: между ними порог смотрит человек, а векторизация — самый
дорогой шаг, пересобирать её из-за порога незачем.

    --stage scan      CLIP по всему дереву: есть ли на кадре объект
                      -> scan.npz, candidates.json
    --stage crop      кроп объектов -> crops/ (см. --method)
    --stage cropscore тот же CLIP по кропам, ниже порога -> rejected/

Листы собирает `run.py --no-books --input <out>/crops` — он умеет и уникальность,
и отчёт, и `check.py`, дублировать его здесь не зачем.

Память. Машине 17 ГБ, на ней же живут чужие сессии; прогон с SAM 3.1 на MPS
уже ронял машину в перезагрузку. Поэтому: CLIP по умолчанию на `cpu`, любое
изображение перед обработкой ужимается до `--max-side`, тяжёлый детектор
опционален, а старт запрещён при свободной памяти ниже `--min-free`.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, "/Users/user/PycharmProjects/_research/image-clone/scripts")

import embed as V  # noqa: E402

EXT = {".png", ".jpg", ".jpeg", ".webp"}
MAX_SIDE = 1024          # потолок стороны на время обработки: 1024² × 3 байта ≈ 3 МБ
# Вопрос не «это картина здания», а «есть ли на кадре здание»: иначе стиль
# иконки (тёмный фон, рамка) перекрывает содержание — замок из `split` набирал
# 0.008 против 0.31 у огня.
POS = {
    "building": ["building", "house", "cottage", "castle", "tower", "fortress",
                 "hut", "barn", "cathedral", "windmill", "stone walls and gates"],
}
# «интерфейс» оставлен намеренно: скриншоты градостроителей напичканы домиками,
# но источником ассетов они не являются
NEG = {
    "building": ["fantasy creature", "person", "weapon", "plant", "bowl of food",
                 "open fire", "magic spell effect", "written text", "a user interface",
                 "empty landscape without any buildings"],
}


def free_mem_pct():
    out = subprocess.run(["memory_pressure", "-Q"], capture_output=True, text=True).stdout
    m = re.search(r"free percentage: (\d+)", out)
    return int(m.group(1)) if m else 100


def images(root):
    """Изображения дерева, по одному на md5 (в пуле 172 группы полных копий)."""
    Image.MAX_IMAGE_PIXELS = None
    seen, out = set(), []
    for p in sorted(Path(root).rglob("*")):
        if p.suffix.lower() not in EXT or p.name.startswith("."):
            continue
        try:
            h = hashlib.md5(p.read_bytes()).hexdigest()
        except OSError:
            continue
        if h not in seen:
            seen.add(h)
            out.append(p)
    return out


def open_small(p, side=MAX_SIDE):
    """RGB/RGBA не крупнее `side`: декод JPEG сразу в масштабе, потом thumbnail."""
    im = Image.open(p)
    alpha = im.mode in ("RGBA", "LA", "PA") or "transparency" in im.info
    if hasattr(im, "draft"):
        im.draft(None, (side, side))
    im = im.convert("RGBA" if alpha else "RGB")
    if max(im.size) > side:
        im.thumbnail((side, side), Image.BILINEAR)
    return im


def score_frames(paths, query, device="cpu", batch=32):
    """-> P(объект) на кадр: softmax по позитивным/негативным подсказкам CLIP."""
    import torch
    import transformers
    torch.set_num_threads(max(1, (os_cpu_count() - 1) if device == "cpu" else 8))
    model = transformers.CLIPModel.from_pretrained(V.MODEL).to(device).eval()
    pr = transformers.CLIPProcessor.from_pretrained(V.MODEL)
    lines = [f"a painting of a {x}" for x in POS[query] + NEG[query]]
    npos = len(POS[query])
    with torch.no_grad():
        t = model.get_text_features(**pr(text=lines, padding=True, return_tensors="pt").to(device))
        if not isinstance(t, torch.Tensor):
            t = t.pooler_output
        T = t / t.norm(p=2, dim=-1, keepdim=True)
        out = []
        for i in range(0, len(paths), batch):
            imgs = [open_small(p, 448).convert("RGB") for p in paths[i:i + batch]]
            f = model.get_image_features(**pr(images=imgs, return_tensors="pt").to(device))
            if not isinstance(f, torch.Tensor):
                f = f.pooler_output
            f = f / f.norm(p=2, dim=-1, keepdim=True)
            out.append(((100 * f @ T.T).softmax(-1)[:, :npos].sum(-1)).float().cpu().numpy())
            n = min(i + batch, len(paths))
            if n % (batch * 25) == 0 or n == len(paths):
                print(f"  scan {n}/{len(paths)} · свободно {free_mem_pct()}%", flush=True)
    return np.concatenate(out).astype(np.float32)


def os_cpu_count():
    import os
    return os.cpu_count() or 4


def stage_scan(args):
    files = images(args.root)
    print(f"файлов (после md5-дедупа): {len(files)} · свободно {free_mem_pct()}%")
    p = score_frames(files, args.query, args.device)
    np.savez_compressed(args.out / "scan.npz", p=p, names=np.array([str(x) for x in files]))
    keep = [str(f) for f, s in zip(files, p) if s >= args.min_score]
    (args.out / "candidates.json").write_text(json.dumps(keep, ensure_ascii=False, indent=1))
    q = np.percentile(p, [50, 90, 99])
    print(f"P({args.query}): медиана {q[0]:.3f} · 90% {q[1]:.3f} · 99% {q[2]:.3f} · "
          f"порог {args.min_score} → кандидатов {len(keep)}")


def objects(im, min_frac=0.02, max_n=3, atlas_min=8):
    """Квадраты объектов на однотонном фоне: порог по цвету рамки + связные компоненты.

    -> (список боксов в пикселях `im`, доля переднего плана, метка компонент для
    маски или None). Боксов нет -> [] ; фона нет (фото, скриншот) -> ([], frac, None)
    при frac > 0.9.

    Атлас (спрайт-шит: >= `atlas_min` отдельных кусков) режется по сырым
    компонентам — с дилейтом соседние спрайты склеиваются в один бокс.
    """
    from scipy import ndimage
    a = np.asarray(im.convert("RGB"), dtype=np.int16)
    if im.mode == "RGBA":
        fg = np.asarray(im)[:, :, 3] > 16
    else:
        border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
        fg = np.abs(a - np.median(border, axis=0)).sum(-1) > 40
    fg = ndimage.binary_opening(fg, np.ones((3, 3)))
    frac = float(fg.mean())
    if not 0.005 <= frac <= 0.9:
        return [], frac, None
    raw, _ = ndimage.label(fg, structure=np.ones((3, 3)))
    sizes = np.bincount(raw.ravel())[1:]
    floor = 0.002 * fg.sum()
    if sizes.size and np.count_nonzero(sizes >= floor) >= atlas_min:
        return _boxes(raw, sizes, max_n, floor, min_side=12), frac, raw
    lab, n = ndimage.label(ndimage.binary_dilation(fg, np.ones((3, 3)), iterations=2),
                           structure=np.ones((3, 3)))
    return _boxes(lab, np.bincount(lab.ravel())[1:], max_n, min_frac * fg.sum()), frac, None


def _boxes(lab, sizes, max_n, min_area, min_side=0):
    """Боксы компонент по убыванию площади: не больше `max_n`, мельче `min_area` не берём.

    Шестой элемент — номер компоненты в `lab`, нужен `tile()` чтобы вырезать
    объект маской и не утащить соседа при расширении в квадрат.
    """
    out = []
    for i, area in sorted(enumerate(sizes, 1), key=lambda x: -x[1]):
        if area < min_area or len(out) >= max_n:
            break
        ys, xs = np.nonzero(lab == i)
        if min(xs.max() - xs.min(), ys.max() - ys.min()) < min_side:
            continue
        out.append([int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1,
                    int(area), i])
    return out


def tile(im, lab, box, size=512, bg=(255, 255, 255)):
    """Квадрат объекта: с маской (`lab`) — только пиксели своей компоненты на фоне `bg`,
    без неё — просто квадрат кадра. Маска и лечит подтаскивание соседей: квадрат
    шире бокса, а чужие спрайты в него не попадают."""
    import detect as D
    l, t, r, b = D.square(box, *im.size)[:4]
    crop = im.crop((l, t, r, b)).convert("RGB")
    if lab is not None:
        m = Image.fromarray((lab[t:b, l:r] == box[5]).astype("uint8") * 255)
        crop = Image.composite(crop, Image.new("RGB", crop.size, bg),
                               m.resize(crop.size, Image.NEAREST))
    return crop.resize((size, size), Image.LANCZOS)


def stage_crop(args):
    """Кропы объектов в out/crops. Метод `trim` — фон+компоненты (CPU), `sam` — SAM 3.1."""
    import detect as D
    cand = [Path(x) for x in json.loads((args.out / "candidates.json").read_text())]
    if args.exclude:
        skip = args.exclude.split(",")
        dropped = [c for c in cand if any(s in str(c) for s in skip)]
        cand = [c for c in cand if not any(s in str(c) for s in skip)]
        print(f"исключено по --exclude {skip}: {len(dropped)} кадров")
    crops = args.out / "crops"
    crops.mkdir(exist_ok=True)
    predict = D.client("mps") if args.method == "sam" else None
    stats = {"кропов": 0, "без фона": 0, "без объекта": 0}
    for i, p in enumerate(cand):
        try:
            im = open_small(p)
        except Exception as e:                       # битый/неподдерживаемый файл
            print(f"  [{i + 1}/{len(cand)}] ПРОПУСК {p.name}: {e}", flush=True)
            continue
        if predict is not None:
            w, h = im.size
            boxes = sorted((D._bbox(m) for m in predict(im.convert("RGB"), args.query)
                            if m.sum() >= args.min_frac * w * h), key=lambda b: -b[4])
            uniq = []
            for b in boxes:
                if all(not _same(b, u) for u in uniq):
                    uniq.append(b)
            frac, lab = 1.0, None
        else:
            uniq, frac, lab = objects(im, args.min_frac, args.max_per_frame)
        if not uniq:
            stats["без фона" if frac > 0.9 else "без объекта"] += 1
            uniq = [[0, 0, im.size[0], im.size[1], 1]]      # объект = весь кадр
            lab = None
        for k, b in enumerate(uniq[:args.max_per_frame]):
            tile(im, lab, b).convert("RGB").save(
                crops / f"{i:04d}_{p.stem[:24].replace(' ', '_')}_{k}.png")
            stats["кропов"] += 1
        im.close()
        if (i + 1) % 25 == 0 or i + 1 == len(cand):
            print(f"  crop {i + 1}/{len(cand)} · {stats} · свободно {free_mem_pct()}%", flush=True)
    print(f"итого: {stats}")


def stage_cropscore(args):
    """Тот же CLIP по готовым кропам: `--min-score` ниже порога -> out/rejected/."""
    paths = sorted(p for p in (args.out / "crops").iterdir() if p.suffix.lower() in EXT)
    p = score_frames(paths, args.query, args.device)
    rej = args.out / "rejected"
    rej.mkdir(exist_ok=True)
    (args.out / "crop_scores.json").write_text(json.dumps(
        {n.name: round(float(s), 4) for n, s in zip(paths, p)}, indent=1))
    moved = 0
    for n, s in zip(paths, p):
        if s < args.min_score:
            n.rename(rej / n.name)
            moved += 1
    print(f"кропов {len(paths)} · медиана {np.median(p):.3f} · порог {args.min_score} · "
          f"отложено {moved}")


def _same(a, b):
    """Один ли это объект: пересечение боксов или вложенность (крыша внутри дома)."""
    x = max(0, min(a[2], b[2]) - max(a[0], b[0]))
    y = max(0, min(a[3], b[3]) - max(a[1], b[1]))
    inter = x * y
    aa, ab = (a[2] - a[0]) * (a[3] - a[1]), (b[2] - b[0]) * (b[3] - b[1])
    ua = aa + ab - inter
    return (inter / ua if ua else 0) > 0.5 or (inter / min(aa, ab) if min(aa, ab) else 0) > 0.7


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--input", type=Path)
    ap.add_argument("--root", type=Path,
                    default=Path("/Users/user/sigil-of-the-unwilling-slop"),
                    help="дерево с кадрами для --stage scan")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--query", default="building", choices=sorted(POS))
    ap.add_argument("--stage", choices=["scan", "crop", "cropscore"], required=True)
    ap.add_argument("--min-score", type=float, default=0.5)
    ap.add_argument("--min-frac", type=float, default=0.02,
                    help="минимальная доля объекта (доля кадра для --method sam, "
                         "доля переднего плана для trim)")
    ap.add_argument("--max-per-frame", type=int, default=3, help="не больше N объектов с кадра")
    ap.add_argument("--method", choices=["trim", "sam"], default="trim")
    ap.add_argument("--device", default="cpu", help="CLIP: cpu (по умолчанию) или mps")
    ap.add_argument("--min-free", type=int, default=25, help="% свободной памяти для старта")
    ap.add_argument("--exclude", default="", help="подстроки пути, чьи кадры не кроить")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    free = free_mem_pct()
    if free < args.min_free and not args.force:
        sys.exit(f"свободно {free}% памяти — ниже порога {args.min_free}%. "
                 f"Прогон на 17 ГБ машине может её уронить; ждём или --force.")
    args.out.mkdir(parents=True, exist_ok=True)
    {"scan": stage_scan, "crop": stage_crop, "cropscore": stage_cropscore}[args.stage](args)


def selfcheck():
    """Геометрия дедупа масок и кроля по фону: `python3 scan.py` без аргументов."""
    from PIL import ImageDraw
    a = [0, 0, 100, 100, 1]
    assert _same(a, [10, 0, 110, 100, 1]) and _same(a, [20, 20, 60, 60, 1])
    assert not _same(a, [200, 0, 300, 100, 1]) and not _same(a, [60, 0, 200, 100, 1])
    # дом на белом фоне -> один бокс по объекту, фон не попал
    im = Image.new("RGB", (200, 200), "white")
    ImageDraw.Draw(im).rectangle([40, 60, 120, 150], fill=(120, 60, 30))
    boxes, frac, _ = objects(im)
    assert len(boxes) == 1 and abs(frac - 0.18) < 0.03, (boxes, frac)
    assert all(abs(x - y) <= 3 for x, y in zip(boxes[0][:4], [40, 60, 121, 151])), boxes[0]
    # два объекта -> два бокса, порядок по площади
    ImageDraw.Draw(im).rectangle([150, 20, 190, 60], fill=(10, 90, 40))
    assert len(objects(im)[0]) == 2, objects(im)[0]
    # атлас 3x3 широких плашек: квадрат тянется на соседа, маска обязана отсечь
    from PIL import ImageDraw as _D
    at = Image.new("RGB", (200, 200), "white")
    d = _D.Draw(at)
    for r in range(3):
        for c in range(3):
            col = (60, 40, 90) if (r + c) % 2 == 0 else (200, 30, 30)
            d.rectangle([10 + c * 70, 10 + r * 40, 70 + c * 70, 30 + r * 40], fill=col)
    boxes, frac, lab = objects(at, max_n=40, atlas_min=3)
    assert len(boxes) == 9 and len(objects(at, max_n=4, atlas_min=3)[0]) == 4, len(boxes)
    a = np.asarray(tile(at, lab, boxes[0], size=200))
    near = lambda c: int((np.abs(a - np.array(c)).sum(-1) < 90).sum())
    assert near((60, 40, 90)) > 5000 and near((200, 30, 30)) == 0, (near((60, 40, 90)), near((200, 30, 30)))
    # пёстрый кадр без фона -> «не кроить»
    assert objects(Image.new("RGB", (200, 200), (90, 30, 200)))[0] == []
    print("ok")


if __name__ == "__main__":
    selfcheck() if len(sys.argv) == 1 else main()

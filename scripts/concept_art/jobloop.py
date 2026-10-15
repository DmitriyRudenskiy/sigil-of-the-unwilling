#!/usr/bin/env python3
"""Лаборатория image-clone: один образец за раз — анализ, промт, генерация, сверка, вердикт.

    jobloop.py init [--src КАТАЛОГ_ЛИСТОВ]  нарезать ячейки листов, завести очередь и оправу
    jobloop.py next [--model krea2]         взять первый in-queue, сгенерировать, собрать пару
    jobloop.py score IMG-001 comp=8 subject=5 palette=9 ...
    jobloop.py accept IMG-001 [--note ...]  готовность >= 85 -> копия в matches/
    jobloop.py reject IMG-001 ["новое описание"] [--note "что не так"]
    jobloop.py model IMG-001 qwen21         сменить модель, счётчик версий начинается с v1
    jobloop.py subject IMG-001 "описание"   записать письменный анализ до генерации
    jobloop.py stat                         статусы + сводка «модель -> средний % / попытки»

Критерии сверки (0-10, неприменимый не указывать — он выпадает из знаменателя):
comp кадрирование, subject главный объект, objects состав объектов, palette палитра,
style техника, light свет, bg фон, camera ракурс, text надписи.
"""
import argparse
import json
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]

LAB = ROOT / "image-clone"
REFS = LAB / "references"
CROPS = REFS / "crops"
ATTEMPTS = LAB / "attempts"
MATCHES = LAB / "matches"
DOCS = LAB / "docs"
QUEUE = LAB / "queue.json"
SPEC = LAB / "spec.json"
PAIRS = LAB / "pairs"
SHEETS_SRC = Path("/Users/user/sigil-of-the-unwilling-slop/___STYLE_BOOK/for_local_agent/unit")

GRID = (4, 3)                   # колонок, строк на листе
SIZE = [512, 512]               # размер прогона лаборатории
MAX_ATTEMPTS = 5
READINESS_MIN = 85
MODEL_DEFAULT = "krea2"
CRITERIA = ("comp", "subject", "objects", "palette", "style", "light", "bg", "camera", "text")
OUT_DIR = "concept_art/clone"

# Стиль листа: семейство держит категория, вариант двигает только технику рендера.
SHEET_STYLE = {
    "unit-01": "stylized hand-painted fantasy game character illustration from a single comic-painted art bible, heroic stocky proportions: head about one sixth of the total height, broad shoulders, thick arms, compact build, mature stylized cartoon face with simplified exaggerated features, large readable eyes, bold expression, hand-painted, never a photograph, matte painterly surfaces with soft airbrushed shading",
    "unit-02": "stylized hand-painted fantasy game character illustration from a single comic-painted art bible, more graphic and crisp than painterly: clean planes of colour, polished metal with sharp speculars, saturated palette, heroic stocky proportions with a head about one sixth of the total height, mature stylized cartoon face with simplified exaggerated features, bold expression, hand-painted, never a photograph",
    "unit-03": "semi-realistic painterly fantasy game character illustration, adult heroic proportions with a head about one seventh of the total height, soft visible brush strokes over rendered planes, restrained palette, mature stylized face with simplified exaggerated features, hand-painted, never a photograph",
    "unit-04": "cartoonish comic fantasy game character illustration, exaggerated proportions with a head about one fifth of the total height, round barrel chest, strong rim light, bold simplified shapes, large readable eyes, cheeky bold expression, hand-painted, never a photograph",
    "unit-05": "stylized hand-painted fantasy game character illustration from a single comic-painted art bible, heroic stocky proportions: head about one sixth of the total height, broad shoulders, thick arms, compact build, mature stylized cartoon face with simplified exaggerated features, large readable eyes, bold expression, hand-painted, never a photograph, matte painterly surfaces with soft airbrushed shading",
}
FRAME = ("single full-body fantasy character standing exactly as described, entire figure visible "
         "from head to boots, whole object with a clear empty margin around it, nothing touching "
         "the frame, centered, front view facing the camera straight on, head up and eyes open "
         "looking at the viewer, isolated on plain white background with no scenery and no blurred "
         "shapes, soft grey contact shadow under the feet only, no second copy, no turnaround, "
         "no grey clay 3d render, no inset pictures, nothing in the corners")
VARIANT = {
    "id": "copy", "name": "copy",
    "style": ("smooth airbrushed painterly rendering without visible line, matte hand-painted "
              "materials, gentle ambient occlusion, low gloss, readable silhouette"),
    "negative": ("chibi, toddler proportions, baby face, doll face, toy figure, blind box vinyl, "
                 "clay render, glossy plastic, shiny enamel, 3d print, cute child, photorealism, "
                 "photograph, ink outlines, line art, sketch, grayscale, character sheet, "
                 "turnaround, multiple views, reference sheet, split frame, collage, two characters, "
                 "dark background, gradient background, scenery, landscape, text, letters, watermark"),
}


# ------------------------------------------------------------- метрика кадра

def _figure(im: Image.Image, box=(256, 341)):
    """Кадрирует по чернилам, приводит к одному холсту с сохранением пропорций."""
    a = np.asarray(im.convert("RGB")).astype(np.int16)
    ink = (a < 245).any(2)
    ys, xs = np.where(ink)
    if len(ys) < 200:
        return None, None
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    ink = ink[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h, w = ink.shape
    sc = min(box[0] / w, box[1] / h)
    nw, nh = max(1, round(w * sc)), max(1, round(h * sc))
    canvas = np.full((box[1], box[0], 3), 255, np.uint8)
    mask = np.zeros((box[1], box[0]), bool)
    fig = np.asarray(Image.fromarray(a.astype(np.uint8)).resize((nw, nh), Image.LANCZOS))
    mk = np.asarray(Image.fromarray((ink * 255).astype(np.uint8)).resize((nw, nh), Image.NEAREST)) > 127
    y0, x0 = (box[1] - nh) // 2, (box[0] - nw) // 2
    canvas[y0:y0 + nh, x0:x0 + nw], mask[y0:y0 + nh, x0:x0 + nw] = fig, mk
    return canvas, mask


def similarity(ref: Path, gen: Path) -> dict:
    """Подсказка порядка разбора: силуэт + цвета внутри силуэта. Вердикт ставится не по ней."""
    f1, m1 = _figure(Image.open(ref))
    f2, m2 = _figure(Image.open(gen))
    if f1 is None or f2 is None:
        return {"error": "не найден силуэт"}
    iou = float((m1 & m2).sum() / max(1, (m1 | m2).sum()))
    h1 = np.histogram(f1[m1] / 32, bins=8, range=(0, 8), density=True)[0]
    h2 = np.histogram(f2[m2] / 32, bins=8, range=(0, 8), density=True)[0]
    hist = float(np.minimum(h1, h2).sum() / 3)
    ar = float(min(m1.sum(), m2.sum()) / max(1, max(m1.sum(), m2.sum())))
    return {"silhouette": round(iou, 3), "colour": round(hist, 3), "fill": round(ar, 3),
            "score": round(0.45 * iou + 0.35 * hist + 0.2 * ar, 3)}


def pair(jid: str, ref: Path, gen: Path, out: Path, caption: str) -> None:
    h = 420
    cells = []
    for p in (ref, gen):
        im = Image.open(p).convert("RGB")
        cells.append(im.resize((round(im.width * h / im.height), h), Image.LANCZOS))
    board = Image.new("RGB", (cells[0].width + cells[1].width + 12, h + 22), (255, 255, 255))
    board.paste(cells[0], (0, 22))
    board.paste(cells[1], (cells[0].width + 12, 22))
    d = ImageDraw.Draw(board)
    d.text((4, 6), f"ОРИГИНАЛ {jid}", fill=(0, 0, 0))
    d.text((cells[0].width + 16, 6), f"КОПИЯ {caption}", fill=(0, 0, 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    board.save(out, quality=92)


# ------------------------------------------------------------- очередь

def load() -> dict:
    return json.loads(QUEUE.read_text()) if QUEUE.exists() else {}


def save(q: dict) -> None:
    QUEUE.write_text(json.dumps(q, ensure_ascii=False, indent=1) + "\n")


def attempt_name(unit: dict, model: str, version: int) -> str:
    return f"{model}_{unit['unit']}_v{version}"


def attempt_path(unit: dict, model: str, version: int) -> Path:
    ext = (unit.get("file") or "").split(".")[-1] or "webp"
    return ATTEMPTS / unit["unit"] / f"{attempt_name(unit, model, version)}.{ext}"


def readiness(scores: dict) -> float:
    """Средняя по применимым критериям, умноженная на 10. Неприменимый — не указывай."""
    return round(10 * sum(scores.values()) / len(scores)) if scores else 0.0


def report(line: str) -> None:
    DOCS.mkdir(parents=True, exist_ok=True)
    log = DOCS / "report.md"
    if not log.exists():
        log.write_text("# Журнал итераций image-clone\n"
                       f"Модели: krea2, qwen21 | Порог готовности: {READINESS_MIN}% | "
                       f"Лимит попыток: {MAX_ATTEMPTS}\n\n---\n")
    with log.open("a") as fh:
        fh.write(line.rstrip() + "\n\n")


# ------------------------------------------------------------- init

def crop_sheet(src: Path, out: Path) -> None:
    """Ячейка сетки -> трим по белому -> белое поле по бокам до квадрата (общая оправа с прогоном)."""
    im = Image.open(src).convert("RGB")
    cols, rows = GRID
    cw, ch = im.width / cols, im.height / rows
    for n in range(cols * rows):
        col, row = n % cols, n // cols
        cell = im.crop((round(col * cw), round(row * ch), round((col + 1) * cw), round((row + 1) * ch)))
        a = np.asarray(cell)
        ink = (a < 245).any(2)
        ys, xs = np.where(ink)
        if len(ys) < 200:
            raise SystemExit(f"{src.name}: ячейка {n + 1} пустая — сетка листа не 4x3?")
        cell = cell.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
        side = max(cell.size)
        canvas = Image.new("RGB", (side, side), (255, 255, 255))
        canvas.paste(cell, ((side - cell.width) // 2, (side - cell.height) // 2))
        canvas.save(out / f"cell-{n + 1:02d}.png")


def cmd_init(a) -> int:
    src = Path(a.src)
    sheets = sorted(src.glob("*.jpeg")) + sorted(src.glob("*.jpg")) + sorted(src.glob("*.png"))
    if len(sheets) != 5:
        raise SystemExit(f"в {src} листов {len(sheets)}, ожидалось 5")
    CROPS.mkdir(parents=True, exist_ok=True)
    ATTEMPTS.mkdir(parents=True, exist_ok=True)
    MATCHES.mkdir(parents=True, exist_ok=True)
    spec = json.loads(SPEC.read_text()) if SPEC.exists() else blank_spec()
    q = load()
    for s, sheet in enumerate(sheets):
        name = f"unit-{s + 1:02d}"
        dst = REFS / f"{name}.jpeg"
        REFS.mkdir(parents=True, exist_ok=True)
        if not dst.exists():
            shutil.copy(sheet, dst)
        tmp = CROPS / name
        tmp.mkdir(exist_ok=True)
        if not any(tmp.glob("cell-*.png")):
            crop_sheet(dst, tmp)
        for n in range(GRID[0] * GRID[1]):
            uid = f"IMG-{s * GRID[0] * GRID[1] + n + 1:03d}"
            crop = CROPS / f"{uid}.png"
            if not crop.exists():
                (tmp / f"cell-{n + 1:02d}.png").rename(crop)
            if uid in q:
                continue
            q[uid] = {"unit": uid, "reference": f"references/crops/{uid}.png",
                      "sheet": f"references/{name}.jpeg", "cell": n + 1, "category": name,
                      "model": MODEL_DEFAULT, "status": "in-queue", "version": 0,
                      "versions": {}, "best_score": None, "max_attempts": MAX_ATTEMPTS,
                      "subject": "", "history": []}
        shutil.rmtree(tmp, ignore_errors=True)
        spec["categories"][name]["items"] = [
            {"id": f"IMG-{s * GRID[0] * GRID[1] + n + 1:03d}", "subject": ""} for n in range(12)]
    save(q)
    SPEC.write_text(json.dumps(spec, ensure_ascii=False, indent=1) + "\n")
    check_invariant(q)
    print(f"юнитов в очереди: {len(q)} (новых не перезаписывали), оправа: {SPEC}")
    return 0


def blank_spec() -> dict:
    base = json.loads((HERE / "spec_copy48.json").read_text())
    base["out_dir"] = OUT_DIR
    base["references_dir"] = str(REFS)
    base["model"] = MODEL_DEFAULT
    base["_comment"] = ("Оправа лаборатории image-clone: 5 листов по 12 ячеек, прогон 512x512. "
                        "Сюжеты живёт в queue.json, сюда вкладываются на время генерации.")
    base["variants"] = [VARIANT]
    base["categories"] = {
        name: {"count": 12, "reference": f"{name}.jpeg", "style": style, "frame": FRAME,
               "size": SIZE, "items": []}
        for name, style in SHEET_STYLE.items()}
    return base


def check_invariant(q: dict) -> None:
    ids = sorted(q)
    if len(ids) != 60:
        raise SystemExit(f"юнитов {len(ids)} != 60")
    if len(set(ids)) != len(ids):
        raise SystemExit("дубли id")
    missing = [u for u in ids if not (LAB / q[u]["reference"]).is_file()]
    if missing:
        raise SystemExit(f"нет кропов: {missing[:5]}")
    sizes = {Image.open(LAB / q[u]["reference"]).size for u in ids}
    if len({s[0] // s[1] for s in sizes}) > 1:
        raise SystemExit(f"кропы не квадрратные: {sizes}")


# ------------------------------------------------------------- генерация

def cmd_next(a) -> int:
    q = load()
    uid, unit = next(((k, v) for k, v in sorted(q.items()) if v["status"] == "in-queue"), (None, None))
    if unit is None:
        print("незакрытых юнитов нет")
        return 0
    model = a.model or unit["model"]
    version = unit["versions"].get(model, 0) + 1
    gen = attempt_path(unit, model, version)
    if not gen.exists():
        if not unit["subject"].strip():
            print(f"{uid}: описания нет — сначала письменный анализ оригинала\n"
                  f"оригинал: {LAB / unit['reference']}")
            return 1
        spec = json.loads(SPEC.read_text())
        item = next(i for i in spec["categories"][unit["category"]]["items"] if i["id"] == uid)
        item["subject"], item["seed_bump"] = unit["subject"], version - 1
        SPEC.write_text(json.dumps(spec, ensure_ascii=False, indent=1) + "\n")
        raw = ROOT / OUT_DIR / model / "copy" / unit["category"] / f"{uid}.webp"
        raw.unlink(missing_ok=True)
        subprocess.run([sys.executable, str(HERE / "generate.py"), "--spec", str(SPEC),
                        "--model", model, "--only", uid], check=False)
        if not raw.exists():
            print(f"{uid}: генерация не дала файла")
            return 1
        gen.parent.mkdir(parents=True, exist_ok=True)
        raw.rename(gen)
    m = similarity(LAB / unit["reference"], gen)
    p = PAIRS / f"{uid}.png"
    pair(uid, LAB / unit["reference"], gen, p, f"{model} v{version} metric={m.get('score')}")
    unit["versions"][model] = version
    unit.update(model=model, version=version, file=str(gen.relative_to(LAB)), pair=str(p))
    save(q)
    print(f"\n>>> {uid} [{unit['category']}] {model} v{version} метрика {m}")
    print(f"оригинал: {LAB / unit['reference']}\nкопия:   {gen}\nпара:    {p}")
    print(f"в журнал: {date.today()} {uid} v{version} | {gen.name}")
    return 0


# ------------------------------------------------------------- вердикт

def cmd_score(a) -> int:
    q = load()
    uid, unit = a.id, q[a.id]
    scores = {}
    for kv in a.criteria:
        k, _, v = kv.partition("=")
        if k not in CRITERIA:
            raise SystemExit(f"критерий {k!r} не из списка: {', '.join(CRITERIA)}")
        scores[k] = int(v)
    pct = readiness(scores)
    prev = unit["history"][-1]["readiness"] if unit["history"] else None
    if not unit.get("file"):
        raise SystemExit("кадра нет — сначала next")
    unit["history"].append({"version": unit["version"], "model": unit["model"], "date": str(date.today()),
                            "file": unit.get("file"), "scores": scores, "readiness": pct,
                            "note": a.note or ""})
    unit["best_score"] = max([pct] + [h["readiness"] for h in unit["history"]])
    save(q)
    delta = f"{pct - prev:+d}" if prev is not None else "первая"
    report(f"## {date.today()} {uid} v{unit['version']} → {pct}% (было {prev or '—'}) | "
           f"{Path(unit['file']).name}\n"
           f"- Промт: {unit['subject'][:400]}\n"
           f"- Оценки: {', '.join(f'{k} {v}' for k, v in scores.items())}\n"
           f"- Метрика-подсказка: {unit.get('metric', '—')}\n- Дельта: {delta}\n"
           f"- Заметка: {a.note or '—'}\n")
    verdict = "success" if pct >= READINESS_MIN else ("переработка с нуля" if pct < 60 else "точечная правка")
    print(f"{uid} v{unit['version']}: готовность {pct}% (дельта {delta}) -> {verdict}")
    print(f"запись в {DOCS / 'report.md'}")
    return 0


def cmd_accept(a) -> int:
    q = load()
    unit = q[a.id]
    last = unit["history"][-1] if unit["history"] else None
    if last is None:
        raise SystemExit("сначала сверка: score с оценками по критериям")
    if last["readiness"] < READINESS_MIN:
        raise SystemExit(f"готовность {last['readiness']}% < {READINESS_MIN}% — accept закрыт")
    src = LAB / unit["file"]
    dst = MATCHES / (src.stem + ".webp")
    MATCHES.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, dst)
    unit.update(status="success", note=a.note or unit.get("note", ""))
    save(q)
    doc = DOCS / "prompts.md"
    with doc.open("a") as fh:
        fh.write(f"\n## {a.id} — {unit['sheet'].split('/')[-1]}, ячейка {unit['cell']}\n"
                 f"- Копия: `{dst.name}`, {unit['model']}, {unit['version']} попыток, "
                 f"{last['readiness']}%\n\n{unit['subject']}\n")
    report(f"ИТОГ: ✅ success — {a.id} за {unit['version']} попыток "
           f"({unit['model']}, {last['readiness']}%) → {dst.name}\n")
    print(f"{a.id} принят -> {dst}")
    return 0


def cmd_reject(a) -> int:
    q = load()
    unit = q[a.id]
    if a.subject:
        unit["subject"] = a.subject
    unit["note"] = (a.note or unit.get("note", ""))[:300]
    if unit["version"] >= unit["max_attempts"]:
        unit["status"] = "blocked"
        report(f"ИТОГ: ⛔ blocked — {a.id}, {unit['version']} попыток "
               f"({unit['model']}). Причина: {unit['note']}\n")
        print(f"{a.id} заблокирован: попыток {unit['version']} >= {unit['max_attempts']}")
    else:
        print(f"{a.id} остаётся текущим: версия {unit['version']}+1, правь только слабые критерии")
    save(q)
    return 0


def cmd_model(a) -> int:
    q = load()
    unit = q[a.id]
    unit["model"] = a.model
    unit["versions"].setdefault(a.model, 0)
    save(q)
    print(f"{a.id}: модель {a.model}, следующая попытка — v1 в рамках этой модели")
    return 0


def cmd_subject(a) -> int:
    q = load()
    unit = q[a.id]
    if unit["status"] == "success":
        raise SystemExit(f"{a.id} закрыт, описание правится только через reject")
    unit["subject"] = a.text.strip()
    save(q)
    print(f"{a.id}: описание {len(unit['subject'])} знаков, кадр ещё не генерировался")
    return 0


def cmd_stat(_a) -> int:
    q = load()
    tally = {}
    for u in q.values():
        tally[u["status"]] = tally.get(u["status"], 0) + 1
    print(f"всего {len(q)}: " + ", ".join(f"{k}={v}" for k, v in sorted(tally.items())))
    by_model = {}
    for u in q.values():
        for h in u["history"]:
            by_model.setdefault(h["model"], []).append((h["readiness"], u["version"]))
    print("\nмодель | средний % | средние попытки | замеров")
    for model, rows in sorted(by_model.items()):
        n = len(rows)
        print(f"  {model:8} {sum(r[0] for r in rows) / n:6.1f} "
              f"{sum(r[1] for r in rows) / n:8.1f} {n:8}")
    open_ = [u for u in sorted(q) if q[u]["status"] == "in-queue"]
    if open_:
        print(f"\nтекущий: {open_[0]} (пока он не закрыт, следующий не начинается)")
    blocked = [u for u in sorted(q) if q[u]["status"] == "blocked"]
    if blocked:
        print(f"заблокировано: {', '.join(blocked)}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    i = sub.add_parser("init")
    i.add_argument("--src", default=str(SHEETS_SRC))
    i.set_defaults(f=cmd_init)
    n = sub.add_parser("next")
    n.add_argument("--model", default=None)
    n.set_defaults(f=cmd_next)
    sc = sub.add_parser("score")
    sc.add_argument("id")
    sc.add_argument("criteria", nargs="+")
    sc.add_argument("--note", default="")
    sc.set_defaults(f=cmd_score)
    ac = sub.add_parser("accept")
    ac.add_argument("id")
    ac.add_argument("--note", default="")
    ac.set_defaults(f=cmd_accept)
    rj = sub.add_parser("reject")
    rj.add_argument("id")
    rj.add_argument("subject", nargs="?", default="")
    rj.add_argument("--note", default="")
    rj.set_defaults(f=cmd_reject)
    md = sub.add_parser("model")
    md.add_argument("id")
    md.add_argument("model")
    md.set_defaults(f=cmd_model)
    sj = sub.add_parser("subject")
    sj.add_argument("id")
    sj.add_argument("text")
    sj.set_defaults(f=cmd_subject)
    sub.add_parser("stat").set_defaults(f=cmd_stat)
    args = ap.parse_args()
    return args.f(args)


if __name__ == "__main__":
    sys.exit(main())

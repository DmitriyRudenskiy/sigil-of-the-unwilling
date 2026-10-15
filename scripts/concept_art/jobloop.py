#!/usr/bin/env python3
"""База заданий копирования: один сюжет за раз — сгенерировать, сверить с оригиналом,
принять в локальную папку или переписать сюжет и поставить в очередь заново.

    jobloop.py init                 завести/дополнить базу из каталога
    jobloop.py next [--model krea2] взять первое незакрытое задание, сгенерировать, оценить
    jobloop.py accept <id>          копия совпала -> положить в папку принятых
    jobloop.py reject <id> "новое описание" [--note "что не так"]
    jobloop.py stat                 сводка по статусам
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SPEC = HERE / "spec_copy48.json"
CROPS = ROOT / "concept_art/refs48/crops"
JOBS = HERE / "jobs.json"
ACCEPTED = ROOT / "concept_art/accepted48"
PAIRS = ROOT / "concept_art/pairs48"
MODEL_DEFAULT = "krea2"


# ------------------------------------------------------------- метрика кадра

def _figure(im: Image.Image, box=(256, 341)):
    """Кадрирует по чернилам, приводит к одному холсту с сохранением пропорций."""
    a = np.asarray(im.convert("RGB")).astype(np.int16)
    ink = (a < 245).any(2)
    ys, xs = np.where(ink)
    if len(ys) < 200:
        return None, None
    a, ink = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1], ink[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
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
    """Насколько кадр похож на оригинал: силуэт + цвета внутри силуэта.

    SSIM по всему кадру здесь врёт — фон белый у обоих и тащит оценку вверх независимо от
    персонажа (раунды 3-4: 0.805 против 0.801 при разных кадрах)."""
    f1, m1 = _figure(Image.open(ref))
    f2, m2 = _figure(Image.open(gen))
    if f1 is None or f2 is None:
        return {"error": "не найден силуэт"}
    iou = float((m1 & m2).sum() / max(1, (m1 | m2).sum()))
    h1 = np.histogram(f1[m1] / 32, bins=8, range=(0, 8), density=True)[0]
    h2 = np.histogram(f2[m2] / 32, bins=8, range=(0, 8), density=True)[0]
    hist = float(np.minimum(h1, h2).sum() / 3)          # пересечение гистограмм по каналам
    ar = float(min(m1.sum(), m2.sum()) / max(1, max(m1.sum(), m2.sum())))
    return {"silhouette": round(iou, 3), "colour": round(hist, 3), "fill": round(ar, 3),
            "score": round(0.45 * iou + 0.35 * hist + 0.2 * ar, 3)}


def pair(jid: str, ref: Path, gen: Path, out: Path, caption: str) -> None:
    h = 512
    cells = []
    for p in (ref, gen):
        im = Image.open(p).convert("RGB")
        sc = h / im.height
        cells.append(im.resize((round(im.width * sc), h), Image.LANCZOS))
    board = Image.new("RGB", (cells[0].width + cells[1].width + 12, h + 22), (255, 255, 255))
    board.paste(cells[0], (0, 22))
    board.paste(cells[1], (cells[0].width + 12, 22))
    d = ImageDraw.Draw(board)
    d.text((4, 6), f"ОРИГИНАЛ {jid}", fill=(0, 0, 0))
    d.text((cells[0].width + 16, 6), f"КОПИЯ {caption}", fill=(0, 0, 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    board.save(out, quality=92)


# ------------------------------------------------------------- база

def load() -> dict:
    return json.loads(JOBS.read_text()) if JOBS.exists() else {"model": MODEL_DEFAULT, "jobs": []}


def save(db: dict) -> None:
    JOBS.write_text(json.dumps(db, ensure_ascii=False, indent=1) + "\n")


def index(db: dict) -> dict:
    return {j["id"]: j for j in db["jobs"]}


def out_path(job: dict, model: str) -> Path:
    spec = json.loads(SPEC.read_text())
    return (ROOT / spec["out_dir"] / model / "copy" / job["cat"] / f"{job['id']}.webp")


def cmd_init(_a) -> int:
    spec = json.loads(SPEC.read_text())
    db = load()
    seen = {j["id"] for j in db["jobs"]}
    for cname, c in spec["categories"].items():
        for item in c["items"]:
            if item["id"] in seen:
                continue
            db["jobs"].append({"id": item["id"], "cat": cname, "subject": item["subject"],
                               "ref": str(CROPS / f"{item['id']}.png"), "status": "pending",
                               "tries": 0, "score": None, "note": ""})
    save(db)
    print(f"заданий в базе: {len(db['jobs'])}")
    return 0


def db_jobs() -> list:
    return load()["jobs"]

def cmd_stat(_a) -> int:
    db, tally = load(), {}
    for j in db["jobs"]:
        tally[j["status"]] = tally.get(j["status"], 0) + 1
    print(f"всего {len(db['jobs'])}: " + ", ".join(f"{k}={v}" for k, v in sorted(tally.items())))
    for j in db["jobs"]:
        if j["status"] not in ("accepted",):
            print(f"  {j['status']:8} {j['id']:8} tries={j['tries']} score={j['score']} {j['note'][:60]}")
    return 0


def cmd_next(a) -> int:
    db = load()
    model = a.model or db.get("model", MODEL_DEFAULT)
    job = next((j for j in db["jobs"] if j["status"] in ("pending", "requeue")), None)
    if job is None:
        print("незакрытых заданий нет")
        return 0
    ref, gen = Path(job["ref"]), out_path(job, model)
    if not gen.exists():
        spec = json.loads(SPEC.read_text())
        item = next(i for i in spec["categories"][job["cat"]]["items"] if i["id"] == job["id"])
        item["subject"], item["seed_bump"] = job["subject"], job["tries"]
        SPEC.write_text(json.dumps(spec, ensure_ascii=False, indent=1) + "\n")
        cmd = [sys.executable, str(HERE / "generate.py"), "--spec", str(SPEC),
               "--model", model, "--only", job["id"]]
        print(" ".join(cmd[-4:]), flush=True)
        subprocess.run(cmd, check=False)
    if not gen.exists():
        job["status"], job["note"] = "requeue", "генерация не дала файла"
        job["tries"] += 1
        save(db)
        print(f"{job['id']}: нет файла, снова в очередь")
        return 1
    m = similarity(ref, gen)
    p = PAIRS / f"{job['id']}.png"
    pair(job["id"], ref, gen, p, f"{model} try{job['tries']} score={m.get('score')}")
    job.update(status="review", score=m.get("score"), metric=m, model=model,
               gen=str(gen), pair=str(p))
    save(db)
    print(f"\n>>> {job['id']} [{job['cat']}] попытка {job['tries']} метрика {m}")
    print(f"оригинал: {ref}\nкопия:   {gen}\nпара:    {p}")
    print(f"сюжет: {job['subject']}")
    return 0


def cmd_accept(a) -> int:
    db = load()
    job = index(db)[a.id]
    gen = Path(job["gen"]) if job.get("gen") else out_path(job, job.get("model", MODEL_DEFAULT))
    ACCEPTED.mkdir(parents=True, exist_ok=True)
    shutil.copy(gen, ACCEPTED / f"{job['id']}.webp")
    job.update(status="accepted", note=a.note or job.get("note", ""))
    save(db)
    print(f"{job['id']} принят -> {ACCEPTED / (job['id'] + '.webp')}")
    return 0


def cmd_reject(a) -> int:
    db = load()
    job = index(db)[a.id]
    gen = Path(job["gen"]) if job.get("gen") else out_path(job, job.get("model", MODEL_DEFAULT))
    if gen.exists():                                   # брак не остаётся готовым выводом
        rej = gen.parent.parent.parent / "_reject" / f"{job['id']}__try{job['tries']}.webp"
        rej.parent.mkdir(parents=True, exist_ok=True)
        gen.rename(rej)
    if a.subject:
        job["subject"] = a.subject
    job.update(status="requeue", tries=job["tries"] + 1, note=(a.note or "")[:200])
    save(db)
    print(f"{job['id']} -> очередь (попытка {job['tries']}), затравка смещена")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("init").set_defaults(f=cmd_init)
    sub.add_parser("stat").set_defaults(f=cmd_stat)
    n = sub.add_parser("next")
    n.add_argument("--model", default=None)
    n.set_defaults(f=cmd_next)
    ac = sub.add_parser("accept")
    ac.add_argument("id")
    ac.add_argument("--note", default="")
    ac.set_defaults(f=cmd_accept)
    rj = sub.add_parser("reject")
    rj.add_argument("id")
    rj.add_argument("subject", nargs="?", default="")
    rj.add_argument("--note", default="")
    rj.set_defaults(f=cmd_reject)
    a = ap.parse_args()
    return a.f(a)


if __name__ == "__main__":
    sys.exit(main())

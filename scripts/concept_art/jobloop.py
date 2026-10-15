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
import hashlib
import inspect
import re
import json
import shutil
import subprocess
import sys
from datetime import date
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from generate import seed_for        # затравку считает генератор, не копия формулы
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
ETALONS = REFS / "manifest.json"
ANCHOR_MANIFEST = REFS / "anchors-manifest.json"
INK_MAX = 235                       # порог «не бумага» для поиска фигуры (тот же, что у гейта)
SHEETS_SRC = Path("/Users/user/sigil-of-the-unwilling-slop/___STYLE_BOOK/for_local_agent/unit")

GRID = (4, 3)                   # колонок, строк на листе
SIZE = [1024, 1024]             # размер прогона лаборатории
MAX_ATTEMPTS = 5
READINESS_MIN = 85
MODEL_DEFAULT = "krea2"
CNT_FIXUP_MAX = 3               # экономический порог: больше точечных правок — перерисовка
STY_VERDICTS = ("yes", "near", "no")   # да / почти / нет
OPEN = ("in-queue", "redraw")   # статусы, по которым образец всё ещё берётся в работу
CRITERIA = ("comp", "subject", "objects", "palette", "style", "light", "bg", "camera", "text")
# Строки слоя стиля: только они дают STY-% и только на них существует десятка.
STY_ROWS = ("line", "color", "texture", "shade")
STY_ROW_RU = {"line": "линия", "color": "колорит", "texture": "фактура", "shade": "светотень"}
STY_TARGET = 93                 # планка «сошлись»: сумма четырёх строк >= 38
SEED_PIN = 43                   # сид прогона: один на все стадии цепочки (7.2)
ANCHORS = DOCS / "anchors.md"   # реестр якорных пар: цитата обязана быть в нём
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


FONT = None
for _f in ("DejaVuSans.ttf",                                    # Linux / CI
           "/System/Library/Fonts/Supplemental/Verdana.ttf",     # macOS
           "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
           "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):   # Debian
    try:
        FONT = ImageFont.truetype(_f, 16)
        break
    except OSError:
        pass
if FONT is None:                       # у bitmap-шрифта кириллицы нет — подписи квадратами
    FONT = ImageFont.load_default(16)


def pair(jid: str, ref: Path, gen: Path, out: Path, caption: str,
         h: int = 420, inset: float = 0.0) -> None:
    cells = []
    for p in (ref, gen):
        im = Image.open(p).convert("RGB")
        if inset:                                   # доля короткой стороны
            d = int(min(im.size) * inset)
            im = im.crop((d, d, im.width - d, im.height - d))
        cells.append(im.resize((round(im.width * h / im.height), h), Image.LANCZOS))
    board = Image.new("RGB", (cells[0].width + cells[1].width + 12, h + 22), (255, 255, 255))
    board.paste(cells[0], (0, 22))
    board.paste(cells[1], (cells[0].width + 12, 22))
    d = ImageDraw.Draw(board)
    d.text((4, 6), f"ОРИГИНАЛ {jid}", font=FONT, fill=(0, 0, 0))
    d.text((cells[0].width + 16, 6), f"КОПИЯ {caption}", font=FONT, fill=(0, 0, 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    board.save(out, quality=92)


def unit_of(p: Path) -> str:
    m = re.search(r"IMG-\d+", p.name)
    return m.group() if m else "?"


def is_control(r: dict) -> bool:
    return "эталон↔эталон" in r["origin"]


def sheet_key(r: dict) -> str:
    """Лист = строка стиля и ОДИН юнит: его эталон и его варианты.
    Контроль «эталон↔эталон» — общий лист на все строки: там два разных
    эталонных рисунка, своего юнита у него нет."""
    return "К" if is_control(r) else r["row"] + ":" + unit_of(r["pair"][0])


def grid(pairs_: list[dict], out: Path, h: int = 380) -> None:
    """Лист: один эталон и его варианты (для контроля — два эталона).
    Уровней не видно: подписаны id пары, роль кадра и юнит."""
    control = is_control(pairs_[0])
    cells, seen = [], set()
    for r in pairs_:
        for n, p in enumerate(r["pair"]):
            if str(p) in seen:
                continue                       # общий эталон листа рисуется один раз
            seen.add(str(p))
            role = (f"эталон {'АБ'[n]}" if control
                    else ("эталон" if n == 0 else "вариант"))
            im = Image.open(p).convert("RGB")
            cells.append((f'{r["id"]} · {role} ({unit_of(p)})',
                          im.resize((round(im.width * h / im.height), h), Image.LANCZOS)))
    gap, top = 10, 22
    w = max(c[1].width for c in cells)
    lines = -(-len(cells) // 2)
    head = (" · ".join(f'{r["id"]} {r["ru"]}' for r in pairs_) if control else "")
    pad = 26 if head else 0            # контроль один лист на все строки: чем меряется — в шапке
    board = Image.new("RGB", (w * 2 + gap * 3, (h + top) * lines + gap * (lines + 1) + pad),
                      (255, 255, 255))
    d = ImageDraw.Draw(board)
    if head:
        d.text((gap + 2, 6), "контроль поперёк листа: " + head, font=FONT, fill=(0, 0, 0))
    for n, (label, im) in enumerate(cells):
        x = gap + (n % 2) * (w + gap)
        y = pad + gap + (n // 2) * (h + top + gap)
        d.text((x + 2, y + 6), label, font=FONT, fill=(0, 0, 0))
        board.paste(im, (x, y + top))
    out.parent.mkdir(parents=True, exist_ok=True)
    board.save(out, quality=92)


# ------------------------------------------------------------- очередь

def load() -> dict:
    return json.loads(QUEUE.read_text()) if QUEUE.exists() else {}


def save(q: dict) -> None:
    QUEUE.write_text(json.dumps(q, ensure_ascii=False, indent=1) + "\n")


def run_versions() -> tuple[str, str]:
    """Пара версий прогона: P — слова, R — чем настроен рендер.

    Раздельно, иначе правка сэмплера не отличима от правки промпта и кривая
    обучения промпту читается по двум переменным сразу. R — заодно провенанс
    для датасета LoRA: принятые кадры должны собираться под одним R.
    """
    s = json.loads(SPEC.read_text()) if SPEC.is_file() else {}
    return s.get("prompt_version", "P0"), s.get("render", {}).get("id", "R0")


def sha12(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12] if path.is_file() else "нет"


def judge_version() -> str:
    """Версия судьи: чем считается готовность. Порог, набор критериев и формула
    — часть прогона; молча их поправить значит переоценить старые баллы."""
    body = f"{CRITERIA}|{READINESS_MIN}|" + inspect.getsource(readiness)
    return "judge-" + hashlib.sha256(body.encode()).hexdigest()[:12]


def run_seal(unit: dict, model: str, version: int, spec: dict) -> dict:
    """Печать прогона: из чего он был сделан. Пишется до рендера, сверяется
    `verify`, без неё `score` балл не ставит — иначе вердикт нельзя приписать
    ни промпту, ни словарю, ни прибору (8.21)."""
    r = spec.get("render", {})
    m = spec.get("models", {}).get(model, {})
    # печать пишет то, что ушло в граф: cfg/шаги/сэмплер принадлежат модели,
    # R-блок докручивает остальное (см. generate.workflow)
    eff = {k: m.get(k, r.get(k)) for k in ("cfg", "sampler", "scheduler", "steps")}
    return {
        "etalon": sha12(LAB / unit["reference"]),
        "sheet": sha12(LAB / unit["sheet"]),
        "model": model,
        "seed": spec.get("seed", SEED_PIN),   # настоящий сид прогона: он же в графе
        "prompt_version": spec.get("prompt_version", "P0"),
        "render_version": r.get("id", "R0"),
        "render": {**eff,
                   # вес берётся из блока модели, а не из подписи в render: печать
                   # обязана писать то, что грузили, а не то, что там написано
                   "checkpoint": m.get("unet", "нет")},
        "dictionary": sha12(DOCS / "style-card.md"),
        "instrument": anchors_version() if ANCHORS.is_file() else "нет",
        "judge": judge_version(),
    }


def attempt_name(unit: dict, model: str, version: int) -> str:
    """Имя попытки — `<model>_<unit>_v<N>` без суффиксов (спек «Именование результатов»);
    версии промпта и рендера живут в печати прогона и журнале, не в имени файла."""
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

def etalon_files() -> list:
    return sorted(p for p in REFS.rglob("*") if p.is_file() and p.suffix.lower() in (".jpeg", ".png"))


def etalon_version() -> str:
    """Версия эталонного сета: хеш списка «имя:хеш» всех листов и кропов лаборатории."""
    lines = [f"{p.relative_to(REFS).as_posix()}:{hashlib.sha256(p.read_bytes()).hexdigest()}"
             for p in etalon_files()]
    return "etalons-" + hashlib.sha256("\n".join(lines).encode()).hexdigest()[:12]


def cmd_etalons(a) -> int:
    """Зафиксировать эталонный сет: файлы, размеры, хеши, версия. Вердикт сверяется с ней."""
    rows = [{"file": p.relative_to(REFS).as_posix(), "bytes": p.stat().st_size,
             "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in etalon_files()]
    ETALONS.write_text(json.dumps({"version": etalon_version(), "files": rows},
                                  ensure_ascii=False, indent=1) + "\n")
    print(f"{ETALONS}: {json.loads(ETALONS.read_text())['version']}, файлов {len(rows)}")
    return 0


def cmd_next(a) -> int:
    require_anchors()
    q = load()
    if a.id:
        uid, unit = a.id, q.get(a.id)
        if not unit or unit["status"] not in OPEN:
            raise SystemExit(f"{a.id} не в работе: {(unit or {}).get('status', 'нет такого')}")
    else:
        uid, unit = next(((k, v) for k, v in sorted(q.items()) if v["status"] in OPEN), (None, None))
    if unit is None:
        print("незакрытых юнитов нет")
        return 0
    model = a.model or stage_of(unit, json.loads(SPEC.read_text())) or unit["model"]
    version = unit["versions"].get(model, 0) + 1
    gen = attempt_path(unit, model, version)
    if not gen.exists():
        if not unit["subject"].strip():
            print(f"{uid}: описания нет — сначала письменный анализ оригинала\n"
                  f"оригинал: {LAB / unit['reference']}")
            return 1
        spec = json.loads(SPEC.read_text())
        item = next(i for i in spec["categories"][unit["category"]]["items"] if i["id"] == uid)
        item["subject"] = unit["subject"]
        SPEC.write_text(json.dumps(spec, ensure_ascii=False, indent=1) + "\n")
        gen.parent.mkdir(parents=True, exist_ok=True)
        unit["seal"] = run_seal(unit, model, version, spec)
        save(q)        # печать до рендера: упавший прогон тоже обязан быть опечатан
        # Имя кадру отдаём серверу до запуска: узел сохранения пишет его сам,
        # локально файл ложится сразу в attempts/ и ничего не переименовывается.
        subprocess.run([sys.executable, str(HERE / "generate.py"), "--spec", str(SPEC),
                        "--model", model, "--only", uid, "--dest", str(gen),
                        "--server-prefix", f"{LAB.name}/{uid}/{gen.stem}"], check=False)
        if not gen.exists():
            print(f"{uid}: генерация не дала файла")
            return 1
    m = similarity(LAB / unit["reference"], gen)
    unit["versions"][model] = version
    unit.update(model=model, version=version, file=str(gen.relative_to(LAB)),
                prompt_version=run_versions()[0], render_version=run_versions()[1])
    save(q)
    p = board(uid)          # доска 2×2 вместо прежней пары 1×1 — тот же pairs/<юнит>
    print(f"\n>>> {uid} [{unit['category']}] {model} v{version} метрика {m}")
    print(f"оригинал: {LAB / unit['reference']}\nкопия:   {gen}\nдоска:    {p}")
    print(f"в журнал: {date.today()} {uid} v{version} | {gen.name}")
    return 0


# ------------------------------------------------- строки стиля (STY-%)

RU_TO_ROW = {v: k for k, v in STY_ROW_RU.items()}


def anchor_rows() -> list[dict]:
    """Строки реестра: | ID | Балл | Строка | Происхождение | Направление | Пара | Что видно |."""
    rows = []
    if not ANCHORS.is_file():
        raise SystemExit(f"реестр якорей не найден: {ANCHORS}")
    for line in ANCHORS.read_text().splitlines():
        c = [x.strip() for x in line.strip().strip("|").split("|")]
        if len(c) != 7 or not c[0].startswith("AP-"):
            continue
        a, b = [x.strip() for x in c[5].split("↔")]
        rows.append({"id": c[0], "score": int(c[1]), "row": RU_TO_ROW[c[2]], "ru": c[2],
                     "origin": c[3], "drift": c[4], "why": c[6],
                     "pair": (LAB / a, LAB / b)})
    return rows


def anchors_body() -> str:
    """Тело реестра = строки таблицы пар. Таблица сравнения судей в том же файле
    не тело: форма строки (7 колонок) решает, а не префикс."""
    return "\n".join(l for l in ANCHORS.read_text().splitlines()
                     if l.startswith("| AP-")
                     and len([x for x in l.strip().strip("|").split("|")]) == 7)


def anchors_version() -> str:
    """Версия прибора = хеш тела реестра (строки пар, без комментариев)."""
    return "anchors-" + hashlib.sha256(anchors_body().encode()).hexdigest()[:12]


def require_anchors() -> str:
    """Гейт целостности прибора: файл реестра сверяется с манифестом при старте.

    Тесты и человек правят реестр чаще, чем коммитят; хеш ловит это до замера,
    а не в отчёте. Несовпадение — отказ, как с эталонным сетом.
    """
    if not ANCHORS.is_file():
        return ""            # прибора ещё нет: десятки цитировать не во что
    body = anchors_body()
    live = "anchors-" + hashlib.sha256(body.encode()).hexdigest()[:12]
    if not ANCHOR_MANIFEST.is_file():
        raise SystemExit(f"реестр якорей не опечатан ({ANCHOR_MANIFEST.name}); "
                         f"живой {live}: `jobloop anchors seal` после правки")
    man = json.loads(ANCHOR_MANIFEST.read_text())
    if man["version"] != live:
        raise SystemExit(f"реестр якорей изменён после опечатки: манифест {man['version']}, "
                         f"файл {live}; переприсмотр или `jobloop anchors seal`")
    bad = check_boards(man)
    if bad:
        raise SystemExit("; ".join(bad) + " — пересборка: `jobloop anchors seal`")
    return live


def chunk_of(rows: list[dict], r: dict) -> list[dict]:
    """Все пары одного листа: та же строка стиля и тот же юнит. Пара без
    своего кадра из листа выпадает одна, а не утаскивает за собой соседей —
    иначе один мёртвый якорь обнулял бы половину строки."""
    return [x for x in rows if sheet_key(x) == sheet_key(r)
            and all(p.is_file() for p in x["pair"])]


def board_path(r: dict) -> Path:
    """Имя листа — по строке стиля и юниту (AP-line-IMG-001.png)."""
    k = sheet_key(r)
    return PAIRS / "anchors" / ("AP-control.png" if k == "К"
                                else "AP-" + k.replace(":", "-") + ".png")


def seal_boards(rows: list[dict]) -> dict:
    """Доски слепого прохода под печатью тоже. Реестр — прибор, а доски — то,
    что реально скорит судья: подменённая доска меняет вердикт, не трогая
    ни реестра, ни эталонов. Доска детерминирована из строки реестра."""
    out = {}
    for r in rows:
        chunk = chunk_of(rows, r)
        if not chunk:
            continue          # у пары кадры не на месте — она не в печати, соседи при своих
        b = grid_board(chunk)
        for x in chunk:
            out[x["id"]] = hashlib.sha256(b.read_bytes()).hexdigest()
    return out


def check_boards(manifest: dict) -> list[str]:
    out, rows = [], anchor_rows()
    for rid, want in manifest.get("boards", {}).items():
        r = next((x for x in rows if x["id"] == rid), None)
        if r is None:
            out.append(f"пара {rid} пропала из реестра, доска под печатью")
            continue
        b = board_path(r)
        if not b.is_file():
            out.append(f"доска {b.name} удалена из material слепого прохода")
        elif hashlib.sha256(b.read_bytes()).hexdigest() != want:
            out.append(f"доска {b.name} расходится с опечатанной: судья смотрел не это")
    return out


def cmd_seal(a) -> int:
    body = anchors_body()
    ver = "anchors-" + hashlib.sha256(body.encode()).hexdigest()[:12]
    rows = anchor_rows()
    ANCHOR_MANIFEST.write_text(json.dumps(
        {"version": ver, "sha256": hashlib.sha256(body.encode()).hexdigest(),
         "pairs": len(rows), "date": str(date.today()), "boards": seal_boards(rows)},
        ensure_ascii=False, indent=1) + "\n")
    n = len(json.loads(ANCHOR_MANIFEST.read_text())["boards"])
    print(f"{ANCHOR_MANIFEST}: {ver}, пар {len(rows)}, досок опечатано {n}")
    return 0


def control_board(ap_id: str) -> Path:
    """Контроль сессии подаётся другим кадрированием, чем в реестровой доске:
    опознанный контроль перестаёт детектировать дрейф судьи."""
    r = next(x for x in anchor_rows() if x["id"] == ap_id)
    out = PAIRS / "controls" / f"{ap_id}.png"
    # другое кадрирование и другой масштаб: опознанный контроль не детектирует
    # дрейф судьи, он детектирует только память на доску
    pair(ap_id, r["pair"][0], r["pair"][1], out, "контроль", h=640, inset=0.06)
    return out


def anchor_log() -> list[dict]:
    log = DOCS / "anchor-log.json"
    return json.loads(log.read_text()) if log.is_file() else []


def grid_board(chunk: list[dict]) -> Path:
    """Лист для всех пар строки и юнита; имя — по строке и юниту."""
    out = board_path(chunk[0])
    out.parent.mkdir(parents=True, exist_ok=True)
    grid(chunk, out)
    return out


def cmd_anchors_show_all(rows: list[dict]) -> int:
    board = PAIRS / "anchors"
    board.mkdir(parents=True, exist_ok=True)
    for old in board.glob("AP-*.png"):
        old.unlink()                       # доски другого кроя больше не прибор
    sheets = {sheet_key(r): chunk_of(rows, r) for r in rows}
    for key in sorted(sheets, key=lambda k: (k == "К", k)):
        chunk = sheets[key]
        out = grid_board(chunk)
        head = (f"{chunk[0]['ru']}, {unit_of(chunk[0]['pair'][0])}: эталон и "
                f"{len(chunk)} варианта" if key != "К"
                else "контроль: два эталонных листа, меряется по строкам своих пар")
        print(f"\n{out}  — {head}")
        for r in chunk:
            print(f"  jobloop.py anchors score {r['id']} {r['row']}=N --pass revision")
    print(f"\nлистов {len(sheets)}; на каждом один персонаж: его эталон и его "
          f"варианты; уровней не видно; сверка — после записи каждой пары")
    return 0


# Рубрика уровней живёт здесь, а не в реестре: второй судья не должен видеть ни
# заявленных баллов, ни описаний пар — только шкалу и лист.
BLIND_BRIEF = (
    "Ты слепой судья стиля. Реестра якорей ты не видишь, уровней не знаешь.\n"
    "На каждом листе слева — эталон, справа варианты ТОГО ЖЕ персонажа.\n"
    "Одна строка стиля на листе; смотреть лист целиком; сходство позы,\n"
    "лица и кадрирования не считать — меряется только строка листа.\n"
    "Шкала: 10 — по этой строке расхождений нет; 9 — одно мелкое;\n"
    "7–8 — заметное расхождение, семья та же; 5–6 — строка держится\n"
    "клочьями; 1–4 — строка потеряна. Концов шкалы не бойся: если все\n"
    "твои оценки 6–8, ты не пользуешься шкалой, а не картинка плоха."
)


def cmd_anchors(a) -> int:
    """Реестр якорных пар: show вслепую, score с сверкой после записи, check — структура."""
    if a.what not in ("seal", "check"):
        require_anchors()                # прибор под печатью: молча порвать нельзя
    rows = anchor_rows()
    by_id = {r["id"]: r for r in rows}
    if a.what == "seal":
        return cmd_seal(a)
    if a.what == "stat":
        log = anchor_log()
        print(f"{anchors_version()}, пар {len(rows)}, проверок {len(log)}")
        by = {}
        for rec in log:
            by.setdefault(rec.get("klass", "?"), []).append(rec)
        for k, recs in sorted(by.items()):
            note = {"independent": "честно слепой", "semi-blind": "несогласие перевешивает",
                    "self": "floor-check, не подтверждение"}.get(k, "")
            print(f"  {k:12} записей {len(recs):3}  {note}")
        deltas = [r["given"] - r["declared"] for r in log if r.get("klass") != "self"]
        if deltas and (all(d > 0 for d in deltas) or all(d < 0 for d in deltas)):
            print("  систематический сдвиг всех пар в одну сторону — дрейфует судья, "
                  "он отбраковывается до калибровки")
        elif any(d for d in deltas):
            print("  расхождения рассеянные — конкретные пары на переприсмотр")
        # сжатие шкалы: верха не достигает никто, низа не занижают. Это не про
        # пары (пары тогда все «на переприсмотр» сразу), а про шкалу судьи, и
        # считается по всем классам: self для того и floor-check.
        hi = [r for r in log if r["declared"] >= 9]
        lo = [r for r in log if r["declared"] <= 6]
        if hi and lo and all(r["given"] < r["declared"] for r in hi) \
                and all(r["given"] >= r["declared"] for r in lo):
            print(f"  шкала сжалась: из {len(hi)} верхних ни один не дотянут, "
                  f"из {len(lo)} нижних ни один не занижен — судья не пользуется "
                  "концами шкалы; править надо шкалу, а не пары")
        if not log:
            print("  слепой проход не начат; подтверждений нет, пороги не объявляются")
        for r in rows:
            got = "/".join(str(x["given"]) for x in log if x["id"] == r["id"]) or "не судилось"
            print(f"  {r['id']:14} {r['ru']:9} заявлено {r['score']:2} "
                  f"{('поставлено ' + got):19}{r['origin']:16} {r['drift']}")
        return 0
    if a.what == "check":
        bad = []
        seen = set()
        for r in rows:
            if r["id"] in seen:
                bad.append(f"{r['id']}: дубликат id")
            seen.add(r["id"])
            for p in r["pair"]:
                if not p.is_file():
                    bad.append(f"{r['id']}: кадра нет на диске: {p.relative_to(LAB)}")
        for row in STY_ROWS:
            got = [r for r in rows if r["row"] == row]
            if not any(r["score"] == 10 for r in got):
                bad.append(f"{STY_ROW_RU[row]}: нет десятки — строка не откалибрована сверху")
            low = [r for r in got if r["score"] <= 6]
            rev = [r for r in got if r["score"] == 7]
            if not low or not rev:
                bad.append(f"{STY_ROW_RU[row]}: полоса односторонняя, нужен дрейф в обе стороны")
            elif {r["drift"] for r in low} & {r["drift"] for r in rev}:
                bad.append(f"{STY_ROW_RU[row]}: нижняя полоса и семёрка одним дрейфом — "
                           f"пара не кодирует противоположное направление")
        print("OK: реестр цел" if not bad else "находки:\n  " + "\n  ".join(bad))
        return 1 if bad else 0
    if a.what == "brief":
        print(BLIND_BRIEF)
        return cmd_anchors_show_all(anchor_rows()) or 0
    if a.what == "blind":
        return cmd_anchors_show_all(rows) or 0
    r = by_id.get(a.id)
    if not r:
        raise SystemExit(f"пары {a.id} в реестре нет")
    if a.what == "show":
        board = grid_board(chunk_of(rows, r))
        print("вслепую: уровень заявленного балла скрыт, рядом вторая пара строки\n" + str(board))
        print(f"запись: jobloop.py anchors score {r['id']} {r['row']}=N --pass revision")
        return 0
    if a.what == "score":
        key, _, val = a.mark.partition("=")
        if key != r["row"]:
            raise SystemExit(f"пара про строку {r['ru']}, поставлен балл по {key}")
        given = int(val)
        rec = {"id": r["id"], "date": str(date.today()), "given": given, "declared": r["score"],
               "anchors": anchors_version(), "etalons": etalon_version(),
               "pass": a.judge_pass, "judge": a.judge, "klass": a.klass}
        log = anchor_log() + [rec]
        (DOCS / "anchor-log.json").write_text(json.dumps(log, ensure_ascii=False, indent=1) + "\n")
        with (DOCS / "anchor-log.md").open("a") as fh:
            fh.write(f"\n## {rec['date']} {r['id']} — поставлено {given}, "
                     f"проход {rec['pass']}, реестр {rec['anchors']}\n")
        hit = given == r["score"] or (r["score"] <= 6 and 5 <= given <= 6)
        print(f"{r['id']}: заявлено {r['score']}, поставлено {given} -> "
              + ("подтверждено" if hit else "переприсмотр: неточно либо якорь, либо описание уровня"))
        if a.klass == "self":
            print("  класс self: это floor-check, а не подтверждение пары")
        elif a.klass == "semi-blind":
            print("  класс semi-blind: согласие слабо, перевешивает несогласие")
        return 0
    raise SystemExit("нужно: stat | check | show | score")


def parse_sty_rows(pairs: list[str], gaps: list[str], revised: bool):
    """Баллы четырёх строк стиля. Десятка — сертифицируемое утверждение: только
    с цитатой якорной пары и только пережившая адверсариальный проход. Девятка
    требует проверки (цитаты или названного расхождения), иначе восемь."""
    named = {g.partition("=")[0] for g in gaps}
    rows, tens, notes = {}, [], []
    for kv in pairs:
        k, _, v = kv.partition("=")
        if k not in STY_ROWS:
            raise SystemExit(f"строка {k!r} не из списка: {', '.join(STY_ROWS)}")
        score, _, anchor = v.partition("@")
        score = int(score)
        if not 0 <= score <= 10:
            raise SystemExit(f"{k}: балл {score} вне 0..10")
        ru = STY_ROW_RU[k]
        if score == 10 and not anchor:
            notes.append(f"{ru}: 10 без цитаты якоря -> 9")
            score, anchor = 9, ""
        elif score == 10 and not revised:
            notes.append(f"{ru}: 10 не прошла адверсариальный проход -> 9")
            score = 9
        if score == 9 and not anchor and k not in named:
            notes.append(f"{ru}: 9 без проверки и без названного расхождения -> 8")
            score = 8
        rows[k] = score
        if score == 10:
            tens.append(f"{ru}, против якорной пары {anchor}: расхождений не найдено")
    missing = [STY_ROW_RU[r] for r in STY_ROWS if r not in rows]
    if missing:
        raise SystemExit("нет баллов строк: " + ", ".join(missing)
                         + " — строка без якорной пары не является мерой")
    return rows, tens, notes


def sty_pct(rows: dict) -> float:
    return round(sum(rows[r] for r in STY_ROWS) / len(STY_ROWS) * 10, 1)


def sty_delta(prev: dict | None, rows: dict) -> dict | None:
    """Дельта по строкам, а не по баллу: оператору нужно, какая строка двинулась."""
    return None if not prev else {r: rows[r] - prev.get(r, 0) for r in STY_ROWS}


def head_ratio(spec: str | None):
    """Пропорции головы: `--head-ratio 17/15` = эталон 17%, попытка 15% (высота головы
    от макушки до подбородка без ушей и головного убора / высота фигуры, способ
    зафиксирован в `image-clone/docs/style-card.md` §5). Дельта — в журнале;
    в STY-% не входит."""
    if not spec:
        return None
    try:
        e, _, p = spec.partition("/")
        e, p = int(e), int(p)
    except ValueError:
        raise SystemExit("пропорции головы пишутся как --head-ratio 17/15 "
                         "(эталон/попытка, целые проценты)")
    return {"etalon": e, "attempt": p, "delta": p - e}


def cmd_sty(a) -> int:
    """Замер попытки строками стиля. Единый источник чисел для грида, плато и «сошлись»."""
    q = load()
    uid, unit = a.id, q[a.id]
    if not unit.get("file"):
        raise SystemExit("кадра нет — сначала next")
    if not unit.get("seal"):
        raise SystemExit("прогон не запечатан: STY-числа непроверяемому прогону не ставятся")
    require_anchors()
    gaps = a.gap or []
    a.judge_pass = getattr(a, "judge_pass", "score")
    a.control = getattr(a, "control", None)
    revised = a.judge_pass == "revision"
    rows, tens, notes = parse_sty_rows(a.rows, gaps, revised)
    cited = [kv.partition("@")[2] for kv in a.rows if "@" in kv]
    if cited:
        reg = ANCHORS.read_text() if ANCHORS.is_file() else ""
        dead = [c for c in cited if c and c not in reg]
        if dead:
            raise SystemExit(f"якорной пары нет в реестре {ANCHORS.name}: "
                             + ", ".join(sorted(set(dead))))
    if a.control:
        if not any(r["id"] == a.control for r in anchor_rows()):
            raise SystemExit(f"контроль {a.control} не подтверждён слепым проходом: "
                             f"в реестре такой пары нет")
        print(f"контроль вслепую (другой кроп и масштаб): {control_board(a.control)}")
    pct = sty_pct(rows)
    head = head_ratio(getattr(a, "head_ratio", None))
    prev = next((h for h in reversed(unit["history"]) if h.get("rows")), None)
    delta = sty_delta(prev.get("rows") if prev else None, rows)
    ver = etalon_version() if ETALONS.is_file() else None
    rec = {"kind": "sty", "date": str(date.today()), "model": unit["model"],
           "version": unit["version"], "file": unit["file"],
           "prompt_version": unit.get("prompt_version"),
           "render_version": unit.get("render_version"),
           "seed": unit["seal"]["seed"],      # настоящая затравка прогона, не SEED_PIN
           "cycle": unit.get("cycle", 0) + 1,  # круг цепочки, на котором сделан замер
           "head": head,                        # пропорции головы: отдельный слой, не STY-%
           "etalons": ver, "anchors": anchors_version() if ANCHORS.is_file() else None,
           "rows": rows, "sty_pct": pct, "tens": tens, "gaps": gaps, "notes": notes,
           "judge_pass": a.judge_pass, "control": a.control, "delta": delta}
    unit["history"].append(rec)
    save(q)
    anchor_of = {}
    for kv in a.rows:
        k, _, v = kv.partition("=")
        anchor_of[k] = v.partition("@")[2]
    gap_of = {g.partition("=")[0]: g.partition("=")[2] for g in gaps}
    lines = [f"## {rec['date']} {uid} v{unit['version']} | {unit['model']} "
             f"| {unit.get('prompt_version', 'P?')}{unit.get('render_version', 'R?')}"
             f" | сид {unit['seal']['seed']} | эталоны {ver} | STY-% {pct} (планка {STY_TARGET})\n",
             f"- Файл: {unit['file']}\n"]
    for r in STY_ROWS:
        lines.append(f"- {STY_ROW_RU[r]}: {rows[r]} | {gap_of.get(r, '—')} | "
                     f"{anchor_of.get(r) or '—'}\n")
    for t in tens:
        lines.append(f"- Десятка: {t}\n")
    for note in notes:
        lines.append(f"- Понижение: {note}\n")
    if head:
        lines.append(f"- Пропорции головы: эталон {head['etalon']}%, попытка "
                     f"{head['attempt']}%, дельта {head['delta']:+d} п.п. "
                     f"(в STY-% не входит; до 8.6 — только измерение и лог)\n")
    if a.control:
        lines.insert(1, f"- Контроль судьи вслепую: {a.control}"
                       f" (в термостат десяток не входит)\n")
    lines.append("- Дельта к прошлому замеру: "
                 + ("первый замер" if delta is None else
                    ", ".join(f"{STY_ROW_RU[r]} {delta[r]:+d}" for r in STY_ROWS)) + "\n")
    report("".join(lines))
    for r in STY_ROWS:
        print(f"  {STY_ROW_RU[r]:9} {rows[r]:2} | {gap_of.get(r, '—')[:60]}")
    print(f"{uid} {unit['model']} v{unit['version']}: STY-% {pct} "
          f"(планка {STY_TARGET}, сумма {sum(rows.values())}/40) "
          f"| десяток {len(tens)} | проход {a.judge_pass}")
    if notes:
        print("понижения: " + "; ".join(notes))
    if head:
        print(f"голова/фигура: эталон {head['etalon']}%, попытка {head['attempt']}%, "
              f"дельта {head['delta']:+d} п.п. (в STY-% не входит; гейтинга нет до 8.6)")
    advance_chain(unit, json.loads(SPEC.read_text()))
    save(q)
    board(a.id)
    return 0


# ------------------------------------------------------ цепочка стадий (7.4)

CYCLE_PAUSE = 2                 # цикла без движения STY-% → автопауза с меню (8.4)
CYCLE_MAX = 3                   # цикла цепочки → лучший кадр, автопродолжения нет


def chain_of(spec: dict) -> list:
    """Порядок стадий: krea2 → ernie → z-image → krea2 → … qwen21 вне цепочки (7.8)."""
    return spec.get("chain", [spec.get("model", MODEL_DEFAULT)])


def sty_last(unit: dict, model: str):
    """Последний STY-замер стадии (не последней попытки — последней правки слов)."""
    return next((h for h in reversed(unit["history"])
                 if h.get("kind") == "sty" and h["model"] == model), None)


def sty_cycle(unit: dict, model: str, cycle: int):
    """STY-% стадии в круге цепочки (несколько замеров одного круга — последний)."""
    vals = [h["sty_pct"] for h in unit["history"]
            if h.get("kind") == "sty" and h["model"] == model and h.get("cycle") == cycle]
    return max(vals) if vals else None


def ceilinged(unit: dict, model: str) -> bool:
    """Стадии, признанные потолком: требование «все три» с неё снято, молча не снимается."""
    return model in unit.get("ceilings", {})


def stage_closed(unit: dict, model: str, spec: dict) -> bool:
    """Стадия закрыта честно: её последний STY-% не ниже порога этой модели (8.3).
    Порог калибруется по эталону отдельно для каждой модели; до калибровки — планка."""
    h = sty_last(unit, model)
    return bool(h) and h["sty_pct"] >= spec.get("sty_threshold", {}).get(model, STY_TARGET)


def stage_done(unit: dict, model: str, spec: dict) -> bool:
    """Стадию больше не гоняем: порог взят либо признан потолок."""
    return stage_closed(unit, model, spec) or ceilinged(unit, model)


def stage_of(unit: dict, spec: dict):
    """Следующая стадия цепочки: первая, которая ещё не брала замер в текущем круге
    и не закрыта (порог или потолок). None — круг собран либо идти некуда."""
    cur = unit.get("cycle", 0) + 1
    for m in chain_of(spec):
        if stage_done(unit, m, spec):
            continue
        if sty_cycle(unit, m, cur) is None:
            return m
    return None


def advance_chain(unit: dict, spec: dict) -> dict | None:
    """Замыкает цикл цепочки и ставит остановки: потолок стадии, «сошлись», пауза, лимит.
    Цикл = по одному STY-замеру каждой стадии текущего круга; правка промпта
    между стадиями остаётся внутри цикла."""
    stages = chain_of(spec)
    cur = unit.get("cycle", 0) + 1
    if not all(sty_cycle(unit, m, cur) is not None for m in stages):
        return None
    got = {m: sty_cycle(unit, m, cur) for m in stages}
    unit["cycle"] = cur
    unit.setdefault("cycles", []).append({"cycle": cur, "sty": got,
                                          "mean": round(sum(got.values()) / len(got), 1)})
    cyc = unit["cycles"][-1]
    for m in stages:                      # 8.4: два круга без движения — потолок стадии
        if stage_done(unit, m, spec):
            continue
        hist = [sty_cycle(unit, m, c["cycle"]) for c in unit["cycles"]][-CYCLE_PAUSE:]
        if len(hist) == CYCLE_PAUSE and len(set(hist)) == 1:
            unit.setdefault("ceilings", {})[m] = {"sty": hist[-1], "cycle": cur}
            print(f"{unit['unit']}: {m} — {CYCLE_PAUSE} круга без движения STY-% ({hist[-1]}), "
                  f"снята с требования «все три» (model-ceiling)")
    menu = ("пауза. Меню: сменить жанровый якорь / сменить модель / признать "
            "потолок / остановить")
    if all(stage_closed(unit, m, spec) for m in stages):
        unit["status"] = "success"
        print(f"{unit['unit']}: цепочка замкнута — все три стадии не ниже своего порога "
              f"({got})")
    elif all(stage_done(unit, m, spec) for m in stages):
        unit["status"] = "paused"
        print(f"{unit['unit']}: гнать нечего — порог не взят ни одной стадией, "
              f"остальные в потолке ({got}); {menu}")
    else:
        means = [c["mean"] for c in unit["cycles"]][-CYCLE_PAUSE:]
        if len(means) == CYCLE_PAUSE and max(means) - min(means) < 1:
            unit["status"] = "paused"
            print(f"{unit['unit']}: {CYCLE_PAUSE} цикла без движения STY-% — {menu}")
        elif len(unit["cycles"]) >= CYCLE_MAX:
            unit["status"] = "blocked"
            print(f"{unit['unit']}: {CYCLE_MAX} цикла исчерпаны, кадр не принят — берётся "
                  f"лучший из прошедших, автопродолжения нет (рестарт — записью в журнал)")
    return cyc


# ------------------------------------------------------------ доска 2×2

def cnt_status(unit: dict, model: str, version: int) -> str:
    """Статус слоя CNT для кадра: точечные доводки вердикта этой попытки."""
    for h in reversed(unit["history"]):
        if "kind" in h or h.get("model") != model or h.get("version") != version:
            continue
        if h.get("head_sty"):
            return "CNT redraw"
        n = len(h.get("cnt") or [])
        return "CNT ok" if not n else f"CNT {n}"
    return "CNT ?"


def board(uid: str) -> Path | None:
    """Доска 2×2: эталон + по одному кадру каждой стадии. Ярлык в правом нижнем углу
    каждого сгенерированного кадра: `модель · STY-% · статус CNT`. Доска — отчёт по
    записям движка, глазами она не пересуживается."""
    q = load()
    if uid not in q:
        return None
    unit = q[uid]
    spec = json.loads(SPEC.read_text())
    cells = [(LAB / unit["reference"], "ЭТАЛОН", "")]
    for m in chain_of(spec):
        h = sty_last(unit, m)
        src = (LAB / h["file"]) if h and h.get("file") else \
            attempt_path(unit, m, unit["versions"].get(m, 0))
        if h:
            label = f"{m} · {h['sty_pct']}% · {cnt_status(unit, m, h['version'])}"
        else:
            label = f"{m} · STY не мерян · CNT ?" if src.is_file() else f"{m} · не прогнана"
        head = f"голова {h['head']['etalon']}→{h['head']['attempt']}" if h and h.get("head") else ""
        cells.append((src, label, head))
    side, pad, out = 512, 26, PAIRS / f"{uid}.png"
    sheet = Image.new("RGB", (side * 2 + 12, side * 2 + 12), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    for n, (src, label, head) in enumerate(cells[:4]):
        x, y = (n % 2) * (side + 12), (n // 2) * (side + 12)
        if src.is_file():
            im = Image.open(src).convert("RGB").resize((side, side), Image.LANCZOS)
        else:
            im = Image.new("RGB", (side, side), (235, 235, 235))
            d.text((x + 8, y + side // 2), f"нет кадра: {src.name}", font=FONT, fill=(120, 0, 0))
        sheet.paste(im, (x, y))
        if n:                               # ярлык — только на сгенерированных кадрах
            for k, text in enumerate(t for t in (label, head) if t):
                w = d.textlength(text, font=FONT)
                d.rectangle([x + side - w - 10, y + side - pad * (2 - k),
                             x + side - 2, y + side - pad * (1 - k) - 4], fill=(255, 255, 255))
                d.text((x + side - w - 6, y + side - pad * (2 - k) + 2), text, font=FONT,
                       fill=(0, 0, 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, quality=92)
    return out


def cmd_board(a) -> int:
    p = board(a.id)
    print(f"доска 2×2: {p}" if p else f"{a.id}: юнита в очереди нет")
    return 0 if p else 1


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
    # история — смешанный журнал (STY-замеры и вердикты readiness не имеют),
    # дельта считается к последнему замеру готовности, а не к последней записи
    prev = next((h["readiness"] for h in reversed(unit["history"]) if "readiness" in h),
                None)
    if not unit.get("file"):
        raise SystemExit("кадра нет — сначала next")
    if not unit.get("seal"):
        raise SystemExit("прогон не запечатан: состав прогона не записан до рендера, "
                         "балл не ставится (`next` печатает сам, сверка — `verify`)")
    unit["history"].append({"version": unit["version"], "model": unit["model"], "date": str(date.today()),
                            "file": unit.get("file"), "seal": unit["seal"],
                            "scores": scores, "readiness": pct,
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


def cmd_verify(a) -> int:
    """Сверка печати прогона с тем, что в дереве сейчас. Расхождение — печать
    снимается: кадр, нарисованный другим промптом/словарём/прибором, этим баллом
    не описывается."""
    q = load()
    uid, unit = a.id, q[a.id]
    stored = unit.get("seal")
    if not stored:
        print(f"{uid}: печати нет — прогон без неё не считается, нужен новый `next`")
        return 1
    now = run_seal(unit, unit["model"], unit["version"], json.loads(SPEC.read_text()))
    diff = sorted(k for k in now if now[k] != stored.get(k))
    if diff:
        unit.pop("seal")
        save(q)
        print(f"{uid}: печать снята, разошлось {', '.join(diff)} — прогон не воспроизведён")
        return 1
    print(f"{uid}: печать совпала\n" + json.dumps(stored, ensure_ascii=False, indent=1))
    return 0


def cmd_verdict(a) -> int:
    """Вердикт попытки парным тестом к якорю. Приёмка только по нему; проценты — статистика.

    Флаг обязан объявить слой: `--sty` и `--head-sty` — стиль, они блокируют;
    `--cnt` — контент, журнал ручной доводки, не блокирует, кроме экономического
    порога; `--ident` — похожесть, отдельный слой: пишется, но не блокирует никогда
    (текстовым промптом не управляется, рычаг — референс-кондишенинг).
    """
    q = load()
    uid, unit = a.id, q[a.id]
    if a.sty not in STY_VERDICTS:
        raise SystemExit(f"вердикт: {', '.join(STY_VERDICTS)}")
    if not unit.get("file"):
        raise SystemExit("кадра нет — сначала next")
    ver = etalon_version()
    if not ETALONS.is_file():
        raise SystemExit(f"нет манифеста эталонов {ETALONS} — jobloop.py etalons")
    booked = json.loads(ETALONS.read_text())["version"]
    if booked != ver:
        raise SystemExit(f"эталонный сет изменился: заявлено {booked}, на диске {ver} — "
                         f"сверь кропы и пересобери манифест")
    cnt, ident = a.cnt or [], a.ident or []
    status = "success" if a.sty == "yes" else "in-queue"
    why = ""
    if status == "in-queue" and (a.head_sty or len(cnt) > CNT_FIXUP_MAX):
        status, why = "redraw", "стиль лица или кисти" if a.head_sty else f"правок {len(cnt)} > {CNT_FIXUP_MAX}"
    same = [h for h in unit["history"] if h.get("ident") and h["model"] == unit["model"] and h["sty"] == a.sty]
    ceiling = bool(ident) and len(same) >= 1
    unit["history"].append({"version": unit["version"], "model": unit["model"], "date": str(date.today()),
                            "file": unit["file"], "sty": a.sty, "sty_notes": a.sty_notes or [],
                            "cnt": cnt, "ident": ident, "head_sty": bool(a.head_sty),
                            "identity_ceiling": ceiling, "etalons": ver,
                            "prompt_version": unit.get("prompt_version"),
                            "render_version": unit.get("render_version"),
                            "prompt_ceiling": a.ceiling,
                            "readiness": None, "note": a.note or ""})
    unit["status"] = status
    if status != "success" and a.ceiling:
        unit["status"] = status = "model-ceiling"
        why = f"промпт упёрся в признак: {a.ceiling}"
    elif status != "success" and unit["versions"][unit["model"]] >= MAX_ATTEMPTS:
        unit["status"] = status = "blocked"
        why = f"исчерпан лимит {MAX_ATTEMPTS} попыток"
    save(q)
    if cnt:
        with (DOCS / "fixups.md").open("a") as fh:
            fh.write(f"\n## {uid} {unit['model']} v{unit['version']} — {unit['file']}\n")
            fh.writelines(f"- {c}\n" for c in cnt)
    if ident:
        with (DOCS / "identity.md").open("a") as fh:
            fh.write(f"\n## {uid} {unit['model']} v{unit['version']} — {unit['file']}\n"
                     + "".join(f"- {i}\n" for i in ident)
                     + ("- `identity-ceiling`: похожесть не двигается промптом — "
                        "рычаг референс-кондишенинга, не перерисовка\n" if ceiling else ""))
    report(f"## {date.today()} {uid} v{unit['version']} | {unit['model']} "
           f"| {unit.get('prompt_version', 'P?')}{unit.get('render_version', 'R?')} | стиль: {a.sty}"
           f"{f' -> {status} ({why})' if why else ''}\n"
           f"- Файл: {unit['file']}\n- Эталоны: {ver}\n"
           f"- Метрика-подсказка: {unit.get('metric', '—')}\n"
           f"- Стиль ({len(a.sty_notes or [])}): {'; '.join(a.sty_notes or []) or '—'}\n"
           f"- Точечные правки ({len(cnt)}): {'; '.join(cnt) or '—'}\n"
           f"- Похожесть ({len(ident)}){' — потолок, не блокирует' if ceiling else ''}: "
           f"{'; '.join(ident) or '—'}\n"
           f"- Заметка: {a.note or '—'}\n")
    if status == "success":
        src = LAB / unit["file"]
        MATCHES.mkdir(parents=True, exist_ok=True)
        dst = MATCHES / src.name
        shutil.copy(src, dst)
        report(f"ИТОГ: ✅ success — {uid} за {unit['versions'][unit['model']]} попыток "
               f"({unit['model']}) → {dst.name}\n")
        print(f"{uid} принят (стиль: та же рука) -> {dst}")
    else:
        print(f"{uid} v{unit['version']}: стиль {a.sty} -> {status}"
              + (f" ({why})" if why else "") + f", точечных правок {len(cnt)}")
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


def split_style(style: str) -> tuple[str, str]:
    """Стилевой блок на плюс и минус: минус начинается с первого `no `."""
    i = style.find(", no ")
    return (style, "") if i < 0 else (style[:i], style[i + 1:])


NEG_RE = re.compile(r"\b(no|not|without|never|без)\b")
JUDGE_CLASSES = ("independent", "semi-blind", "self")


def card_cells(card: str):
    r"""Ячейки строк словаря: (признак, [формулировки]). Только нумерованные
    секции (журнал отрицаний — не словарь), без отменённых, только ячейка
    формулировки — источник с цитатами старых отрицаний мерить нельзя.
    Разделитель ячеек — неэкранированная вертикаль, `\|` внутри ячейки экранирован.
    Формулировок больше одной = слот (выбор одного), а не конъюнкция."""
    for sec in ("\n" + card).split("\n## ")[1:]:
        if not sec[:1].isdigit():
            continue
        for line in sec.splitlines():
            c = [x.strip() for x in re.split(r"(?<!\\)\|", line.strip().strip("|"))]
            if len(c) != 3 or "~~" in line or "`" not in c[1]:
                continue
            yield c[0], [f.strip() for f in c[1].split("`")[1::2]]


def card_rows(card: str) -> list[tuple[str, str]]:
    return [(n, f) for n, forms in card_cells(card) if len(forms) == 1 for f in forms]


def card_slots(card: str) -> list[list[str]]:
    """Слоты словаря: выбор ровно одного (жанровый якорь и т.п.)."""
    return [forms for _, forms in card_cells(card) if len(forms) > 1]


def card_phrases(card: str) -> list[str]:
    return [f for _, f in card_rows(card)]


def lint_card(card: str) -> list[str]:
    """Словарь меряется строже задачи: источник чище потребителя."""
    out = []
    for name, form in card_rows(card):
        neg = sorted({m.group(0) for m in NEG_RE.finditer(form.lower())})
        if neg:
            out.append(f"строка словаря с отрицанием ({', '.join(neg)}): {name!r} — "
                       f"«{form}»; мера читается с 10-якоря строки, запрет "
                       f"формулируется положительно")
    return out


def lint_style(style: str, card: str) -> list[str]:
    """Правила стилевого блока: токен не живёт в двух половинах, строка словаря
    обязана иметь якорь в плюсе. Нарушение = находка, а не падение."""
    plus, minus = split_style(style)
    low, out = plus.lower(), []
    neg = sorted({m.group(0) for m in NEG_RE.finditer(style.lower())})
    if neg:
        out.append("лексическое отрицание в задаче (" + ", ".join(neg) + "): живой "
                   "отрицательной ветки нет ни у одной стадии, эти слова уходят в "
                   "положительный промпт — прецедент P0: \"no ink outlines\" снял "
                   "главный носитель стиля; запрет формулируется положительно")
    for clause in minus.lower().replace("no ", "").split(","):
        w = clause.strip()
        if len(w) > 3 and w in low:
            out.append(f"токен {w!r} стоит в плюсе и в минусе одновременно")
    for phrase in card_phrases(card):
        if phrase.lower() not in low:
            out.append(f"строка словаря без якоря в плюсе: {phrase!r}")
    for opts in card_slots(card):
        hit = [o for o in opts if o.lower() in low]
        if len(hit) > 1:
            out.append("смешаны якоря слота (" + ", ".join(repr(h) for h in hit) +
                       "): ровно один на версию, иначе вердикт нельзя приписать слову")
    return sorted(set(out))


def cmd_lint(a) -> int:
    style = json.loads(SPEC.read_text())["variants"][0]["style"]
    card = (DOCS / "style-card.md").read_text()
    bad = lint_style(style, card) + lint_card(card)
    for b in bad:
        print(f"- {b}")
    print(f"нарушений {len(bad)}")
    return 0


def figure_bbox(im: Image.Image, cell: tuple[int, int, int, int],
                gutter: int = 80, margin: int = 12) -> tuple[int, int, int, int]:
    """Бокс фигуры, а не ячейки: сетка референса режется по ровным колонкам,
    рука соседа лезет в кадр, а своя рука лезет за край ячейки.

    Фигура = связный компонент ненугового содержимого, чей центр тяжести лежит
    в ячейке. Рука, перегнувшая за границу, остаётся своей (центр тяжести в
    теле), кисть соседа — чужой.
    """
    from scipy import ndimage
    a = np.asarray(im.convert("L"), dtype=np.uint8)
    x0, y0, x1, y1 = cell
    win = (max(0, x0 - gutter), max(0, y0 - gutter),
           min(a.shape[1], x1 + gutter), min(a.shape[0], y1 + gutter))
    lab, n = ndimage.label(a[win[1]:win[3], win[0]:win[2]] < INK_MAX)
    boxes = []
    for i in range(1, n + 1):
        ys, xs = np.where(lab == i)
        if len(ys) < 200:
            continue
        cx, cy = xs.mean() + win[0], ys.mean() + win[1]
        if x0 <= cx < x1 and y0 <= cy < y1:
            boxes.append((xs.min() + win[0], ys.min() + win[1],
                          xs.max() + win[0], ys.max() + win[1]))
    if not boxes:
        return cell
    return (max(0, min(b[0] for b in boxes) - margin),
            max(0, min(b[1] for b in boxes) - margin),
            min(a.shape[1], max(b[2] for b in boxes) + margin),
            min(a.shape[0], max(b[3] for b in boxes) + margin))


def cmd_cut(a) -> int:
    """Перерезать кропы по боксу фигуры и пересобрать манифест эталонов."""
    from scipy import ndimage                                    # noqa: F401
    q = load()
    for uid, unit in sorted(q.items()):
        sheet = Image.open(LAB / unit["sheet"])
        cols, rows = GRID                                   # GRID = (колонок, рядов)
        idx = unit["cell"] - 1                              # cell в очереди 1-базируется
        r, c = idx // cols, idx % cols
        cw, ch = sheet.width // cols, sheet.height // rows
        cell = (c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)
        box = figure_bbox(sheet, cell)
        fig = sheet.crop(box)
        side = max(fig.size)
        canvas = Image.new("RGB", (side, side), "white")
        canvas.paste(fig, ((side - fig.width) // 2, (side - fig.height) // 2))
        out = LAB / unit["reference"]
        out.parent.mkdir(parents=True, exist_ok=True)
        canvas.save(out)
        print(f"{uid}: ячейка {cell} -> фигура {box} ({side}px)")
    return cmd_etalons(None)


def cmd_reopen(a) -> int:
    """Снять вердиктный статус: потолок отозван, юнит снова в работе."""
    q = load()
    unit = q[a.id]
    if unit["status"] in ("success",):
        raise SystemExit("принятый юнит не открывается командой reopen — сначала отзыв приёмки")
    prev = unit["status"]
    unit["status"] = OPEN[0]
    unit["lifted"] = sorted(unit.get("ceilings", {}))   # что именно возвращено в гонку
    unit.pop("ceilings", None)   # потолок отозван — стадии снова в гонке, иначе reopen пуст
    save(q)
    report(f"## {date.today()} {a.id} — статус {prev} снят, юнит снова в очереди\n"
           f"- Причина: {a.note or '—'}\n"
           f"- Потолки стадий сняты: {', '.join(unit.get('lifted') or []) or 'все'}\n")
    print(f"{a.id}: {prev} -> {OPEN[0]}")
    return 0


def cmd_stat(_a) -> int:
    require_anchors()
    q = load()
    tally = {}
    for u in q.values():
        tally[u["status"]] = tally.get(u["status"], 0) + 1
    print(f"всего {len(q)}: " + ", ".join(f"{k}={v}" for k, v in sorted(tally.items())))
    by_model = {}
    for u in q.values():
        for h in u["history"]:
            if h.get("readiness") is not None:
                by_model.setdefault(h["model"], []).append((h["readiness"], u["version"]))
    tens = total = 0
    for u in q.values():
        for h in u["history"]:
            if h.get("rows") and not h.get("control"):   # контроли — не попытки
                total += len(h["rows"])
                tens += sum(1 for v in h["rows"].values() if v == 10)
    if total:
        print(f"\nдесятки: {tens}/{total} ({100 * tens / total:.0f} %) — термостат "
              f"якорных пар: доля растёт => якоря поплыли, перекалибровка")
    print("\nмодель | средний % | средние попытки | замеров")
    for model, rows in sorted(by_model.items()):
        n = len(rows)
        print(f"  {model:8} {sum(r[0] for r in rows) / n:6.1f} "
              f"{sum(r[1] for r in rows) / n:8.1f} {n:8}")
    open_ = [u for u in sorted(q) if q[u]["status"] in OPEN]
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
    n.add_argument("--id", default=None, help="взять в работу конкретный юнит, а не первый открытый")
    n.set_defaults(f=cmd_next)
    e = sub.add_parser("etalons")
    e.set_defaults(f=cmd_etalons)
    vf = sub.add_parser("verify", help="сверить печать прогона с деревом")
    vf.add_argument("id")
    vf.set_defaults(f=cmd_verify)
    sc = sub.add_parser("score")
    sc.add_argument("id")
    sc.add_argument("criteria", nargs="+")
    sc.add_argument("--note", default="")
    sc.set_defaults(f=cmd_score)
    an = sub.add_parser("anchors")
    an.add_argument("what", choices=("stat", "check", "show", "score", "blind", "seal", "brief"))
    an.add_argument("id", nargs="?")
    an.add_argument("mark", nargs="?")
    an.add_argument("--pass", dest="judge_pass", choices=("score", "revision"),
                    default="revision")
    an.add_argument("--judge", default="", help="кто судил (имя или id сессии)")
    an.add_argument("--class", dest="klass", choices=JUDGE_CLASSES,
                    help="independent | semi-blind | self (floor-check)")

    st = sub.add_parser("sty")
    st.add_argument("id")
    st.add_argument("rows", nargs="+", help="line=9 color=10@AP-line-2 ... (все четыре)")
    st.add_argument("--gap", action="append", help="row=названное расхождение")
    st.add_argument("--pass", dest="judge_pass", choices=("score", "revision"),
                    default="score", help="какой судейский проход даёт эти числа")
    st.add_argument("--control", help="AP-id вслепую вставленной контрольной пары")
    st.add_argument("--head-ratio", dest="head_ratio",
                    help="пропорции головы эталон/попытка, напр. 17/15 (в STY-% не входит)")


    vd = sub.add_parser("verdict")
    vd.add_argument("id")
    vd.add_argument("sty", choices=STY_VERDICTS)
    vd.add_argument("--sty-note", dest="sty_notes", action="append",
                    help="расхождение стиля со ссылкой на строку словаря (повторяемо)")
    vd.add_argument("--cnt", action="append", help="точечная правка слоя контента (повторяемо)")
    vd.add_argument("--ident", action="append",
                    help="расхождение похожести: журнал, приёмку не блокирует (повторяемо)")
    vd.add_argument("--head-sty", dest="head_sty", action="store_true",
                    help="линия или светотень лица/кистей расходится — это стиль, он блокирует")
    vd.add_argument("--note", default="")
    vd.add_argument("--ceiling", default="",
                    help="признак, в который упёрся промпт (gloss, line…): "
                         "правками слов на этом юните больше не двигается")
    st.set_defaults(f=cmd_sty)
    an.set_defaults(f=cmd_anchors)
    vd.set_defaults(f=cmd_verdict)
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
    bd = sub.add_parser("board", help="доска 2×2: эталон + по кадру каждой стадии")
    bd.add_argument("id")
    bd.set_defaults(f=cmd_board)
    sub.add_parser("cut", help="перерезать кропы по боксу фигуры").set_defaults(f=cmd_cut)
    sub.add_parser("lint", help="проверить стилевой блок словарём стиля").set_defaults(f=cmd_lint)
    ro = sub.add_parser("reopen", help="снять статус потолка или блокировки")
    ro.add_argument("id")
    ro.add_argument("--note", default="")
    ro.set_defaults(f=cmd_reopen)
    args = ap.parse_args()
    return args.f(args)


if __name__ == "__main__":
    sys.exit(main())

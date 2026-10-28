#!/usr/bin/env python3
"""Генератор концепт-арта: 5 вариантов стиля × 77 сюжетов через ComfyUI.

Каталог сюжетов и стилей — spec.json рядом с этим файлом, кода там нет (см. дельта-спеку
`concept-art-pipeline`). Прогон возобновляем: существующие файлы пропускаются, затравка
выводится из идентификатора артефакта, поэтому повтор рисует то же самое.

Имя кадр задаётся до запуска: граф уходит на сервер с `filename_prefix` узла
сохранения, поэтому локально файл рождается итоговым и ничего не переименовывается.
Заготовки графов — workflows.json рядом (роли узлов ищутся по `class_type`).

    python3 scripts/concept_art/generate.py --dry-run
    python3 scripts/concept_art/generate.py --variant v1_candlelight --only cursor_default
    python3 scripts/concept_art/generate.py                 # полный прогон
    python3 scripts/concept_art/generate.py --sheet         # контактные листы
"""
from __future__ import annotations

import argparse
import binascii
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
SPEC_PATH = HERE / "spec.json"
WORKFLOWS_PATH = HERE / "workflows.json"
WORKFLOWS = json.loads(WORKFLOWS_PATH.read_text())   # заготовки графов ComfyUI по моделям
WHITE_MIN = 0.60          # доля почти-белого в рамке для изолированных категорий
NEAR_WHITE = 235          # порог «белый»: фон образца — 1% чистого и 98% почти-белого
BORDER = 24               # ширина рамки, px
CONTENT_MIN = 0.02        # в центральном окне 50% обязана быть картинка, а не пустой белый лист
SEAM_MAX = 250              # строка пуста, если её средняя яркость не ниже (фон 255, тень ~200)
SEAM_SIDE = 0.02            # ...и по обе стороны разрыва не меньше 2 % контента
SEAM_GAP = 0.003            # разрыв от 4 px (0,3 % высоты) — это лист, а не фигура. По 31
                            # кадру калибровки и 12 кроям эталона пустых полос нет вовсе (0.0),
                            # а два настоящих листа-обманки дают 0.005 и 0.012
LUMA_RANGE = (25, 235)    # средняя яркость кадров без требования белого фона (экраны UI)
ISOLATED = ("units", "buildings", "signs", "cursors", "resources", "plates", "emblems", "glyphs")
TERMINAL_BAD = ("error", "not_found", "canceled")


# ---------------------------------------------------------------- каталог

def load_spec(path: Path = SPEC_PATH) -> dict:
    spec = json.loads(Path(path).read_text())
    raw = str(spec.get("references_dir", ""))
    # Путь эталонного сета относительный — от корня репозитория, а не от рабочей папки:
    # калибровка не должна зависеть от того, откуда запущен прогон.
    refs = Path(raw) if Path(raw).is_absolute() else ROOT / raw
    if not refs.is_dir():
        raise SystemExit(f"spec: нет каталога эталонов references_dir={spec.get('references_dir')!r}")
    spec["_references"] = refs
    for cat, c in spec["categories"].items():
        for key in ("style", "reference"):
            if not c.get(key):
                raise SystemExit(f"spec: категория {cat}: нет поля {key} (кадр обязан повторять эталон)")
        if not (refs / c["reference"]).is_file():
            raise SystemExit(f"spec: категория {cat}: эталон {c['reference']} не найден в {refs}")
        n = len(c["items"])
        if n != c["count"]:
            raise SystemExit(f"spec: категория {cat}: count={c['count']} != items={n}")
        ids = [i["id"] for i in c["items"]]
        if len(set(ids)) != n:
            raise SystemExit(f"spec: категория {cat}: дублируются id")
    for v in spec["variants"]:
        for key in ("id", "style"):
            if key not in v:
                raise SystemExit(f"spec: в варианте {v.get('id', '?')} нет поля {key}")
    # Пастбище граблей: слои запроса — style категории → style варианта → frame категории →
    # subject. Глобальных полей у каталога нет; четыре раунда калибровки правили spec["base"]
    # и spec["negative"], которые никто не читал, и всё это время модель получала
    # «tall slender build, head one seventh» из style категории.
    for dead in ("base", "negative"):
        if dead in spec:
            raise SystemExit(f"spec: поле {dead} верхнего уровня не читается генератором — "
                             f"прави style/frame категории и negative варианта")
    r = spec.get("render", {})
    if r:
        miss = [k for k in ("id", "model", "cfg", "sampler", "scheduler", "steps", "checkpoint")
                if k not in r]
        if miss:
            raise SystemExit(f"spec: в render нет {', '.join(miss)} — блок читается сэмплером")
        if r.get("checkpoint") != spec["models"].get(r.get("model", ""), {}).get("unet"):
            raise SystemExit("spec: render.checkpoint не совпадает с unet модели "
                             f"{r.get('model')} — печать приписала бы вес, которого не грузили")
    for key in ("model", "probe_models"):
        if not spec.get(key):
            raise SystemExit(f"spec: нет поля {key} — модель выбирается прогоном, не категорией")
    for m in [spec["model"], *spec["probe_models"]]:
        if m not in spec["models"]:
            raise SystemExit(f"spec: модели {m} нет в реестре models")
    return spec


def seed_for(variant: str, cat: str, item_id: str) -> int:
    return binascii.crc32(f"{variant}/{cat}/{item_id}".encode()) % (2**31)


def seed_of(spec: dict, art: dict, attempt: int = 1) -> int:
    """Затравка кадра. spec.seed (лаборатория: 43) пинит её на всех стадиях: кадр при
    одном (P, R) обязан выходить побайтово одинаковым, перевыпуск делается правкой
    слов, а не сидом. Без spec.seed — старая выводимая затравка конвейера ассетов."""
    if "seed" in spec:
        return int(spec["seed"])
    return (seed_for(art["variant"], art["category"], art["id"]) + (attempt - 1)
            + int(art.get("seed_bump", 0)))


def build_prompt(variant: dict, cat: dict, item: dict, negative_param: bool) -> tuple[str, str]:
    """(prompt, negative). Слои: стиль эталона категории -> техника варианта -> кадр -> сюжет.

    Стиль категории — словесное описание эталона, он держит семейство; вариант двигает только
    технику рендера. У Krea-2 нет параметра негатива — негатив дописывается в конец запроса."""
    prompt = ", ".join([cat["style"], variant["style"], cat["frame"], item["subject"]])
    neg = variant.get("negative", "")
    if neg and not negative_param:
        prompt = f"{prompt}, no {neg}"
        neg = ""
    return prompt, neg


def artifacts(spec: dict, variants=None, categories=None, only=None, model: str = "") -> list[dict]:
    """Артефакты одного прогона. Модель — уровень прогона, а не категории: один и тот же промпт
    обязан прогоняться и в Krea-2, и в Qwen 2.1, поэтому модель сидит в пути вывода."""
    out = []
    for v in spec["variants"]:
        if variants and v["id"] not in variants:
            continue
        for cname, c in spec["categories"].items():
            if categories and cname not in categories:
                continue
            for item in c["items"]:
                if only and item["id"] not in only:
                    continue
                out.append({
                    "variant": v["id"], "category": cname, "id": item["id"],
                    "subject": item["subject"], "model_key": model,
                    "seed_bump": item.get("seed_bump", 0),
                    "size": tuple(c["size"]),
                    "path": Path(spec["out_dir"]) / model / v["id"] / cname / f"{item['id']}.webp",
                })
    return out


# ------------------------------------------------------------- проверки

def white_ratio(im: Image.Image, border: int = BORDER, thr: int = NEAR_WHITE) -> float:
    """Доля почти-белого (все каналы >= thr) в рамке заданной ширины."""
    rgb = im.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    total = hits = 0
    for x in range(0, w, 2):
        for y in list(range(0, min(border, h), 2)) + list(range(max(0, h - border), h, 2)):
            total += 1
            hits += min(px[x, y]) >= thr
    for y in range(0, h, 2):
        for x in list(range(0, min(border, w), 2)) + list(range(max(0, w - border), w, 2)):
            total += 1
            hits += min(px[x, y]) >= thr
    return hits / total if total else 0.0


def content_ratio(im: Image.Image) -> float:
    """Доля не-белых пикселей в центральном окне 50% — признак того, что объект нарисован."""
    rgb = im.convert("RGB")
    w, h = rgb.size
    x0, y0, x1, y1 = w // 4, h // 4, w * 3 // 4, h * 3 // 4
    crop = rgb.crop((x0, y0, x1, y1))
    px = crop.load()
    total = hits = 0
    for x in range(0, crop.size[0], 2):
        for y in range(0, crop.size[1], 2):
            total += 1
            hits += px[x, y] != (255, 255, 255)
    return hits / total if total else 0.0


def mean_luma(im: Image.Image) -> float:
    g = im.convert("L")
    hist = g.histogram()
    n = g.size[0] * g.size[1]
    return sum(i * c for i, c in enumerate(hist)) / n


def seam_ratio(im: Image.Image, thr: int = SEAM_MAX) -> float:
    """Доля самого длинного пустого разрыва, делённая на высоту кадра.

    Одиночная фигура не имеет права быть рассечённой горизонтальной белой полосой: если между
    двумя кусками контента есть разрыв хотя бы в 1,5 % высоты, это лист (Krea-2 на c11 выдала
    сетку 2×2, на c08 — полосу из шести превью под ногами) и воротчик белизны такой кадр
    пропускает, потому что фон белый.

    Строки считаются на полной высоте: ужатие до 64 строк съедало шов в 10 px и c08 прошла.
    Массой контента шв не меряют — полоса превью весит 10 % и проходила порог в 15 %.
    Проверяются строки, а не колонки: фигура с посохом даёт пустую колонку и в эталоне."""
    g = im.convert("L")
    w, h = g.size
    means = list(g.resize((1, h), Image.BOX).getdata())      # среднее яркости строки
    empty = [m >= thr for m in means]
    content = [max(0, thr - m) for m in means]               # 0 у пустой строки
    total = sum(content)
    if not total:
        return 0.0
    above, best, run = 0.0, 0, 0
    for y, (is_empty, c) in enumerate(zip(empty, content)):
        if is_empty:
            run += 1
            continue
        below = total - above - c
        if run and min(above, below) / total >= SEAM_SIDE and run > best:
            best = run                                       # разрыв только с контентом с обеих сторон
        run, above = 0, above + c
    return best / h


def check_image(path: Path, size: tuple[int, int], isolated: bool) -> tuple[bool, str]:
    try:
        im = Image.open(path)
        im.load()
    except Exception as exc:                                  # noqa: BLE001
        return False, f"не декодируется: {exc}"
    if im.size != tuple(size):
        return False, f"размер {im.size[0]}x{im.size[1]} != {size[0]}x{size[1]}"
    if isolated:
        ratio = white_ratio(im)
        if ratio < WHITE_MIN:
            return False, f"почти-белого в рамке {ratio:.0%} < {WHITE_MIN:.0%}"
        content = content_ratio(im)
        if content < CONTENT_MIN:
            return False, f"центр пустой: не-белого {content:.1%} < {CONTENT_MIN:.0%}"
        seam = seam_ratio(im)
        if seam > SEAM_GAP:
            return False, (f"кадр разрезан пустой "
                           f"полосой {seam:.1%} высоты — лист с вариантами?")
    else:
        luma = mean_luma(im)
        if not LUMA_RANGE[0] <= luma <= LUMA_RANGE[1]:
            return False, f"средняя яркость {luma:.0f} вне {LUMA_RANGE}"
    return True, ""


# -------------------------------------------------------------- сервер

def http_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.loads(r.read())


def http_bytes(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=180) as r:
        return r.read()


def workflow(model_key: str, spec_model: dict, art: dict, prompt: str, neg: str,
             seed: int, server_name: str, render: dict | None = None) -> dict:
    """Заготовка графа ComfyUI с подставленными параметрами.

    Имя кадр получает здесь, до запуска: узел сохранения пишет файл сам, и
    локально его не нужно переименовывать. Роли узлов ищутся по `class_type`,
    а не по номерам, — перенумерация графа на сервере прогон не ломает.
    """
    g = json.loads(json.dumps(WORKFLOWS[model_key]))
    for node in g.values():
        ct, i = node["class_type"], node["inputs"]
        if ct == "CLIPTextEncode":
            i["text"] = prompt
        elif ct == "TextEncodeQwenImage21":
            i["prompt"] = prompt
            if neg:
                i["negative_prompt"] = neg
        elif ct.startswith("Empty") and ct.endswith("LatentImage"):
            # EmptyLatentImage / EmptyFlux2LatentImage / EmptySD3LatentImage — у каждой
            # своей чекпоинт свой латентный узел, размеры подставляются в любой из них.
            i.update({"width": art["size"][0], "height": art["size"][1]})
        elif ct == "KSampler":
            # cfg, шаги и сэмплер принадлежат модели, R-блок докручивает то, чего
            # модель не знает: turbo-стадии (krea2/ernie/z-image) размечены на
            # cfg 1.0 / 8 шагов, а R1 — наследие qwen21 (cfg 3.0 / 25). Прежний
            # порядок (R поверх модели) гнал каждую стадию чужим рендером.
            r = render or {}
            i.update({"seed": seed,
                      "steps": spec_model.get("steps", r.get("steps", 20)),
                      "cfg": spec_model.get("cfg", r.get("cfg", 1.0)),
                      "sampler_name": spec_model.get("sampler", r.get("sampler", "euler")),
                      "scheduler": r.get("scheduler", "simple")})
        elif ct == "SaveImage":
            i["filename_prefix"] = server_name
    return g


def run_job(comfy: str, graph: dict, timeout: int) -> dict:
    """Задание на сервер и ожидание: возвращает запись файла, которую записал SaveImage."""
    req = urllib.request.Request(f"{comfy}/prompt", data=json.dumps({"prompt": graph}).encode(),
                                 headers={"Content-Type": "application/json"})
    pid = json.load(urllib.request.urlopen(req))["prompt_id"]
    t0 = time.time()
    while True:
        hist = http_json(f"{comfy}/history/{pid}")
        imgs = [i for o in hist.get(pid, {}).get("outputs", {}).values() for i in o.get("images", [])]
        if imgs:
            return imgs[0]
        if time.time() - t0 > timeout:
            raise TimeoutError(f"ожидание > {timeout} c (задание {pid})")
        time.sleep(5)


def download(comfy: str, img: dict, dest: Path) -> None:
    q = urllib.parse.urlencode({"filename": img["filename"], "subfolder": img.get("subfolder", ""),
                                "type": img.get("type", "output")})
    dest.write_bytes(http_bytes(f"{comfy}/view?{q}"))


def to_webp(src: Path, dest: Path, quality: int) -> None:
    im = Image.open(src).convert("RGB")
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, "WEBP", quality=quality)


def generate(spec: dict, art: dict, timeout: int, attempt: int = 1,
             server_name: str = "") -> dict:
    """Один сюжет: граф с готовым именем -> ожидание -> загрузка -> экспорт -> проверки."""
    t0 = time.time()
    m = spec["models"][art["model_key"]]
    variant = next(v for v in spec["variants"] if v["id"] == art["variant"])
    cat = spec["categories"][art["category"]]
    # Живой негатив только там, где граф действительно ведёт его на сэмплер. В krea2
    # negative замкнут на positive, в ernie/z-image обнулён ConditioningZeroOut — текст
    # там мёртв, запрет переезжает в конец положительного промпта.
    negative_param = m.get("negative", "zeroed") == "param"
    prompt, neg = build_prompt(variant, cat, art, negative_param)
    seed = seed_of(spec, art, attempt)
    server_name = server_name or f"{art['model_key']}/{art['variant']}/{art['category']}/{art['id']}"
    img = run_job(spec["comfy"], workflow(art["model_key"], m, art, prompt, neg, seed, server_name,
                                         spec.get("render", {})),
                  timeout)

    out = art["path"]
    tmp = out.with_suffix(".part.png")
    tmp.parent.mkdir(parents=True, exist_ok=True)
    download(spec["comfy"], img, tmp)
    to_webp(tmp, out, spec["export"]["quality"])
    tmp.unlink(missing_ok=True)
    ok, why = check_image(out, art["size"], art["category"] in ISOLATED)
    return {"verdict": "ok" if ok else "fail", "error": why, "seed": seed,
            "model": art["model_key"], "checkpoint": m["unet"], "prompt": prompt,
            "negative_prompt": neg, "size": list(art["size"]),
            "server_file": f"{img.get('subfolder', '')}/{img['filename']}".strip("/").replace("\\", "/"),
            "seconds": round(time.time() - t0, 1), "file": str(out)}


# ------------------------------------------------------------- листы

def _cell(path: Path, box: int, caption: str) -> Image.Image:
    c = Image.new("RGB", (box, box + 18), (245, 245, 245))
    if path.exists():
        im = Image.open(path).convert("RGB")
        im.thumbnail((box, box))
        c.paste(im, ((box - im.size[0]) // 2, 0))
    ImageDraw.Draw(c).text((3, box + 2), caption[:40], fill=(20, 20, 20))
    return c


def contact_sheets(spec: dict, out_root: Path, model: str) -> list[Path]:
    """Матрица «вариант × категория» и по листу на вариант со всеми сюжетами."""
    made = []
    out_root.mkdir(parents=True, exist_ok=True)
    cats = list(spec["categories"])
    box = 220
    m = Image.new("RGB", (box * (len(cats) + 1), box * len(spec["variants"]) + 18), (255, 255, 255))
    d = ImageDraw.Draw(m)
    for j, cname in enumerate(cats):
        d.text((box * (j + 1) + 3, 2), cname, fill=(0, 0, 0))
    for i, v in enumerate(spec["variants"]):
        d.text((3, box * (i + 1) + 2), v["id"], fill=(0, 0, 0))
        for j, cname in enumerate(cats):
            items = spec["categories"][cname]["items"]
            p = out_root / model / v["id"] / cname / f"{items[0]['id']}.webp"
            m.paste(_cell(p, box, ""), (box * (j + 1), box * (i + 1)))
    p = out_root / "sheet_matrix.webp"
    m.save(p, "WEBP", quality=88)
    made.append(p)

    for v in spec["variants"]:
        cells = [(out_root / model / v["id"] / cname / f"{it['id']}.webp", f"{cname}/{it['id']}")
                 for cname, c in spec["categories"].items() for it in c["items"]]
        cols = 8
        rows = -(-len(cells) // cols)
        s = Image.new("RGB", (box * cols, (box + 18) * rows), (255, 255, 255))
        for n, (cp, cap) in enumerate(cells):
            s.paste(_cell(cp, box, cap), (box * (n % cols), (box + 18) * (n // cols)))
        p = out_root / f"sheet_{v['id']}.webp"
        s.save(p, "WEBP", quality=88)
        made.append(p)
    return made


def style_board(spec: dict, out_root: Path, model: str) -> Path:
    """Борд стиля: строка = категория, первая ячейка — эталон категории, дальше все варианты.

    Нужен ровно для одного вопроса: повторяет ли кадр стиль своего эталона. Сравнение
    «вариант с вариантом» без эталона на нём невозможно."""
    box = 420
    cats = list(spec["categories"])
    cols = len(spec["variants"]) + 1
    b = Image.new("RGB", (box * cols, (box + 18) * len(cats)), (255, 255, 255))
    for i, cname in enumerate(cats):
        c = spec["categories"][cname]
        b.paste(_cell(spec["_references"] / c["reference"], box, f"ЭТАЛОН: {c['reference'][:30]}"),
                (0, (box + 18) * i))
        for j, v in enumerate(spec["variants"], 1):
            it = c["items"][0]
            b.paste(_cell(out_root / model / v["id"] / cname / f"{it['id']}.webp", box, v["id"]),
                    (box * j, (box + 18) * i))
    p = out_root / f"board_style_{model}.webp"
    b.save(p, "WEBP", quality=90)
    return p


# ---------------------------------------------------------------- main

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--spec", default=str(SPEC_PATH))
    ap.add_argument("--variant", help="список id вариантов через запятую")
    ap.add_argument("--category", help="список категорий через запятую")
    ap.add_argument("--only", help="список id сюжетов через запятую")
    ap.add_argument("--force", action="store_true", help="перегенеровать существующее")
    ap.add_argument("--dry-run", action="store_true", help="только перечислить артефакты")
    ap.add_argument("--sheet", action="store_true", help="собрать контактные листы и выйти")
    ap.add_argument("--probe", action="store_true",
                    help="стилевой борд: по одному сюжету каждой категории во всех вариантах и во всех "
                         "моделях из probe_models + борд с эталонами на каждую модель")
    ap.add_argument("--model", help="модель прогона (krea2 | qwen21); по умолчанию spec.model")
    ap.add_argument("--dest", help="итоговый путь одного кадра (с --only): файл пишется сразу в него")
    ap.add_argument("--server-prefix", dest="server_prefix",
                    help="имя кадру на сервере (подкаталог/имя); по умолчанию повторяет локальное дерево")
    ap.add_argument("--limit", type=int, help="не больше N артефактов за прогон")
    ap.add_argument("--timeout", type=int, default=900, help="ожидание одного сюжета, c (900)")
    a = ap.parse_args()

    spec = load_spec(Path(a.spec))
    out_root = Path(spec["out_dir"])
    if not out_root.is_absolute():
        out_root = Path(__file__).resolve().parents[2] / out_root
    lst = lambda s: s.split(",") if s else None              # noqa: E731
    models = spec["probe_models"] if a.probe else [a.model or spec["model"]]
    arts = [x for m in models for x in artifacts(spec, lst(a.variant), lst(a.category), lst(a.only), m)]
    for art in arts:                       # путь из каталога относительный — делаем абсолютным
        art["path"] = out_root / art["model_key"] / art["variant"] / art["category"] / f"{art['id']}.webp"
    if a.probe:                            # первый сюжет каждой категории, все варианты
        first = {cname: c["items"][0]["id"] for cname, c in spec["categories"].items()}
        arts = [x for x in arts if x["id"] == first[x["category"]]]
    if a.dest:                             # кадр рождается итоговым именем — промежуточного нет
        if len(arts) != 1:
            raise SystemExit("--dest имеет смысл только с одним артефактом (--only)")
        arts[0]["path"] = Path(a.dest)

    if a.dry_run:
        for art in arts:
            print(f"{art['model_key']}/{art['variant']}/{art['category']}/{art['id']} "
                  f"{art['size'][0]}x{art['size'][1]} seed={seed_of(spec, art)}")
        print(f"итого: {len(arts)} артефактов, {len(spec['variants'])} вариантов, "
              f"{len({x['id'] for x in arts})} уникальных id сюжетов")
        return 0

    if a.sheet:
        for p in contact_sheets(spec, out_root, a.model or spec["model"]):
            print(p)
        return 0
    if a.limit:
        arts = arts[:a.limit]

    mpath = out_root / "manifest.json"
    out_root.mkdir(parents=True, exist_ok=True)
    manifest = json.loads(mpath.read_text()) if mpath.exists() else {}
    tally = {"ok": 0, "skip": 0, "fail": 0}
    failed: list[str] = []

    def record(key: str, entry: dict) -> None:
        manifest[key] = {**manifest.get(key, {}), **entry}
        mpath.write_text(json.dumps(manifest, ensure_ascii=False, indent=1))

    todo = []
    for art in arts:
        key = f"{art['model_key']}/{art['variant']}/{art['category']}/{art['id']}"
        if art["path"].exists() and not a.force:
            tally["skip"] += 1
            continue
        todo.append((key, art))
    print(f"к генерации {len(todo)}, пропущено готовых {tally['skip']}", flush=True)

    for n, (key, art) in enumerate(todo, 1):
        entry = {"variant": art["variant"], "category": art["category"],
                 "id": art["id"], "subject": art["subject"], "file": str(art["path"])}
        tries, verdict, err = 1, "fail", ""
        while tries <= 2:
            try:
                entry.update(generate(spec, art, a.timeout, tries, a.server_prefix or ""))
                verdict = entry["verdict"]
                err = entry.get("error", "")
            except Exception as exc:                             # noqa: BLE001
                verdict, err = "fail", f"{type(exc).__name__}: {exc}"[:300]
            if verdict == "ok" or tries == 2:
                break
            tries += 1
            print(f"   retry {key}: {err}", flush=True)
        tally[verdict] += 1
        if verdict != "ok":
            failed.append(key)
            if not a.dest:      # прогон лаборатории: кадр-улика остаётся на своём месте
                reject = out_root / "_reject" / (f"{art['model_key']}__{art['variant']}"
                                                  f"__{art['category']}__{art['id']}.webp")
                reject.parent.mkdir(parents=True, exist_ok=True)
                art["path"].rename(reject) if art["path"].exists() else None
        entry["verdict"] = verdict
        entry["error"] = err
        entry["tries"] = tries
        record(key, entry)
        print(f"[{n}/{len(todo)}] {verdict:4} {key} "
              f"{entry.get('seconds', '-')}s {err}", flush=True)
    print(f"ИТОГ ok={tally['ok']} skip={tally['skip']} fail={tally['fail']}  манифест: {mpath}")
    for k in failed:
        print(f"  fail: {k}")
    if a.probe:
        for m in models:
            print(f"борд стиля {m} (в каждой строке первым — эталон категории): "
                  f"{style_board(spec, out_root, m)}")
    return 1 if tally["fail"] else 0


if __name__ == "__main__":
    sys.exit(main())

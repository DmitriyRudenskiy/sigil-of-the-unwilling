#!/usr/bin/env python3
"""Генератор концепт-арта: 5 вариантов стиля × 77 сюжетов через ComfyUI MCP.

Каталог сюжетов и стилей — spec.json рядом с этим файлом, кода там нет (см. дельта-спеку
`concept-art-pipeline`). Прогон возобновляем: существующие файлы пропускаются, затравка
выводится из идентификатора артефакта, поэтому повтор рисует то же самое.

    python3 scripts/concept_art/generate.py --dry-run
    python3 scripts/concept_art/generate.py --variant v1_candlelight --only cursor_default
    python3 scripts/concept_art/generate.py                 # полный прогон
    python3 scripts/concept_art/generate.py --sheet         # контактные листы
"""
from __future__ import annotations

import argparse
import asyncio
import binascii
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client

HERE = Path(__file__).resolve().parent
SPEC_PATH = HERE / "spec.json"
WHITE_MIN = 0.60          # доля почти-белого в рамке для изолированных категорий
NEAR_WHITE = 235          # порог «белый»: фон образца — 1% чистого и 98% почти-белого
BORDER = 24               # ширина рамки, px
CONTENT_MIN = 0.02        # в центральном окне 50% обязана быть картинка, а не пустой белый лист
SEAM_MAX = 0.995          # строка считается пустой, если почти-белого в ней не меньше
SEAM_MASS = 0.15            # ...а по обе её стороны не меньше 15 % контента (урок c11: лист 2x2)
LUMA_RANGE = (25, 235)    # средняя яркость кадров без требования белого фона (экраны UI)
ISOLATED = ("units", "buildings", "signs", "cursors", "resources")
TERMINAL_BAD = ("error", "not_found", "canceled")


# ---------------------------------------------------------------- каталог

def load_spec(path: Path = SPEC_PATH) -> dict:
    spec = json.loads(Path(path).read_text())
    refs = Path(spec.get("references_dir", ""))
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
    for key in ("model", "probe_models"):
        if not spec.get(key):
            raise SystemExit(f"spec: нет поля {key} — модель выбирается прогоном, не категорией")
    for m in [spec["model"], *spec["probe_models"]]:
        if m not in spec["models"]:
            raise SystemExit(f"spec: модели {m} нет в реестре models")
    return spec


def seed_for(variant: str, cat: str, item_id: str) -> int:
    return binascii.crc32(f"{variant}/{cat}/{item_id}".encode()) % (2**31)


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


def seam_ratio(im: Image.Image, thr: int = NEAR_WHITE) -> float:
    """Кто сколько занимает по обе стороны от самой пустой горизонтальной полосы кадра.

    Возвращает min(доли контента сверху, доли снизу) для почти-белой строки: 0 у одиночной
    фигуры, много — когда кадр разрезан пустой полосой пополам. Урок калибровки: Krea-2 на
    c11 выдала лист 2×2 (фигура + четыре превью) и прошла воротчик белизны, а шов её сидит
    на 75 % высоты — любая «средняя полоса» кадра его не видит. Полоса ищется по всей высоте,
    но требует содержимого с обеих сторон: пустая строка между ног или под ногами — не шов.
    Строки, а не колонки: фигура с посохом сбоку даёт пустую колонку и в эталоне."""
    px = im.convert("L").point(lambda p: 255 if p >= thr else 0).resize((64, 64)).load()
    mass = [1 - sum(px[x, y] for x in range(64)) / 64 / 255 for y in range(64)]
    total = sum(mass)
    if not total:
        return 0.0
    best, above = 0.0, 0.0
    for m in mass:
        below = total - above - m
        if m <= 1 - SEAM_MAX and min(above, below) / total > best:
            best = min(above, below) / total
        above += m
    return best


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
        if seam > SEAM_MASS:
            return False, (f"кадр разрезан пустой полосой: контента по обе стороны {seam:.0%} "
                           f"> {SEAM_MASS:.0%} — лист с вариантами?")
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


def download(comfy: str, prompt_id: str, fallback_name: str, dest: Path) -> str:
    """Байты результата этого задания: имя файла берём из его истории, не из asset_url."""
    q = urllib.parse.urlencode({"prompt_id": prompt_id})
    try:
        hist = http_json(f"{comfy}/history?{q}")
        imgs = [i for o in hist.get(prompt_id, {}).get("outputs", {}).values()
                for i in o.get("images", [])]
        img = imgs[0]
        name, sub, typ = img["filename"], img.get("subfolder", ""), img.get("type", "output")
    except Exception:                                          # noqa: BLE001
        name, sub, typ = fallback_name, "", "output"
    q = urllib.parse.urlencode({"filename": name, "subfolder": sub, "type": typ})
    dest.write_bytes(http_bytes(f"{comfy}/view?{q}"))
    return name


def to_webp(src: Path, dest: Path, quality: int) -> None:
    im = Image.open(src).convert("RGB")
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, "WEBP", quality=quality)


async def tool_text(session: ClientSession, name: str, args: dict) -> str:
    res = await session.call_tool(name, args)
    return "\n".join(c.text for c in res.content if getattr(c, "type", "") == "text")


async def generate(session: ClientSession, spec: dict, art: dict, timeout: int,
                   attempt: int = 1) -> dict:
    """Один сюжет: запрос -> ожидание -> загрузка -> экспорт -> проверки."""
    t0 = time.time()
    m = spec["models"][art["model_key"]]
    variant = next(v for v in spec["variants"] if v["id"] == art["variant"])
    cat = spec["categories"][art["category"]]
    negative_param = art["model_key"] != "krea2"
    prompt, neg = build_prompt(variant, cat, art, negative_param)
    # +attempt: повтор при провале воротчика обязан менять затравку — тот же запрос с той же
    # затравкой ComfyUI отдаёт из кэша мгновенно и тем же кадром (проверено: 0.2 с, тот же вердикт).
    seed = seed_for(art["variant"], art["category"], art["id"]) + (attempt - 1)
    args = {"unet": m["unet"], "clip": m["clip"], "vae": m["vae"], "prompt": prompt,
            "width": art["size"][0], "height": art["size"][1], "seed": seed, "steps": m["steps"]}
    if "cfg" in m:
        args["cfg"] = m["cfg"]
    if neg:
        args["negative_prompt"] = neg

    text = await tool_text(session, m["tool"], args)
    pid = (re.search(r'"prompt_id":\s*"([0-9a-f-]+)"', text) or [None, None])[1]
    name = (re.search(r'"filename":\s*"([^"]+)"', text) or [None, None])[1]
    while pid and not name:
        if time.time() - t0 > timeout:
            raise TimeoutError(f"ожидание > {timeout} c")
        await asyncio.sleep(10)
        text = await tool_text(session, "get_job", {"prompt_id": pid})
        st = (re.search(r'"status":\s*"(\w+)"', text) or [None, "?"])[1]
        if st in TERMINAL_BAD:
            raise RuntimeError(f"{st}: {text[:200]}")
        name = (re.search(r'"filename":\s*"([^"]+)"', text) or [None, None])[1]
        if st == "completed" and not name:
            raise RuntimeError(f"completed без имени файла: {text[:200]}")
    if not name:
        raise RuntimeError(f"сервер не вернул ни задания, ни файла: {text[:200]}")

    out = art["path"]
    tmp = out.with_suffix(".part.png")
    tmp.parent.mkdir(parents=True, exist_ok=True)
    server_name = download(spec["comfy"], pid or "", name, tmp)
    to_webp(tmp, out, spec["export"]["quality"])
    tmp.unlink(missing_ok=True)
    ok, why = check_image(out, art["size"], art["category"] in ISOLATED)
    return {"verdict": "ok" if ok else "fail", "error": why, "seed": seed,
            "model": art["model_key"], "checkpoint": m["unet"], "prompt": prompt,
            "negative_prompt": neg, "size": list(art["size"]), "server_file": server_name,
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

    if a.dry_run:
        for art in arts:
            print(f"{art['model_key']}/{art['variant']}/{art['category']}/{art['id']} "
                  f"{art['size'][0]}x{art['size'][1]} seed={seed_for(art['variant'], art['category'], art['id'])}")
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

    async def run() -> None:
        async with streamablehttp_client(spec["server"]) as (r, w, _):
            async with ClientSession(r, w) as s:
                await s.initialize()
                for n, (key, art) in enumerate(todo, 1):
                    entry = {"variant": art["variant"], "category": art["category"],
                             "id": art["id"], "subject": art["subject"], "file": str(art["path"])}
                    tries, verdict, err = 1, "fail", ""
                    while tries <= 2:
                        try:
                            entry.update(await generate(s, spec, art, a.timeout, tries))
                            verdict = entry["verdict"]
                            err = entry.get("error", "")
                        except Exception as exc:                 # noqa: BLE001
                            verdict, err = "fail", f"{type(exc).__name__}: {exc}"[:300]
                        if verdict == "ok" or tries == 2:
                            break
                        tries += 1
                        print(f"   retry {key}: {err}", flush=True)
                    tally[verdict] += 1
                    if verdict != "ok":
                        failed.append(key)
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

    asyncio.run(run())
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

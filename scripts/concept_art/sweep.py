#!/usr/bin/env python3
"""Массовый прогон цепочки: на персонажа три круга по три модели = 9 кадров.

Круг = одна правка строки словаря (новый P) и по замеру каждой стадии на этой
паре (P, R). Судья STY — свежая сессия `pi` без инструментов: тот же прибор,
которым меряются слепые якоря. Человек в массовый прогон не помещается.

    python3 scripts/concept_art/sweep.py                     # очередь (IMG-001..)
    python3 scripts/concept_art/sweep.py --intake DIR        # затем досыпать из DIR
    python3 scripts/concept_art/sweep.py --calibrate IMG-001 # судья против человека

История: docs/sweep.jsonl — по строке на кадр (аудит), docs/sweep.md — сводка.
Перезапуск безопасен: кадры, помеченные в jsonl, не повторяются.
"""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
from datetime import date, datetime
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from PIL import Image
from concept_art import jobloop as j

MODELS = ("krea2", "ernie", "zimage")
ROWS = ("line", "color", "texture", "shade")
LOG = j.DOCS / "sweep.jsonl"
MD = j.DOCS / "sweep.md"
INTAKE_LEDGER = j.DOCS / "sweep-intake.json"
FREE_FLOOR = 2 * 1024 ** 3          # ниже не пишем: машина владельца задохнётся
LOOSE = "loose"                      # категория юнитов из --intake (свои кропы)

# Круг = одна правка строки; правки накапливаются (принятая строка остаётся).
SHADE_P8 = ("flat local colour kept flat between a few soft-edged form shadows "
            "where the figure turns away")
TEXT_O = "matte painted surface with fine painterly tonal variation"
TEXT_P9 = ("matte painted surface with visible dry-brush strokes and two or three "
           "tonal variations inside every large surface")
LINE_O = "thinner interior lines of the same hue for muscles, seams and folds"
LINE_P10 = ("thinner interior lines of the same hue for muscles, seams, folds, facial "
            "features and clothing edges")
LADDER = [
    # P8 — базовое состояние: накопленные правки предыдущего юнита откатываются.
    ("P8", [(TEXT_P9, TEXT_O), (LINE_P10, LINE_O)]),
    ("P9", [(TEXT_O, TEXT_P9)]),      # фактура: мазок внутрь больших плоскостей
    ("P10", [(LINE_O, LINE_P10)]),    # линия: внутренние линии на лицо и одежду
]

BRIEF = """Судья стиля. Первый файл — эталон, второй — попытка того же персонажа.
Меряются четыре строки; поза, кадрирование, анатомия и сюжет не считаются.
line    — ровный тёмный контур одинаковой толщины + внутренние линии той же семьи
color   — семья оттенков, сатурация, температура, без глянцевого сдвига
texture — характер поверхности: мазок, матовость, микровариация, не пластик
shade   — световая логика: собственные тени формами, мягкий возврат, без аэрографа
Шкала: 10 — расхождений нет; 9 — одно мелкое; 7-8 — заметное расхождение, семья та же;
5-6 — строка держится клочьями; 1-4 — строка потеряна.
Ответь ровно четырьмя строками вида `row=N|одно названное расхождение` (line, color,
texture, shade). Текст после | обязателен при N=9 или N=10 и обязателен коротко."""

GATE = """Первый файл — кандидат в библиотеку персонажей. Это ОДИН персонаж
(челеноподобная фигура, существо, робот), нарисованный от головы до ног или
пояса, на белом или простом фоне? Фоны-пейзажи, оружие, логотипы, скетч-листы
с несколькими фигурами, фото и 3D-ренсеры — нет.
Если да, ответь двумя строками:
YES
<по-английски, одной строкой: телосложение, поза, одежда и предметы, лицо и волосы>
Если нет, ответь одной строкой: NO"""


# ------------------------------------------------------------------ журнал

def log(rec: dict) -> None:
    rec["ts"] = datetime.now().isoformat(timespec="seconds")
    with LOG.open("a") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")


def done_keys() -> set:
    out = set()
    if LOG.is_file():
        for line in LOG.read_text().splitlines():
            r = json.loads(line)
            if r.get("ok"):
                out.add(f'{r["unit"]}|{r["p"]}|{r["model"]}')
    return out


def md(line: str) -> None:
    with MD.open("a") as f:
        f.write(line + "\n")


# ------------------------------------------------------------------ промт

def set_prompt(p: str, edits: list[tuple[str, str]]) -> None:
    """Состояние STYLE для круга: правки применяются идемпотентно (перезапуск
    и повторные юниты не меняют текст дважды). Пара (P, R) обязана отличаться
    от пары предыдущего круга — иначе повтори-гард снимет генерацию."""
    spec = json.loads(j.SPEC.read_text())
    style = spec["variants"][0]["style"]
    for old, new in edits:
        if old in style:
            style = style.replace(old, new)
        elif new not in style:
            raise SystemExit(f"P{p}: строки нет в STYLE и новая не на месте:\n{old}")
    spec["variants"][0]["style"] = style
    spec["prompt_version"] = p
    j.SPEC.write_text(json.dumps(spec, ensure_ascii=False, indent=1) + "\n")


# ------------------------------------------------------------------ судья

def ask(files: list[Path], brief: str, tries: int = 2) -> str:
    err = ""
    for _ in range(tries):
        r = subprocess.run(["pi", "-p", "--no-tools", "--no-session", "--mode", "text",
                            *[f"@{f}" for f in files], brief],
                           capture_output=True, text=True, timeout=1800,
                           stdin=subprocess.DEVNULL)
        out = r.stdout.strip()
        if out:
            return out
        err = (r.stdout + r.stderr)[-300:]
        time.sleep(5)
    return err


def png(p: Path) -> Path:
    """Судья читает PNG; webp прогона конвертируется на лету."""
    if p.suffix.lower() == ".png":
        return p
    tmp = Path("/tmp") / f"sweep-{p.stem}.png"
    Image.open(p).convert("RGB").save(tmp)
    return tmp


def judge(etalon: Path, frame: Path) -> tuple[list[str], list[str], str]:
    """(rows, gaps, ошибка). Девятка живёт только с названным расхождением —
    судья обязан назвать его сам, иначе движок срезает её в восемь."""
    shot = png(frame)
    out = ask([png(etalon), shot], BRIEF)
    if shot != frame:
        shot.unlink(missing_ok=True)
    got = dict((m.group(1), (int(m.group(2)), m.group(3).strip()))
               for m in re.finditer(r"(line|color|texture|shade)\s*=\s*(\d+)\s*\|?\s*([^\n]*)",
                                    out, re.I))
    if not all(k in got for k in ROWS):
        return [], [], f"судья не ответил четырьмя строками: {out[-200:]}"
    rows, gaps = [], []
    for k in ROWS:
        n, why = got[k]
        n = max(0, min(10, n))
        rows.append(f"{k}={n}")
        if n >= 9 and why:
            gaps.append(f"{k}={why[:160]}")
    return rows, gaps, ""


# ------------------------------------------------------------------ кадр

def shoot(uid: str, model: str) -> tuple[Path | None, str]:
    q = j.load()
    unit = q[uid]
    ver = unit["versions"].get(model, 0) + 1
    want = j.attempt_path(unit, model, ver)
    try:
        j.cmd_next(SimpleNamespace(id=uid, model=model, force=False))
    except SystemExit as e:
        return None, f"next: {e}"
    except Exception as e:                              # генерация/сеть не роняют прогон
        return None, f"next: {type(e).__name__}: {e}"
    if not want.is_file():
        return None, "next: генерация не дала файла"
    return want, ""


def measure(uid: str, model: str, rows: list[str], gaps: list[str]) -> tuple[float | None, str]:
    before = len(j.load()[uid]["history"])
    try:
        j.cmd_sty(SimpleNamespace(id=uid, model=model, rows=rows, gap=gaps,
                                  judge_pass="score", control=None, head_ratio=None))
    except SystemExit as e:
        return None, f"sty: {e}"
    except Exception as e:
        return None, f"sty: {type(e).__name__}: {e}"
    hist = j.load()[uid]["history"]
    return (hist[-1].get("sty_pct") if len(hist) > before else None), ""


def free_ok() -> bool:
    return shutil.disk_usage(str(j.LAB)).free > FREE_FLOOR


# ------------------------------------------------------------------ круг

def circles(uid: str, done: set) -> None:
    unit = j.load()[uid]
    etalon = j.LAB / unit["reference"]
    for p, edits in LADDER:
        set_prompt(p, edits)
        for model in MODELS:
            key = f"{uid}|{p}|{model}"
            if key in done:
                continue
            if not free_ok():
                md(f"{date.today()} СТОП: свободно меньше "
                   f"{FREE_FLOOR // 2**30} ГиБ — прогон приостановлен, {key} не снят")
                raise SystemExit(0)
            rec = {"unit": uid, "p": p, "model": model, "ok": False}
            t0 = time.time()
            frame, err = shoot(uid, model)
            rec["frame"] = str(frame.relative_to(j.LAB)) if frame else None
            if frame is None:
                rec["err"] = err
                log(rec)
                continue
            rows, gaps, jerr = judge(etalon, frame)
            rec["rows"], rec["gaps"] = rows, gaps
            if not rows:
                rec["err"] = jerr
                log(rec)
                continue
            sty, serr = measure(uid, model, rows, gaps)
            rec["sty"], rec["err"] = sty, serr
            rec["ok"] = serr == ""
            rec["sec"] = round(time.time() - t0)
            log(rec)
            done.add(key)


def unit_summary(uid: str) -> None:
    u = j.load()[uid]
    cyc = " · ".join(f"круг {c['cycle']}: " + "/".join(f"{m} {c['sty'][m]}" for m in MODELS
                                                       if m in c["sty"]) + f" → {c['mean']}"
                     for c in u.get("cycles", [])[-3:])
    md(f"{date.today()} {uid}: {cyc}")


# ------------------------------------------------------------------ intake

def sha1(p: Path) -> str:
    return hashlib.sha1(p.read_bytes()).hexdigest()


def intake_ledger() -> dict:
    return json.loads(INTAKE_LEDGER.read_text()) if INTAKE_LEDGER.is_file() else {}


def loose_category() -> str:
    """Категория юнитов из --intake: та же семья стиля, свой лист-заглушка.
    Истиной для них служит собственный кроп юнита, а не лист."""
    spec = json.loads(j.SPEC.read_text())
    if LOOSE not in spec["categories"]:
        base = json.loads(json.dumps(spec["categories"]["unit-01"]))
        base["items"], base["count"] = [], 0
        base["reference"] = "loose.png"
        spec["categories"][LOOSE] = base
        first = sorted(Path(j.LAB / "references/crops").glob("IMG-*.png"))[0]
        shutil.copy(first, j.REFS / "loose.png")
    j.SPEC.write_text(json.dumps(spec, ensure_ascii=False, indent=1) + "\n")
    return LOOSE


def next_uid(q: dict) -> str:
    n = max(int(k.split("-")[1]) for k in q) + 1
    return f"IMG-{n:03d}"


def square(src: Path, dst: Path, side: int = 1024) -> None:
    im = Image.open(src).convert("RGB")
    if max(im.size) > side:
        im.thumbnail((side, side))
    canvas = Image.new("RGB", (max(im.size),) * 2, (255, 255, 255))
    canvas.paste(im, ((max(im.size) - im.width) // 2, (max(im.size) - im.height) // 2))
    dst.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dst)


def admit(src: Path, ledger: dict, dry: bool = False) -> str | None:
    """Один кандидат: шлюз + подпись одним вызовом судьи. Возвращает id юнита."""
    if dry:
        crop = Path("/tmp") / f"gate-{hashlib.sha1(str(src).encode()).hexdigest()[:8]}.png"
        square(src, crop)
        out = ask([crop], GATE)
        crop.unlink(missing_ok=True)
        print(f"{'+' if out.startswith('YES') else '-'} {src.name}: {out[:150]}", flush=True)
        return None
    q, spec = j.load(), json.loads(j.SPEC.read_text())
    uid = next_uid(q)
    crop = j.LAB / "references/crops" / f"{uid}.png"
    square(src, crop)
    out = ask([crop], GATE)
    if not out.startswith("YES"):
        crop.unlink(missing_ok=True)
        ledger[str(src)] = {"uid": None, "why": out[:160]}
        return None
    subject = out.split("\n", 1)[1].strip().split("\n")[0]
    q[uid] = {"unit": uid, "reference": f"references/crops/{uid}.png",
              "sheet": f"references/{LOOSE}.png", "cell": 0, "category": LOOSE,
              "model": j.MODEL_DEFAULT, "status": "in-queue", "version": 0,
              "versions": {}, "best_score": None, "max_attempts": j.MAX_ATTEMPTS,
              "subject": subject, "history": []}
    j.save(q)
    spec["categories"][LOOSE]["items"].append({"id": uid, "subject": subject})
    spec["categories"][LOOSE]["count"] = len(spec["categories"][LOOSE]["items"])
    j.SPEC.write_text(json.dumps(spec, ensure_ascii=False, indent=1) + "\n")
    ledger[str(src)] = {"uid": uid, "why": "принят"}
    return uid


def sweep_intake(root: Path, done: set, dry: int = 0) -> None:
    files = sorted(p for p in root.rglob("*")
                   if p.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp") and p.is_file())
    if dry:
        for src in files[:dry]:
            admit(src, {}, dry=True)
        return
    ledger = intake_ledger()
    seen = set(ledger)
    md(f"{date.today()} intake {root}: файлов {len(files)}, в реестре {len(seen)}")
    loose_category()
    for n, src in enumerate(files, 1):
        if not free_ok():
            md(f"{date.today()} СТОП intake: свободно меньше "
               f"{FREE_FLOOR // 2**30} ГиБ (обработано {n - 1}/{len(files)})")
            return
        if str(src) in seen:
            continue
        try:
            uid = admit(src, ledger)
        except Exception as e:
            ledger[str(src)] = {"uid": None, "why": f"{type(e).__name__}: {e}"[:200]}
            uid = None
        INTAKE_LEDGER.write_text(json.dumps(ledger, ensure_ascii=False, indent=1) + "\n")
        if uid:
            print(f"[{n}/{len(files)}] {uid} ← {src.name}", flush=True)
            circles(uid, done)
        if n % 25 == 0:
            md(f"{date.today()} intake: обработано {n}/{len(files)}, "
               f"принято {sum(1 for v in ledger.values() if v['uid'])}")


# ------------------------------------------------------------------ вход

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--intake", help="каталог кандидатов для второй волны")
    ap.add_argument("--dry", type=int, default=0, help="проверить шлюз intake на N файлах")
    ap.add_argument("--calibrate", help="прогнать судью по замерам юнита и показать разнос")
    ap.add_argument("--only", help="пропустить юниты до этого id")
    a = ap.parse_args()
    if a.calibrate:
        return calibrate(a.calibrate)
    if a.dry:
        sweep_intake(Path(a.intake), set(), dry=a.dry)
        return 0
    done = done_keys()
    md(f"\n{date.today()} прогон начат: сделанных кадров в журнале {len(done)}")
    q = j.load()
    for uid in sorted(q):
        if a.only and uid < a.only:
            continue
        if q[uid]["status"] not in j.OPEN:
            continue
        if not q[uid]["subject"].strip():
            md(f"{date.today()} {uid}: описания нет — пропущен")
            continue
        circles(uid, done)
        unit_summary(uid)
    if a.intake:
        sweep_intake(Path(a.intake), done)
    md(f"{date.today()} прогон завершён")
    return 0


def calibrate(uid: str) -> int:
    """Судья против человека: те же кадры, те же строки, разнос по баллам."""
    u = j.load()[uid]
    etalon = j.LAB / u["reference"]
    for h in [h for h in u["history"] if h.get("rows")][-3:]:
        rows, gaps, err = judge(etalon, j.LAB / h["file"])
        human = h["rows"]
        vlm = dict(re.findall(r"(\w+)=(\d+)", " ".join(rows)))
        d = {k: int(vlm.get(k, -9)) - human[k] for k in human}
        print(f"{h['model']} v{h['version']}: человек "
              f"{[human[k] for k in ROWS]} судья {[vlm.get(k) for k in ROWS]} разнос {d} {err}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

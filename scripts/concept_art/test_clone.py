#!/usr/bin/env python3
"""Самопроверка движка лаборатории: `python3 scripts/concept_art/test_clone.py`.

assert-ами, без сервера: проверяется то, что глазами в цикле не видно — шаблон имени
файла, «версия считается в рамках модели», блокировка на пятой попытке, accept ниже
порога, знаменатель готовности, журнал только на дописывание.
"""
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import jobloop as j                                                # noqa: E402

checks = 0


def ok(cond, what):
    global checks
    assert cond, f"FAIL: {what}"
    checks += 1


class Args:
    def __init__(self, **kw):
        self.__dict__.update(kw)


tmp = Path(tempfile.mkdtemp())
j.LAB = tmp
j.REFS = tmp / "references"
j.CROPS = j.REFS / "crops"
j.ATTEMPTS = tmp / "attempts"
j.MATCHES = tmp / "matches"
j.DOCS = tmp / "docs"
j.QUEUE = tmp / "queue.json"
j.PAIRS = tmp / "pairs"

unit = {"unit": "IMG-001", "reference": "references/crops/IMG-001.png", "category": "unit-01",
        "model": "krea2", "status": "in-queue", "version": 0, "versions": {}, "best_score": None,
        "max_attempts": j.MAX_ATTEMPTS, "subject": "бравый воин", "history": []}
j.save({"IMG-001": unit})

# --- шаблон имени: <модель>_<юнит>_<версия>
name = j.attempt_path(unit, "krea2", 3).name
ok(name == "krea2_IMG-001_v3.webp", f"имя попытки не по шаблону: {name}")
ok(j.attempt_path(unit, "qwen21", 1).parent == j.ATTEMPTS / "IMG-001", "попытки не в папке юнита")

# --- готовность: неприменимый критерий выпадает из знаменателя
ok(j.readiness({"comp": 10, "subject": 10}) == 100, "идеальные оценки != 100%")
ok(j.readiness({"comp": 5, "subject": 5}) == 50, "половина не 50%")
ok(j.readiness({"comp": 8, "subject": 8, "palette": 8, "text": 0}) < j.readiness({"comp": 8, "subject": 8, "palette": 8}),
   "нулевой текст не должен тянуть готовность вниз — он исключается, а не обнуляется")

# --- accept закрыт до порога, открыт на пороге
q = j.load()
q["IMG-001"].update(model="krea2", version=1, file="attempts/IMG-001/krea2_IMG-001_v1.webp")
j.save(q)
j.cmd_score(Args(id="IMG-001", criteria=["comp=8", "subject=8", "palette=8"], note=""))
ok(j.load()["IMG-001"]["history"][-1]["readiness"] == 80, "готовность не 80%")
try:
    j.cmd_accept(Args(id="IMG-001", note=""))
    ok(False, "accept пропустил 80%")
except SystemExit as e:
    ok("80" in str(e), f"accept отказал не по причине порога: {e}")

# --- reject на пятой попытке блокирует юнит и не трогает кадр
q = j.load()
q["IMG-001"]["version"] = j.MAX_ATTEMPTS
j.save(q)
(j.ATTEMPTS / "IMG-001").mkdir(parents=True, exist_ok=True)
kept = j.ATTEMPTS / "IMG-001" / "krea2_IMG-001_v5.webp"
kept.write_bytes(b"webp")
j.cmd_reject(Args(id="IMG-001", subject="", note="упёрлись"))
ok(j.load()["IMG-001"]["status"] == "blocked", "на пятой попытке не заблокирован")
ok(kept.exists(), "reject удалил кадр — неудачный обязан остаться для разбора")

# --- смена модели: версия начинается с v1, счётчик предыдущей модели не продолжается
q = j.load()
q["IMG-001"].update(status="in-queue", model="krea2", version=4, versions={"krea2": 4})
j.save(q)
j.cmd_model(Args(id="IMG-001", model="qwen21"))
q = j.load()
ok(q["IMG-001"]["model"] == "qwen21", "модель не сменилась")
ok(q["IMG-001"]["versions"].get("qwen21", 0) == 0, "новая модель не обнулила счётчик")
ok(q["IMG-001"]["versions"]["krea2"] == 4, "счётчик прежней модели пострадал")

# --- журнал дописывается, а не перезаписывается
before = (j.DOCS / "report.md").read_text()
q = j.load()
q["IMG-001"].update(status="in-queue", version=1, file="attempts/IMG-001/qwen21_IMG-001_v1.webp")
j.save(q)
j.cmd_score(Args(id="IMG-001", criteria=["comp=9", "subject=9", "palette=9"], note=""))
after = (j.DOCS / "report.md").read_text()
ok(after.startswith(before), "журнал перезаписан вместо дописывания")
ok("qwen21_IMG-001_v1.webp" in after, "имя файла не попало в журнал")

# --- success копирует кадр в matches под тем же именем
q = j.load()
q["IMG-001"].update(version=1, file="attempts/IMG-001/qwen21_IMG-001_v1.webp")
j.save(q)
(j.ATTEMPTS / "IMG-001").mkdir(parents=True, exist_ok=True)
(j.ATTEMPTS / "IMG-001" / "qwen21_IMG-001_v1.webp").write_bytes(b"webp")
j.cmd_accept(Args(id="IMG-001", note=""))
q = j.load()
ok(q["IMG-001"]["status"] == "success", "после accept юнит не success")
ok((j.MATCHES / "qwen21_IMG-001_v1.webp").exists(), "копия не легла в matches с тем же именем")
ok(kept.exists(), "растровые попытки пережили не все команды — кто-то из них удаляет файлы")

# --- кроп квадрратный: оправа эталона и прогона общая
from PIL import Image, ImageDraw                                      # noqa: E402
sheet = Image.new("RGB", (2048, 2048), (255, 255, 255))
d = ImageDraw.Draw(sheet)
for n in range(12):                       # в каждой ячейке — фигура выше, чем шире
    x, y = (n % 4) * 512, (n // 4) * 683
    d.rectangle([x + 150, y + 40, x + 350, y + 640], fill=(10, 20, 30))
sheet.save(tmp / "sheet.jpeg")
out = tmp / "cut"
out.mkdir()
j.crop_sheet(tmp / "sheet.jpeg", out)
crop = Image.open(out / "cell-01.png")
ok(crop.size[0] == crop.size[1], f"кроп не квадратный: {crop.size}")
ok(abs(crop.size[0] - 600) <= 10, f"кроп не по длинной стороне фигуры: {crop.size}")
ok(Image.open(out / "cell-12.png").size[0] == crop.size[0], "ячейки режутся по-разному")

print(f"OK: проверок {checks}")

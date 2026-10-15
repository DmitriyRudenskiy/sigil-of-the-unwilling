#!/usr/bin/env python3
"""Самопроверка движка лаборатории: `python3 scripts/concept_art/test_clone.py`.

assert-ами, без сервера: проверяется то, что глазами в цикле не видно — шаблон имени
файла, «версия считается в рамках модели», блокировка на пятой попытке, accept ниже
порога, знаменатель готовности, журнал только на дописывание.
"""
import json
import re
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
j.ETALONS = j.REFS / "manifest.json"
j.ANCHORS = j.DOCS / "anchors.md"

unit = {"unit": "IMG-001", "reference": "references/crops/IMG-001.png", "category": "unit-01",
        "sheet": "references/unit-01.jpeg", "cell": 1,
        "model": "krea2", "status": "in-queue", "version": 0, "versions": {}, "best_score": None,
        "max_attempts": j.MAX_ATTEMPTS, "subject": "бравый воин", "history": []}
j.save({"IMG-001": unit})

# --- шаблон имени: <модель>_<юнит>_<версия>[_<P><R>]
name = j.attempt_path(unit, "krea2", 3).name
ok(re.fullmatch(r"krea2_IMG-001_v3(_P\d+R\d+)?\.webp", name), f"имя не по шаблону: {name}")
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

# --- вердикт стиля: приёмка только парным тестом, проценты в ней не участвуют
(j.CROPS / "IMG-001").parent.mkdir(parents=True, exist_ok=True)
(j.CROPS / "IMG-001.png").write_bytes(b"png")
j.cmd_etalons(Args())


def verdict(sty, cnt=(), ident=(), head_sty=False):
    q = j.load()
    q["IMG-001"].update(status="in-queue", model="qwen21", version=2,
                        versions={"qwen21": 2}, file="attempts/IMG-001/qwen21_IMG-001_v2.webp")
    j.save(q)
    (j.ATTEMPTS / "IMG-001").mkdir(parents=True, exist_ok=True)
    (j.ATTEMPTS / "IMG-001" / "qwen21_IMG-001_v2.webp").write_bytes(b"webp")
    j.cmd_verdict(Args(id="IMG-001", sty=sty, sty_notes=[], cnt=list(cnt),
                       ident=list(ident), head_sty=head_sty, note="", ceiling=""))
    return j.load()["IMG-001"]


u = verdict("yes")
ok(u["status"] == "success", "вердикт «да» не принял кадр")
ok((j.MATCHES / "qwen21_IMG-001_v2.webp").exists(), "принятый кадр не лёг в matches")
ok(u["history"][-1]["etalons"] == j.etalon_version(), "вердикт не записал версию эталонов")
ok(verdict("no", ["поза: левый локоть"]) ["status"] == "in-queue", "дрейф без головы — не переработка")
ok(verdict("no", ["поза: левый локоть"], head_sty=True)["status"] == "redraw",
   "стилевое расхождение лица не отправляет перерисовывать")
ok(len(verdict("no", [f"правка {n}" for n in range(4)]) ["history"][-1]["cnt"]) == 4,
   "список точечных правок не сохранён в историю")
ok(verdict("no", [f"правка {n}" for n in range(4)]) ["status"] == "redraw",
   "больше трёх точечных правок — не экономический отказ")
ok("правка 0" in (j.DOCS / "fixups.md").read_text(), "журнал доводок не пишется")

# --- похожесть — отдельный слой: пишется, но приёмку не блокирует никогда
u = verdict("no", ["поза: левый локоть"], ident=["лицо не похоже"])
ok(u["status"] == "in-queue", "похожесть заблокировала приёмку — ей нельзя")
ok(not u["history"][-1]["identity_ceiling"], "потолок похожести объявлен на первой же записи")
u = verdict("no", ["поза: левый локоть"], ident=["лицо не похоже"])
ok(u["history"][-1]["identity_ceiling"], "второй одинаковый вердикт по лицу не потолок")
ok(u["status"] == "in-queue", "потолок похожести не должен менять статус")
ok("identity-ceiling" in (j.DOCS / "identity.md").read_text(), "журнал похожести не пишется")

# --- потолок по признаку: правки слов кончились, юнит выходит из очереди
q = j.load()
q["IMG-001"].update(status="in-queue", model="qwen21", version=1, versions={"qwen21": 1})
j.save(q)
j.cmd_verdict(Args(id="IMG-001", sty="near", sty_notes=[], cnt=[], ident=[],
                   head_sty=False, note="", ceiling="gloss"))
unit = j.load()["IMG-001"]
ok(unit["status"] == "model-ceiling", "потолок признака не помечен статусом")
ok(unit["history"][-1]["prompt_ceiling"] == "gloss", "признак потолка не записан")

q = j.load()
q["IMG-001"]["versions"] = {"qwen21": j.MAX_ATTEMPTS}
j.save(q)
(j.ATTEMPTS / "IMG-001" / "qwen21_IMG-001_v2.webp").write_bytes(b"webp")
j.cmd_verdict(Args(id="IMG-001", sty="no", sty_notes=[], cnt=[], ident=[], head_sty=False,
                   note="", ceiling=""))
ok(j.load()["IMG-001"]["status"] == "blocked", "вердикт «нет» на лимите не блокирует юнит")
ok(all(h.get("readiness") is not None or "sty" in h for h in j.load()["IMG-001"]["history"]),
   "запись вердикта не отличить от записи готовности")

# --- эталонный сет: вердикт не выдаётся против несверенных пикселей
(j.CROPS / "IMG-001.png").write_bytes(b"other etalon")
try:
    verdict("yes")
    ok(False, "вердикт прошёл против изменённого эталона")
except SystemExit as e:
    ok("эталонный сет" in str(e), f"эталонный дрейф не пойман: {e}")
j.cmd_etalons(Args())
ok(verdict("yes")["status"] == "success", "после пересборки манифеста вердикт не ожил")

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

# --- имя кадру задаёт сервер: префикс попадает в SaveImage, роли узлов ищутся по class_type
import generate as g                                                 # noqa: E402

art = {"model_key": "qwen21", "variant": "copy", "category": "unit-01", "id": "IMG-001",
       "size": [512, 512]}
PREFIX = "image-clone/IMG-001/qwen21_IMG-001_v1"


def by_class(graph, ct):
    return [n for n in graph.values() if n["class_type"] == ct]


for model, neg in (("qwen21", "NEG"), ("krea2", "")):
    gr = g.workflow(model, {"steps": 25}, art, "ПРОМТ", neg, 123, PREFIX)
    ok(by_class(gr, "SaveImage")[0]["inputs"]["filename_prefix"] == PREFIX,
       f"{model}: SaveImage не получил имя — кадр родится мусорным")
    ok(any(n["inputs"].get("text") == "ПРОМТ" or n["inputs"].get("prompt") == "ПРОМТ"
           for n in gr.values()), f"{model}: промт не дошёл до узла текста")
    ok(by_class(gr, "KSampler")[0]["inputs"]["seed"] == 123, f"{model}: затравка не подставлена")
    ok(by_class(gr, "EmptyLatentImage")[0]["inputs"]["width"] == 512, f"{model}: размер не подставлен")

# --- перенумерация графа не ломает подстановку (роли — по class_type, не по номерам)
import json as _json                                                # noqa: E402
_orig = _json.dumps(g.WORKFLOWS["qwen21"])
try:
    g.WORKFLOWS["qwen21"] = {f"n{k}": v for k, v in g.WORKFLOWS["qwen21"].items()}
    gr = g.workflow("qwen21", {"steps": 25}, art, "ПРОМТ", "NEG", 7, PREFIX)
    ok(by_class(gr, "SaveImage")[0]["inputs"]["filename_prefix"] == PREFIX,
       "перенумерованный граф потерял имя")
    ok(by_class(gr, "KSampler")[0]["inputs"]["seed"] == 7, "перенумерованный граф потерял затравку")
finally:
    g.WORKFLOWS["qwen21"] = _json.loads(_orig)

# --- у кадра нет промежуточного имени: движок отдаёт серверу итоговый путь
j.SPEC = tmp / "lab-spec.json"
spec = {"categories": {"unit-01": {"items": [{"id": "IMG-001", "subject": ""}]}}}
j.SPEC.write_text(_json.dumps(spec))
q = j.load()
q["IMG-001"].update(status="in-queue", model="krea2", version=0, versions={}, file=None)
j.save(q)
(j.CROPS).mkdir(parents=True, exist_ok=True)
Image.new("RGB", (256, 256), "white").save(j.CROPS / "IMG-001.png")

seen_argv = []


def fake_run(cmd, check=False):                        # сервер подменён: рисуем кадр прямо в --dest
    seen_argv.append(cmd)
    dest = Path(cmd[cmd.index("--dest") + 1])
    im = Image.new("RGB", (512, 512), "white")
    ImageDraw.Draw(im).rectangle([180, 60, 330, 450], fill=(20, 30, 40))
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, "WEBP")
    return Args(returncode=0)


sub_run, j.subprocess.run = j.subprocess.run, fake_run
try:
    j.cmd_next(Args(model=None, id=None))
finally:
    j.subprocess.run = sub_run

ok(len(seen_argv) == 1, "next не вызвал генератор")
cmd = seen_argv[0]
ok(re.fullmatch(r".*/IMG-001/krea2_IMG-001_v1(_P\d+R\d+)?\.webp", cmd[cmd.index("--dest") + 1]),
   "генератору не передан итоговый путь")
ok(re.fullmatch(rf"{j.LAB.name}/IMG-001/krea2_IMG-001_v1(_P\d+R\d+)?", cmd[cmd.index("--server-prefix") + 1]),
   "серверу не передано итоговое имя")
leftovers = [p.name for p in j.LAB.rglob("IMG-001.webp")]
ok(not leftovers, f"кадр всё ещё рождается служебным именем: {leftovers}")
ok(any((j.ATTEMPTS / "IMG-001").glob("krea2_IMG-001_v1*.webp")), "кадр не лёг в итоговый путь")
ok(not (j.LAB / "concept_art").exists(), "служебный путь прогона лаборатории вернулся")

# --- 56. пара версий прогона (P, R): в имени, в записи, в вердикте ---------
spec["prompt_version"] = "P2"
spec["render"] = {"id": "R1", "cfg": 2.0, "sampler": "euler"}
j.SPEC.write_text(_json.dumps(spec))
ok(j.attempt_name(unit, "krea2", 2) == "krea2_IMG-001_v2_P2R1",
   f"в имени нет пары версий: {j.attempt_name(unit, 'krea2', 2)}")

# --- 57. линт стилевого блока ----------------------------------------------
card = ("## 1. Линия\n\n| Признак | Формулировка |\n| --- | --- |\n"
        "| Контур | `clean dark contour line` |\n\n"
        "## 2. Цвет\n\n| Признак | Формулировка |\n| --- | --- |\n"
        "| Кожа | `warm ochre skin` |\n\n"
        "## Отрицания\n\n| Токен | Защищаемая строка |\n| --- | --- |\n"
        "| `airbrush` | Контур |\n")
bad = j.lint_style("clean dark contour line, airbrush, matte, no airbrush, no text", card)
ok(any("airbrush" in b and "в плюсе и в минусе" in b for b in bad),
   f"линт не нашёл токен в двух половинах: {bad}")
ok(any("warm ochre skin" in b for b in bad), f"линт не нашёл строку словаря без якоря: {bad}")
ok(not any("clean dark contour line" in b for b in bad), "линт обвинил якорь, который на месте")
ok(j.lint_style("clean dark contour line, warm ochre skin", card) == [],
   "чистый блок дал находки")

# --- 57b. морфология отрицания в плюсе запрещена ---------------------------
neg = j.lint_style("clean dark contour line, no ink outlines", card)
ok(any("лексическое отрицание" in b and "no" in b for b in neg),
   f"линт пропустил морфологию отрицания: {neg}")

# --- 58. reopen: потолок, объявленный на неиспробованном рычаге, снимается --
unit["status"] = "model-ceiling"
j.cmd_reopen(Args(id="IMG-001", note="рычаг не проверен на живучесть"))
ok(j.load()["IMG-001"]["status"] == "in-queue", "reopen не вернул юнит в очередь")
ok("рычаг не проверен" in (j.DOCS / "report.md").read_text(), "причина снятия не в журнале")

# --- 59. десякая без цитаты якоря не существует ----------------------------
rows, tens, notes = j.parse_sty_rows(["line=10", "color=8", "texture=8", "shade=8"], [], True)
ok(any("без цитаты якоря" in n for n in notes), f"десятка без якоря не порезана: {notes}")
ok(rows["line"] == 8 and len(notes) == 2,
   f"строка без цитаты и без проверки падает дважды: {rows} {notes}")
ok(tens == [], "без цитаты в журнал попала десятка")

# --- 60. десятка обязана пережить адверсариальный проход -------------------
rows, tens, notes = j.parse_sty_rows(["line=10@AP-line-2", "color=8", "texture=8", "shade=8"],
                                     [], False)
ok(rows["line"] == 9 and any("адверсариальный" in n for n in notes),
   f"десятка без ревизии не порезана: {rows} {notes}")

# --- 61. десятка с цитатой и ревизией живёт, и формула в журнале -----------
rows, tens, notes = j.parse_sty_rows(["line=10@AP-line-2", "color=8", "texture=8", "shade=8"],
                                     [], True)
ok(rows["line"] == 10 and not notes, f"сертифицированная десятка срезана: {rows} {notes}")
ok(tens == ["линия, против якорной пары AP-line-2: расхождений не найдено"],
   f"формула десятки не собрана: {tens}")

# --- 62. девятка без проверки падает в восемь ------------------------------
rows, _, notes = j.parse_sty_rows(["line=9", "color=9", "texture=9", "shade=9"], [], True)
ok(all(v == 8 for v in rows.values()) and len(notes) == 4,
   f"девятки без проверки не порезаны: {rows}")
rows, _, notes = j.parse_sty_rows(["line=9", "color=9@AP-color-1", "texture=9", "shade=9"],
                                  ["line=контур тоньше на плече"], True)
ok(rows["line"] == 9 and rows["color"] == 9 and rows["texture"] == 8,
   f"проверка не учтена: {rows}")

# --- 63. неполный замер — не STY-% -----------------------------------------
try:
    j.parse_sty_rows(["line=9", "color=8", "texture=8"], [], True)
    raise AssertionError("неполный замер принят")
except SystemExit as e:
    ok("нет баллов строк" in str(e), f"сообщение не про недостающие строки: {e}")

# --- 64. арифметика планки: 93 требует двух десяток ------------------------
full10 = {"line": 10, "color": 10, "texture": 9, "shade": 9}
one10 = {"line": 10, "color": 9, "texture": 9, "shade": 9}
ok(j.sty_pct(full10) == 95.0 and j.sty_pct(full10) >= j.STY_TARGET,
   f"10+10+9+9 не даёт 95: {j.sty_pct(full10)}")
ok(j.sty_pct(one10) < j.STY_TARGET,
   f"одной десятки хватает для планки: {j.sty_pct(one10)}")

# --- 65. дельта считается по строкам, а не по баллу ------------------------
d = j.sty_delta({"line": 8, "color": 7, "texture": 7, "shade": 6},
                {"line": 9, "color": 7, "texture": 8, "shade": 6})
ok(d == {"line": 1, "color": 0, "texture": 1, "shade": 0}, f"дельта по строкам неверна: {d}")
ok(j.sty_delta(None, full10) is None, "первый замер обязан не иметь дельты")

# --- 66. замер пишет кортеж {юнит, P, R, сид, эталоны} --------------------
(j.DOCS / "anchors.md").write_text(
    "| AP-line-2 | 9 | линия | x | мягче | a ↔ b | x |\n"
    "| AP-color-3 | 6 | колорит | x | глянец | a ↔ b | x |\n"
    "| AP-texture-1 | 10 | фактура | x | — | a ↔ b | x |\n"
    "| AP-shade-1 | 10 | светотень | x | — | a ↔ b | x |\n", encoding="utf-8")
q = j.load()
q["IMG-001"]["file"] = "attempts/IMG-001/krea2_IMG-001_v1_P2R0.webp"
q["IMG-001"]["prompt_version"], q["IMG-001"]["render_version"] = "P2", "R0"
j.save(q)
(j.ATTEMPTS / "IMG-001").mkdir(parents=True, exist_ok=True)
j.cmd_sty(Args(id="IMG-001", rows=["line=10@AP-line-2", "color=9", "texture=9@AP-texture-1",
                                   "shade=9"],
               gap=["color=кожа холоднее", "shade=тень теплее"], judge_pass="revision"))
rec = j.load()["IMG-001"]["history"][-1]
ok(rec["kind"] == "sty" and rec["seed"] == j.SEED_PIN and rec["etalons"] == j.etalon_version(),
   f"в замере нет сида/эталонов: {rec}")
ok(rec["prompt_version"] == "P2" and rec["render_version"] == "R0",
   f"в замере нет пары версий: {rec}")
ok(rec["sty_pct"] == 92.5 and rec["delta"] is None, f"первый замер: {rec['sty_pct']} {rec['delta']}")
j.cmd_sty(Args(id="IMG-001", rows=["line=10@AP-line-2", "color=10@AP-color-3",
                                   "texture=9@AP-texture-1", "shade=9@AP-shade-1"],
               gap=[], judge_pass="revision"))
rec2 = j.load()["IMG-001"]["history"][-1]
ok(rec2["sty_pct"] == 95.0 and rec2["delta"]["color"] == 1,
   f"дельта по строкам не записана: {rec2['sty_pct']} {rec2['delta']}")
rep = (j.DOCS / "report.md").read_text()
ok("расхождений не найдено" in rep and "эталонами test-etalon-1" not in rep,
   "журнал не пишет цитату якоря")
ok("сид 43" in rep, "журнал не пишет сид")

# --- 67. цитата обязана ссылаться на пару из реестра -----------------------
(j.DOCS / "anchors.md").write_text("| AP-line-2 | 9 | ... |\n", encoding="utf-8")
try:
    j.cmd_sty(Args(id="IMG-001", rows=["line=9@AP-line-99", "color=9@AP-line-2",
                                       "texture=9@AP-line-2", "shade=9@AP-line-2"],
                   gap=[], judge_pass="revision"))
    raise AssertionError("несуществующий якорь принят")
except SystemExit as e:
    ok("AP-line-99" in str(e), f"движок не назвал мёртвый якорь: {e}")

# --- 68. реестр якорей: структура и слепая сверка ---------------------------
for uid2 in ("IMG-001", "IMG-002"):
    (j.LAB / "attempts" / uid2).mkdir(parents=True, exist_ok=True)
    for nm in ("ref_a.png", "gen_b.webp"):
        im = Image.new("RGB", (64, 64), (240, 230, 220))
        im.save(j.LAB / "attempts" / uid2 / nm)
reg = "\n".join([
    "| ID | Балл | Строка | Происхождение | Направление | Пара | Что видно |",
    "| --- | --- | --- | --- | --- | --- | --- |",
    "| AP-line-1 | 10 | линия | эталон↔эталон | — | attempts/IMG-001/ref_a.png ↔ attempts/IMG-002/ref_a.png | ок",
    "| AP-line-3 | 6 | линия | эталон↔попытка | мягче | attempts/IMG-001/ref_a.png ↔ attempts/IMG-001/gen_b.webp | ок",
    "| AP-line-4 | 7 | линия | эталон↔попытка | мягче | attempts/IMG-001/ref_a.png ↔ attempts/IMG-002/gen_b.webp | ок",
]) + "\n"
j.ANCHORS.write_text(reg, encoding="utf-8")
ok(len(j.anchor_rows()) == 3, "реестр разобрался не целиком")
import contextlib, io
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    rc = j.cmd_anchors(Args(what="check", id=None, mark=None, judge_pass="revision", judge=""))
ok(rc == 1 and any("линия" in x and "одним дрейфом" in x
                   for x in buf.getvalue().splitlines()),
   f"пары одним дрейфом не найдены: {buf.getvalue()}")
j.ANCHORS.write_text(reg.replace("| AP-line-4 | 7 | линия | эталон↔попытка | мягче |",
                                 "| AP-line-4 | 7 | линия | эталон↔попытка | контур-тяжелее |"),
                     encoding="utf-8")
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    rc = j.cmd_anchors(Args(what="check", id=None, mark=None, judge_pass="revision", judge=""))
ok(not any("линия" in x for x in buf.getvalue().splitlines()),
   f"целая строка линии дала находки: {buf.getvalue()}")

# --- 69. слепой проход: уровень скрыт до записи, полоса 5–6 засчитана -------
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    j.cmd_anchors(Args(what="show", id="AP-line-3", mark=None, judge_pass="revision", judge=""))
shown = buf.getvalue()
ok(" 6" not in shown and "заявлено" not in shown, f"show показал уровень: {shown}")
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    j.cmd_anchors(Args(what="score", id="AP-line-3", mark="line=5",
                       judge_pass="revision", judge="владелец"))
ok("подтверждено" in buf.getvalue(), f"полоса 5–6 не засчитана: {buf.getvalue()}")
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    j.cmd_anchors(Args(what="score", id="AP-line-3", mark="line=9",
                       judge_pass="revision", judge="владелец"))
ok("переприсмотр" in buf.getvalue(), f"расхождение не замечено: {buf.getvalue()}")
log = json.loads((j.DOCS / "anchor-log.json").read_text())
ok(log[-1]["anchors"] == j.anchors_version() and log[-1]["etalons"] == j.etalon_version(),
   f"в лог якорей не попал кортеж версии: {log[-1]}")

# --- 70. контроли вслепую не портят термостат десяток -----------------------
def thermo():
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        j.cmd_stat(None)
    return [x for x in out.getvalue().splitlines() if "десятки:" in x]


before = thermo()
ok(before, "до контроля термостат не печатался")
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    j.cmd_sty(Args(id="IMG-001", rows=["line=10@AP-line-1", "color=10@AP-line-1",
                                       "texture=10@AP-line-1", "shade=10@AP-line-1"],
                   gap=[], judge_pass="revision", control="AP-line-1"))
ok(thermo() == before, f"контроль вслепую сдвинул термостат: {before} -> {thermo()}")

print(f"OK: проверок {checks}")

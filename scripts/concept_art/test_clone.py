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
j.ANCHOR_MANIFEST = j.REFS / "anchors-manifest.json"

unit = {"unit": "IMG-001", "reference": "references/crops/IMG-001.png", "category": "unit-01",
        "sheet": "references/unit-01.jpeg", "cell": 1,
        "model": "krea2", "status": "in-queue", "version": 0, "versions": {}, "best_score": None,
        "max_attempts": j.MAX_ATTEMPTS, "subject": "бравый воин", "history": []}
def seal():
    """Реестр правится тестами часто; каждый раз — перепечатка, иначе гейт прав."""
    j.cmd_anchors(Args(what="seal", id=None, mark=None, judge_pass="revision",
                       judge="", klass="independent"))


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

# --- прогон без печати не считается: харнесс печатает то, что он придумал ----
def stamp(uid="IMG-001"):
    q = j.load()
    u = q[uid]
    u["seal"] = j.run_seal(u, u["model"], u["version"], j.json.loads(j.SPEC.read_text()))
    j.save(q)

# --- accept закрыт до порога, открыт на пороге
q = j.load()
q["IMG-001"].update(model="krea2", version=1, file="attempts/IMG-001/krea2_IMG-001_v1.webp")
j.save(q)
stamp()
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
stamp()
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
ok(j.attempt_name(unit, "krea2", 2) == "krea2_IMG-001_v2",
   f"имя попытки не по шаблону <model>_<unit>_v<N>: {j.attempt_name(unit, 'krea2', 2)}")

# --- 57. линт стилевого блока ----------------------------------------------
card = ("## 1. Линия\n\n| Признак | Формулировка | Источник |\n| --- | --- | --- |\n"
        "| Контур | `clean dark contour line` | x |\n\n"
        "## 2. Цвет\n\n| Признак | Формулировка | Источник |\n| --- | --- | --- |\n"
        "| Кожа | `warm ochre skin` | x |\n\n"
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
q = j.load()
q["IMG-001"].update(status="model-ceiling", ceilings={"ernie": {"sty": 71, "cycle": 2}})
j.save(q)
j.cmd_reopen(Args(id="IMG-001", note="рычаг не проверен на живучесть", stages=None))
back = j.load()["IMG-001"]
ok(back["status"] == "in-queue", "reopen не вернул юнит в очередь")
ok(not back.get("ceilings"), "reopen оставил стадии в потолке — цепочка осталась пустой")
ok("ernie" in (j.DOCS / "report.md").read_text(), "снятие потолка не описано в журнале")
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
seal()
q = j.load()
q["IMG-001"]["file"] = "attempts/IMG-001/krea2_IMG-001_v1_P2R0.webp"
q["IMG-001"]["prompt_version"], q["IMG-001"]["render_version"] = "P2", "R0"
j.save(q)
(j.ATTEMPTS / "IMG-001").mkdir(parents=True, exist_ok=True)
stamp()
j.cmd_sty(Args(id="IMG-001", rows=["line=10@AP-line-2", "color=9", "texture=9@AP-texture-1",
                                   "shade=9"],
               gap=["color=кожа холоднее", "shade=тень теплее"], judge_pass="revision"))
rec = j.load()["IMG-001"]["history"][-1]
ok(rec["seed"] == 43,
   f"в замере не пин-сид прогона: {rec['seed']}")
ok(rec["kind"] == "sty" and rec["etalons"] == j.etalon_version(),
   f"в замере нет сида/эталонов: {rec}")
ok(rec["prompt_version"] == "P2" and rec["render_version"] == "R0",
   f"в замере нет пары версий: {rec}")
ok(rec["sty_pct"] == 92.5 and rec["delta"] is None, f"первый замер: {rec['sty_pct']} {rec['delta']}")
stamp()
j.cmd_sty(Args(id="IMG-001", rows=["line=10@AP-line-2", "color=10@AP-color-3",
                                   "texture=9@AP-texture-1", "shade=9@AP-shade-1"],
               gap=[], judge_pass="revision"))
rec2 = j.load()["IMG-001"]["history"][-1]
ok(rec2["sty_pct"] == 95.0 and rec2["delta"]["color"] == 1,
   f"дельта по строкам не записана: {rec2['sty_pct']} {rec2['delta']}")
rep = (j.DOCS / "report.md").read_text()
ok("расхождений не найдено" in rep and "эталонами test-etalon-1" not in rep,
   "журнал не пишет цитату якоря")
seed_real = j.load()["IMG-001"]["seal"]["seed"]
ok(f"сид {seed_real}" in rep, f"журнал не пишет затравка печати {seed_real}")
ok(seed_real == 43, f"печать запечатала не пин-сид: {seed_real}")

# --- 66b. замер стадии цепочки, а не последнего прогона --------------------
q = j.load()
q["IMG-001"].setdefault("versions", {})["ernie"] = 2
j.save(q)
Image.new("RGB", (8, 8), (255, 255, 255)).save(j.ATTEMPTS / "IMG-001" / "ernie_IMG-001_v2.webp")
j.cmd_sty(Args(id="IMG-001", model="ernie", gap=[],
               rows=["line=9@AP-line-2", "color=9", "texture=9", "shade=9"]))
rec = j.load()["IMG-001"]["history"][-1]
ok(rec["model"] == "ernie" and rec["version"] == 2,
   f"замер стадии приписан последнему прогону: {rec['model']} v{rec['version']}")
ok(rec["file"].endswith("ernie_IMG-001_v2.webp"), f"замер не по кадру стадии: {rec['file']}")

# --- 67. цитата обязана ссылаться на пару из реестра -----------------------
(j.DOCS / "anchors.md").write_text("| AP-line-2 | 9 | ... |\n", encoding="utf-8")
seal()
try:
    stamp()
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
seal()
ok(len(j.anchor_rows()) == 3, "реестр разобрался не целиком")
import contextlib, io
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    rc = j.cmd_anchors(Args(what="check", id=None, mark=None, judge_pass="revision",
                            judge="", klass="independent"))
ok(rc == 1 and any("линия" in x and "одним дрейфом" in x
                   for x in buf.getvalue().splitlines()),
   f"пары одним дрейфом не найдены: {buf.getvalue()}")
j.ANCHORS.write_text(reg.replace("| AP-line-4 | 7 | линия | эталон↔попытка | мягче |",
                                 "| AP-line-4 | 7 | линия | эталон↔попытка | контур-тяжелее |"),
                     encoding="utf-8")
seal()
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    rc = j.cmd_anchors(Args(what="check", id=None, mark=None, judge_pass="revision", judge=""))
ok(not any("линия" in x for x in buf.getvalue().splitlines()),
   f"целая строка линии дала находки: {buf.getvalue()}")

# --- 69. слепой проход: уровень скрыт до записи, полоса 5–6 засчитана -------
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    j.cmd_anchors(Args(what="show", id="AP-line-3", mark=None, judge_pass="revision",
                       judge="", klass="independent"))
shown = buf.getvalue()
ok(" 6" not in shown and "заявлено" not in shown, f"show показал уровень: {shown}")
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    j.cmd_anchors(Args(what="score", id="AP-line-3", mark="line=5",
                       judge_pass="revision", judge="владелец", klass="independent"))
ok("подтверждено" in buf.getvalue(), f"полоса 5–6 не засчитана: {buf.getvalue()}")
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    j.cmd_anchors(Args(what="score", id="AP-line-3", mark="line=9",
                       judge_pass="revision", judge="владелец", klass="independent"))
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
    stamp()
    j.cmd_sty(Args(id="IMG-001", rows=["line=10@AP-line-1", "color=10@AP-line-1",
                                       "texture=10@AP-line-1", "shade=10@AP-line-1"],
                   gap=[], judge_pass="revision", control="AP-line-1"))
ok(thermo() == before, f"контроль вслепую сдвинул термостат: {before} -> {thermo()}")

# --- 71. словарь стиля меряется строже задачи: отрицаний в нём нет ----------
found = j.lint_card("## 1. Линия\n\n| a | b | c |\n| --- | --- | --- |\n"
                    "| Контур | `no outlines, never floating` | x |\n")
ok(len(found) == 1 and "Контур" in found[0] and "never" in found[0],
   f"словарь с отрицанием не найден: {found}")
ok(not j.lint_card("## Отрицания\n\n| a | b | c |\n| --- | --- | --- |\n"
                   "| Контур | `no outlines` | x |\n"),
   "журнал отрицаний проверен как словарь")

# --- 72. реестр якорей под гейтом: молча порвать прибор нельзя --------------
try:
    j.ANCHORS.write_text(j.ANCHORS.read_text() + "| AP-line-9 | 5 | линия | x | — | a ↔ b | x |\n",
                         encoding="utf-8")
    j.cmd_stat(None)
    raise AssertionError("изменённый реестр принят")
except SystemExit as e:
    ok("изменён после опечатки" in str(e), f"гейт назвал причину иначе: {e}")
seal()
ok(j.anchors_version() == json.loads(j.ANCHOR_MANIFEST.read_text())["version"],
   "печать не сошлась с живым реестром")

# --- 73. класс судьи записан; self — floor-check, не подтверждение ----------
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    j.cmd_anchors(Args(what="score", id="AP-line-3", mark="line=5", judge_pass="revision",
                       judge="агент", klass="self"))
ok("floor-check" in buf.getvalue(), f"self не помечен floor-checkом: {buf.getvalue()}")
ok(json.loads((j.DOCS / "anchor-log.json").read_text())[-1]["klass"] == "self",
   "класс судьи не записан")

# --- 74. материал слепого прохода под печатью: подмена доски ловится --------
row3 = next(x for x in j.anchor_rows() if x["id"] == "AP-line-3")
board = j.board_path(row3)
ok(json.loads(j.ANCHOR_MANIFEST.read_text())["boards"].get("AP-line-3") and board.is_file(),
   "доска слепого прохода не попала в печать")
ok(board.name != "AP-line-3.png", f"доска снова по одной паре: {board.name}")
man = json.loads(j.ANCHOR_MANIFEST.read_text())["boards"]
sheet = [x["id"] for x in j.chunk_of(j.anchor_rows(), row3)]
ok(len(sheet) == 2 and len({man[i] for i in sheet}) == 1,
   f"лист 2×2 не накрывает обе пары одной печатью: {sheet}")
board.write_bytes(b"not a board")
try:
    j.cmd_stat(None)
    raise AssertionError("подменённая доска принята")
except SystemExit as e:
    ok("расходится с опечатанной" in str(e), f"подмена доски не замечена: {e}")
seal()
ok(j.load()["IMG-001"], "после перепечати прибор не вернулся")

# --- 75. жанровый слот: ровно один якорь на версию --------------------------
slot_card = ("## 0. Семейство\n\n| a | b | c |\n| --- | --- | --- |\n"
             "| Жанр | `comic book` \\| `cartoon` | x |\n\n"
             "## 2. Цвет\n\n| a | b | c |\n| --- | --- | --- |\n"
             "| Кожа | `warm ochre skin` | x |\n")
mix = j.lint_style("comic book, cartoon, warm ochre skin", slot_card)
ok(any("смешаны якоря слота" in m and "cartoon" in m for m in mix),
   f"смешение жанров не найдено: {mix}")
one = j.lint_style("comic book, warm ochre skin", slot_card)
ok(not any("смешаны" in m for m in one), f"один жанр помечен смешением: {one}")
ok(j.card_rows(slot_card) == [("Кожа", "warm ochre skin")],
   f"слот разборался как обязательная строка: {j.card_rows(slot_card)}")

# --- 76. печать прогона: без неё балл не ставится, расхождение снимает её -----
q = j.load()
q["IMG-001"].update(model="krea2", version=1,
                    file="attempts/IMG-001/krea2_IMG-001_v1.webp")
q["IMG-001"].pop("seal", None)
j.save(q)
try:
    j.cmd_score(Args(id="IMG-001", criteria=["comp=9"], note=""))
    ok(False, "балл поставлен прогону без печати")
except SystemExit as e:
    ok("не запечатан" in str(e), f"отказ не про печать: {e}")
stamp()
for k in ("etalon", "sheet", "seed", "prompt_version", "render_version", "dictionary",
          "instrument", "judge"):
    ok(k in j.load()["IMG-001"]["seal"], f"в печати нет {k}")
ok(j.cmd_verify(Args(id="IMG-001")) == 0, "печать не сверилась")
(j.DOCS / "style-card.md").write_text("словарь переписан")
ok(j.cmd_verify(Args(id="IMG-001")) == 1 and not j.load()["IMG-001"].get("seal"),
   "расхождение словаря не сняло печать")

# --- 77. сид пинится: правка промпта затравку не круит (7.2) ----------------
u = {"seed_bump": 5, "prompt_version": "P3"}
ok(not hasattr(j, "next_seed_bump"), "seed_bump вернулся в путь лаборатории")
q = j.load()
q["IMG-001"]["seed_bump"] = 4
q["IMG-001"].pop("seal", None)
j.save(q)
stamp()
ok(j.load()["IMG-001"]["seal"]["seed"] == 43,
   "печать запечатала не пин-сид 43, который уйдёт в граф генератора")

# --- 78. R-блок докручивает рендер, а не перекрикивает модель ---------------
gr = g.workflow("qwen21", {"steps": 25}, art, "ПРОМТ", "NEG", 123, PREFIX,
                {"cfg": 3.0, "sampler": "dpmpp_2m", "scheduler": "karras", "steps": 30})
ks = by_class(gr, "KSampler")[0]["inputs"]
ok((ks["cfg"], ks["sampler_name"], ks["scheduler"]) == (3.0, "dpmpp_2m", "karras"),
   f"R не доехал до сэмплера: {ks}")
ok(ks["steps"] == 25, "R перебил шаги, которые модель объявила сама")
ok(by_class(g.workflow("qwen21", {}, art, "П", "", 1, PREFIX, {"steps": 30}),
            "KSampler")[0]["inputs"]["steps"] == 30,
   "молчаливая модель обязана взять шаги из R")
ok(by_class(g.workflow("qwen21", {"steps": 25}, art, "П", "", 1, PREFIX),
           "KSampler")[0]["inputs"]["cfg"] == 1.0, "без R сэмплер обязан остаться на 1.0")

# --- 78b. turbo-стадия не рисуется чужим рендером (цепочка, 8.10) ----------
turbo = g.workflow("ernie", {"steps": 8, "cfg": 1.0, "sampler": "euler"}, art,
                    "ПРОМТ", "NEG", 43, PREFIX,
                    {"cfg": 3.0, "sampler": "dpmpp_2m", "scheduler": "karras", "steps": 25})
kt = by_class(turbo, "KSampler")[0]["inputs"]
ok((kt["cfg"], kt["steps"], kt["sampler_name"]) == (1.0, 8, "euler"),
   f"R-блок соседней модели перебил рендер стадии: {kt}")

# --- 79. печать пишет грузившийся вес, а не подпись из render ---------------
spec_r = {"prompt_version": "P9", "render": {"id": "R9", "cfg": 3.0, "sampler": "euler",
            "scheduler": "simple", "steps": 25, "checkpoint": "chuzhoi_ves.safetensors"},
          "models": {"qwen21": {"unet": "qwen_image_2.1_int8_convrot.safetensors"}}}
seal_r = j.run_seal({"reference": "references/x.png", "sheet": "sheets/x.png",
                     "category": "unit-01", "unit": "IMG-001"}, "qwen21", 1, spec_r)
ok(seal_r["render"]["checkpoint"] == spec_r["models"]["qwen21"]["unet"],
   "печать приписала вес из подписи render, а не загруженный")
ok(seal_r["render"]["cfg"] == 3.0, "печать не записала cfg прогона")

# --- 79b. печать пишет рендер стадии, а не R-блок поверх модели -------------
spec_t = {"render": {"id": "R1", "cfg": 3.0, "sampler": "dpmpp_2m", "scheduler": "karras",
                     "steps": 25},
          "models": {"ernie": {"unet": "ernie.safetensors", "cfg": 1.0, "steps": 8,
                               "sampler": "euler"}}}
seal_t = j.run_seal({"reference": "references/x.png", "sheet": "sheets/x.png",
                     "category": "unit-01", "unit": "IMG-001"}, "ernie", 1, spec_t)
ok((seal_t["render"]["cfg"], seal_t["render"]["steps"], seal_t["render"]["sampler"]) ==
   (1.0, 8, "euler"), f"печать приписала стадии чужой рендер: {seal_t['render']}")
ok(seal_t["render"]["scheduler"] == "karras", "печать потеряла scheduler из R")

# --- 80. сжатая шкала — не то же самое, что промах пар (8.29) ---------------
def stat_out(log):
    (j.DOCS / "anchor-log.json").write_text(json.dumps(log), encoding="utf-8")
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        j.cmd_anchors(Args(what="stat", id=None, mark=None,
                           judge_pass="revision", judge="", klass=None))
    return out.getvalue()


squeezed = [{"id": "AP-line-1", "given": 8, "declared": 10, "klass": "self"},
            {"id": "AP-line-3", "given": 7, "declared": 6, "klass": "self"}]
seen = stat_out(squeezed)
ok("шкала сжалась" in seen, f"сжатие шкалы не отличается от промаха пар: {seen}")
ok("поставлено 8" in seen, "стат не показывает поставленный балл против заявленного")
honest = [{"id": "AP-line-1", "given": 10, "declared": 10, "klass": "self"},
          {"id": "AP-line-3", "given": 4, "declared": 6, "klass": "self"}]
ok("шкала сжалась" not in stat_out(honest), "здравый расклад помечен сжатием шкалы")

# 81. чужая таблица в файле реестра не двигает версию прибора
body = j.anchors_version()
j.ANCHORS.write_text(j.ANCHORS.read_text() + "\n| AP-line-1 | 10 | 8 | 9 |\n",
                     encoding="utf-8")
ok(j.anchors_version() == body,
   "таблица сравнения судей с префиксом AP- сдвинула версию прибора")

# 82. кондишенинг картинкой запрещён фазе обучения — ни в одном графе
FORBIDDEN = ("IPAdapter", "LoadImage", "VAEEncode", "ControlNet", "Redux", "InstantID",
             "PuLID", "ReferenceLatent", "Blip", "ImageOnly", "Img2Img", "InpaintModelConditioning")
for name, graph in g.WORKFLOWS.items():
    hit = [n["class_type"] for n in graph.values()
           if any(f.lower() in n["class_type"].lower() for f in FORBIDDEN)]
    ok(not hit, f"{name}: в граф вернулся conditioning картинкой {hit} — генерация получает только слова")

# 83. стадии ernie и z-image: латент 1024, негатив обнулён узлом, а не текстом
art1k = dict(art, size=[1024, 1024])
for model in ("ernie", "zimage"):
    gr = g.workflow(model, {"steps": 8, "cfg": 1.0}, art1k, "ПРОМТ", "", 43,
                    f"image-clone/IMG-001/{model}_IMG-001_v1")
    lat = [n["inputs"] for n in gr.values()
           if n["class_type"].startswith("Empty") and n["class_type"].endswith("LatentImage")]
    ok(lat and all(x["width"] == 1024 and x["height"] == 1024 for x in lat),
       f"{model}: латентный узел не переставлен на 1024")
    ks = by_class(gr, "KSampler")[0]["inputs"]
    neg_id = ks["negative"][0]
    ok(gr[neg_id]["class_type"] == "ConditioningZeroOut",
       f"{model}: negative не обнулён узлом ({gr[neg_id]['class_type']}) — текст там мёртв")
    ok(ks["seed"] == 43, f"{model}: граф ушёл не с пином 43")
    ok(by_class(gr, "SaveImage")[0]["inputs"]["filename_prefix"].startswith(f"image-clone/IMG-001/{model}_"),
       f"{model}: имя кадра не доехало до узла сохранения")

# 84. пин-сида: правка, версия и attempt затравку не круят (7.2)
ok(g.seed_of({"seed": 43}, dict(art, seed_bump=9), attempt=5) == 43,
   "spec.seed не пинит затравку")
ok(g.seed_of({}, art, attempt=1) == g.seed_of({}, art, attempt=1) != g.seed_of({}, art, attempt=2),
   "конвейер ассетов потерял выводимую затравку")

# 85. живая спека лаборатории: три стадии, сид 43, кадр 1024, негатив мёртв
lab = json.loads((Path(j.__file__).resolve().parents[2] / "image-clone" / "spec.json").read_text())
ok(lab.get("seed") == 43, f"spec лаборатории без пин-сида: {lab.get('seed')}")
ok(lab.get("chain") == ["krea2", "ernie", "zimage"], f"порядок цепочки: {lab.get('chain')}")
ok(all(c["size"] == [1024, 1024] for c in lab["categories"].values()),
   "не все категории переведены на 1024x1024")
for stage in lab["chain"]:
    ok(stage in g.WORKFLOWS, f"стадии {stage} нет в workflows.json")
    ok(lab["models"][stage].get("negative") == "zeroed",
       f"{stage}: негатив объявлен живым, хотя граф его не читает")
ok("qwen21" not in lab["chain"], "qwen21 вернулась в цепочку (7.8)")

# 86. пропорции головы — отдельный слой замера (7.6)
ok(j.head_ratio("17/15") == {"etalon": 17, "attempt": 15, "delta": -2},
   "пропорции головы записаны не дельтой")
ok(j.head_ratio(None) is None, "пропущенные пропорции должны быть пустяком")
try:
    j.head_ratio("17")
    ok(False, "кривое значение пропорций принято молча")
except SystemExit:
    checks += 1

# 87. стадийная машина: порядок, цикл, «сошлись», пауза, лимит (7.4, 8.4)
sp = {"chain": ["krea2", "ernie", "zimage"], "sty_threshold": {}}


def sty(u, m, pct, cycle):
    u["history"].append({"kind": "sty", "model": m, "sty_pct": pct, "cycle": cycle,
                         "version": 1, "file": "attempts/x.webp"})


u = {"unit": "IMG-001", "history": [], "status": "in-queue", "cycle": 0}
ok(j.stage_of(u, sp) == "krea2", "цепочка началась не с krea2")
sty(u, "krea2", 80, 1)
ok(j.stage_of(u, sp) == "ernie", "закрытая правкой стадия не отдала место следующей")
sty(u, "ernie", 80, 1)
sty(u, "zimage", 80, 1)
cyc = j.advance_chain(u, sp)
ok(cyc and cyc["mean"] == 80 and u["cycle"] == 1 and u["status"] == "in-queue",
   f"первый цикл не замкнут корректно: {cyc} {u['status']}")
for m in ("krea2", "ernie", "zimage"):
    sty(u, m, 80, 2)
j.advance_chain(u, sp)
ok(u["status"] == "paused", f"два круга без движения не встали на паузу: {u['status']}")
ok(set(u.get("ceilings", {})) == {"krea2", "ernie", "zimage"},
   "плоская стадия не снята с требования «все три» (model-ceiling)")
ok(j.stage_of(u, sp) is None, "все стадии в потолке, а цепочка зовёт стадию")
u["status"] = "in-queue"
for m in ("krea2", "ernie", "zimage"):
    sty(u, m, 81, 3)
j.advance_chain(u, sp)
ok(u["status"] == "paused" and len(u["ceilings"]) == 3,
   "движение после потолка молча вернуло стадию в гонку")
u3 = {"unit": "IMG-003", "history": [], "status": "in-queue", "cycle": 0}
for c in (1, 2, 3):
    for m in ("krea2", "ernie", "zimage"):
        sty(u3, m, 70 + c, c)
    j.advance_chain(u3, sp)
ok(u3["status"] == "blocked" and not u3.get("ceilings"),
   f"три круга с движением не исчерпаны: {u3['status']} {u3.get('ceilings')}")
u2 = {"unit": "IMG-002", "history": [], "status": "in-queue", "cycle": 0}
for m in ("krea2", "ernie", "zimage"):
    sty(u2, m, 95, 1)
j.advance_chain(u2, sp)
ok(u2["status"] == "success" and j.stage_of(u2, sp) is None,
   "все три выше порога — а юнит не закрыт")

# 88. доска 2×2 собирается и по неполной цепочке, ярлык — модель · STY-% · CNT
q = j.load()
q["IMG-001"].update({"reference": "references/crops/IMG-001.png", "versions": {"krea2": 1},
                     "history": [{"kind": "sty", "model": "krea2", "sty_pct": 88,
                                  "version": 1, "cycle": 1,
                                  "file": "attempts/IMG-001/krea2_IMG-001_v1.webp",
                                  "head": {"etalon": 17, "attempt": 15, "delta": -2}}]})
j.save(q)
(j.CROPS).mkdir(parents=True, exist_ok=True)
Image.new("RGB", (64, 64), "white").save(j.CROPS / "IMG-001.png")
bp = j.board("IMG-001")
ok(bp.is_file() and bp.parent == j.PAIRS and bp.name == "IMG-001.png",
   f"доска легла не в pairs/<юнит>: {bp}")
ok(Image.open(bp).size == (1036, 1036), f"доска не 2×2: {Image.open(bp).size}")

# --- 87. неизменная пара (P, R) при пин-сиде не жрёт кадр -------------------
q = j.load()
q["IMG-001"].update(status="in-queue", model="krea2", version=1,
                    versions={"krea2": 1}, file="attempts/IMG-001/krea2_IMG-001_v1.webp")
q["IMG-001"]["seals"] = {"krea2_IMG-001_v1": j.run_seal(
    q["IMG-001"], "krea2", 1, json.loads(j.SPEC.read_text()))}
j.save(q)
seen_argv.clear()
sub_run, j.subprocess.run = j.subprocess.run, fake_run
try:
    try:
        j.cmd_next(Args(model="krea2", id="IMG-001", force=False))
        raised = ""
    except SystemExit as exc:
        raised = str(exc)
    ok("побайтово" in raised, f"повтор прогона с неизменной парой не остановлен: {raised!r}")
    ok(not (j.ATTEMPTS / "IMG-001" / "krea2_IMG-001_v2.webp").exists(),
       "стопор сработал уже после генерации кадра")
    j.cmd_next(Args(model="krea2", id="IMG-001", force=True))
finally:
    j.subprocess.run = sub_run
ok(len(seen_argv) == 1, "--force не обошёл стопор побайтового повтора")

# --- 88. круг живёт на одной паре (P, R) ------------------------------------
spec_raw = j.SPEC.read_text()
spec = json.loads(spec_raw)
spec["chain"] = ["krea2", "ernie", "zimage"]        # круг меряется тремя стадиями
j.SPEC.write_text(json.dumps(spec, ensure_ascii=False, indent=1))
q = j.load()
u = q["IMG-001"]
u.update(status="in-queue", history=[], cycle=0, cycles=[], ceilings={},
         versions={"krea2": 2, "ernie": 1, "zimage": 1}, model="krea2", version=2,
         file="attempts/IMG-001/krea2_IMG-001_v2.webp")
u["seal"] = j.run_seal(u, "krea2", 2, spec)
j.save(q)
j.cmd_sty(Args(id="IMG-001", model="krea2", gap=[],
               rows=["line=8", "color=8", "texture=8", "shade=8"]))
ok(j.load()["IMG-001"]["cycle"] == 0, "круг закрылся раньше трёх стадий")
spec["prompt_version"] = "P4"
j.SPEC.write_text(json.dumps(spec, ensure_ascii=False, indent=1))
q = j.load(); u = q["IMG-001"]
Image.new("RGB", (8, 8), (255, 255, 255)).save(j.ATTEMPTS / "IMG-001" / "ernie_IMG-001_v1.webp")
u.update(model="ernie", version=1, file="attempts/IMG-001/ernie_IMG-001_v1.webp")
u["seal"] = j.run_seal(u, "ernie", 1, spec)
j.save(q)
j.cmd_sty(Args(id="IMG-001", model="ernie", gap=[],
               rows=["line=6", "color=6", "texture=6", "shade=6"]))
u = j.load()["IMG-001"]
ok(u["cycle"] == 1 and u["history"][-1]["cycle"] == 2,
   f"смена P в середине круга не расплела его: cycle={u['cycle']} {u['history'][-1]['cycle']}")
ok(not any(c["cycle"] == 1 for c in u["cycles"]), "распавшийся круг попал в реестр кругов")
ok(u["history"][-1]["pair"] == ["P4", u["history"][-1]["render_version"]],
   "замер не запомнил пару круга")
q = j.load(); u = q["IMG-001"]
u.update(model="krea2", version=2, file="attempts/IMG-001/krea2_IMG-001_v2.webp")
u["seal"] = j.run_seal(u, "krea2", 2, spec)
j.save(q)
j.cmd_sty(Args(id="IMG-001", model="krea2", gap=[],
               rows=["line=6", "color=8", "texture=8", "shade=8"]))
d = j.load()["IMG-001"]["history"][-1]["delta"]
ok(d["line"] == -2, f"дельта взята не со своей стадии (ernie 6 вместо krea2 8): {d}")
j.SPEC.write_text(spec_raw)

print(f"OK: проверок {checks}")

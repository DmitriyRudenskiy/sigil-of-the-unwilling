#!/usr/bin/env python3
"""Самопроверка генератора концепт-арта: `python3 scripts/concept_art/test_generate.py`.

Без фреймворка: assert-ы. Покрывает то, что нельзя увидеть глазами на одном прогоне —
воротчики размера/белизны/яркости, воспроизводимость затравки, полноту перечисления,
сборку запроса. Обращения к серверу нет.
"""
import sys
import tempfile
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate as g                                            # noqa: E402

SPEC = g.load_spec()
N = 64
checks = 0


def ok(cond, what):
    global checks
    assert cond, f"FAIL: {what}"
    checks += 1


def write(name: str, color, size=(N, N), object_=True) -> Path:
    """Кадр size с рамкой цвета color; object_ — нарисован ли в центре объект (фигура в полроста)."""
    p = Path(tmp) / name
    im = Image.new("RGB", size, color)
    if object_:
        for x in range(int(size[0] * 0.40), int(size[0] * 0.60)):
            for y in range(int(size[1] * 0.15), int(size[1] * 0.85)):
                im.putpixel((x, y), (30, 30, 30))
    im.save(p)
    return p


with tempfile.TemporaryDirectory() as tmp:
    # --- каталог: расхождение count/len(items) падает, id уникальны, счёт сходится
    bad = Path(tmp) / "bad.json"
    bad.write_text(Path(g.SPEC_PATH).read_text().replace('"count": 12', '"count": 11', 1))
    try:
        g.load_spec(bad)
        ok(False, "count != len(items) не уронил загрузку")
    except SystemExit as exc:
        ok("units" in str(exc) and "11" in str(exc) and "12" in str(exc), f"сообщение о count: {exc}")

    subjects = [it["id"] for c in SPEC["categories"].values() for it in c["items"]]
    ok(len(subjects) == 77, f"сюжетов {len(subjects)} != 77")
    ok(len(SPEC["variants"]) == 5, "вариантов != 5")

    # --- перечисление: 385 артефактов, по одному на пару (вариант, сюжет), фильтры
    arts = g.artifacts(SPEC, model="krea2")
    ok(len(arts) == 385, f"артефактов {len(arts)} != 385")
    ok(len({(x["variant"], x["id"]) for x in arts}) == 385, "есть пара (вариант, сюжет) без повтора")
    ok(len(g.artifacts(SPEC, variants=[SPEC["variants"][0]["id"]])) == 77, "фильтр по варианту")
    ok(len(g.artifacts(SPEC, categories=["ui"])) == 25, "фильтр по категории ui")
    ok(len(g.artifacts(SPEC, only=["cursor_default"])) == 5, "фильтр --only")
    ok(all(x["path"].as_posix().startswith("concept_art/") for x in arts), "путь вне concept_art/")
    ok(not any("game/assets" in x["path"].as_posix() for x in arts), "путь попал в game/assets")

    # --- затравка: детерминирована, разная для разных артефактов
    s1 = g.seed_for("v1_candlelight", "cursors", "cursor_default")
    ok(s1 == g.seed_for("v1_candlelight", "cursors", "cursor_default"), "затравка не воспроизводится")
    ok(s1 != g.seed_for("v2_grim_diorama", "cursors", "cursor_default"), "затравка не зависит от варианта")
    ok(0 <= s1 < 2**31, "затравка вне диапазона")

    # --- слои запроса: стиль эталона -> техника варианта -> кадр -> сюжет
    v = SPEC["variants"][0]
    cat = SPEC["categories"]["cursors"]
    item = cat["items"][0]
    p_krea, n_krea = g.build_prompt(v, cat, item, negative_param=False)
    p_qwen, n_qwen = g.build_prompt(v, cat, item, negative_param=True)
    ok(p_krea.startswith(cat["style"] + ", " + v["style"]), "слои запроса перепутаны (эталон -> вариант)")
    ok(item["subject"] in p_krea, "сюжет потерялся в запросе")
    ok(n_krea == "" and f"no {v['negative']}" in p_krea, "негатив не уехал в запрос для Krea-2")
    ok(n_qwen == v["negative"], "негатив не попал в negative_prompt для Qwen")
    same = [g.build_prompt(vv, cat, item, False)[0] for vv in SPEC["variants"]]
    ok(all(item["subject"] in p for p in same), "формулировка сюжета поехала по вариантам")
    ok(all(p.startswith(cat["style"]) for p in same), "стиль эталона не общий для всех вариантов")
    ok(len({vv["style"] for vv in SPEC["variants"]}) == 5, "техники вариантов не уникальны")

    # --- правило: кадр повторяет эталон категории, вариант двигает только технику рендера
    BANNED = ("proportion", "heads", "palette", "thatch", "timber", "gold", "steel", "leather",
              "knight", "ore", "medallion", "parchment")
    for vv in SPEC["variants"]:
        low = vv["style"].lower()
        ok(not any(w in low for w in BANNED),
           f"вариант {vv['id']} лезет в пропорции/палитру/материалы эталона")
    for cname, c in SPEC["categories"].items():
        ok(c.get("style") and c.get("reference"), f"у категории {cname} нет эталона или его описания")
        ok((SPEC["_references"] / c["reference"]).is_file(), f"эталон {cname} не найден на диске")

    # --- воротчик белизны калибруется по эталону: сам эталон обязан его проходить
    ref = Image.open(SPEC["_references"] / SPEC["categories"]["units"]["reference"]).convert("RGB")
    ok(g.white_ratio(ref) >= g.WHITE_MIN, "эталон не проходит собственный воротчик белизны")
    ok(25 <= g.mean_luma(ref) <= 235, "эталон не проходит воротчик яркости")

    # --- воротчик размера
    p = write("right.webp", (255, 255, 255))
    good, _ = g.check_image(p, (N, N), isolated=True)
    ok(good, "белый кадр с объектом не прошёл проверки")
    ok(not g.check_image(p, (1024, 1024), isolated=True)[0], "чужой размер принят")

    # --- воротчик белизны: чёрный и серый фон отсекаются, белый — нет
    ok(g.white_ratio(Image.open(write("purewhite.webp", (255, 255, 255), object_=False))) == 1.0,
       "белизна белого != 1")
    ok(g.white_ratio(Image.open(write("black.webp", (0, 0, 0)))) == 0.0, "белизна чёрного != 0")
    ok(not g.check_image(write("blackbg.webp", (0, 0, 0)), (N, N), isolated=True)[0], "чёрный фон принят")
    ok(not g.check_image(write("greybg.webp", (128, 128, 128)), (N, N), isolated=True)[0], "серый фон принят")

    # --- воротчик пустоты: белая заготовка без объекта — не результат
    blank = write("blank.webp", (255, 255, 255), object_=False)
    ok(g.content_ratio(Image.open(blank)) == 0.0, "пустой центр посчитан непустым")
    ok(not g.check_image(blank, (N, N), isolated=True)[0], "пустой белый лист принят как результат")

    # --- воротчик «листа с вариантами»: кадр, разрезанный пустой полосой, — не одиночный объект
    sheet = Path(tmp) / "sheet.webp"
    im = Image.new("RGB", (N, N), (255, 255, 255))
    for x0 in (N // 8, N // 2 + N // 8):
        for y0 in (N // 8, N // 2 + N // 8):
            for x in range(x0, x0 + N // 5):
                for y in range(y0, y0 + N // 5):
                    im.putpixel((x, y), (40, 40, 40))
    im.save(sheet)
    ok(g.seam_ratio(Image.open(sheet)) > g.SEAM_MAX, "шов листа 2x2 не посчитан швом")
    ok(not g.check_image(sheet, (N, N), isolated=True)[0], "лист 2x2 принят как одиночный объект")
    ok(g.seam_ratio(Image.open(write("figure.webp", (255, 255, 255)))) < g.SEAM_MAX,
       "шов посчитан у кадра с одиночной фигурой")

    # --- воротчик яркости кадров без требования белого фона (экраны UI)
    ok(g.mean_luma(Image.open(write("blank.webp", (255, 255, 255), object_=False))) == 255,
       "яркость белого != 255")
    ok(not g.check_image(write("darkui.webp", (10, 10, 10)), (N, N), isolated=False)[0],
       "почти чёрный экран принят")
    ok(not g.check_image(write("whiteui.webp", (255, 255, 255), object_=False), (N, N), isolated=False)[0],
       "выбитый в белый экран принят")

    # --- экспорт в WEBP сохраняет размер и режим RGB
    src = Path(tmp) / "src.png"
    Image.new("RGBA", (N, N), (10, 20, 30, 0)).save(src)
    dst = Path(tmp) / "dst.webp"
    g.to_webp(src, dst, 82)
    im = Image.open(dst)
    ok(im.mode == "RGB" and im.size == (N, N), f"экспорт: {im.mode} {im.size}")

    # --- листы: матрица и лист варианта существуют и не пустые
    root = Path(tmp) / "concept_art"
    for art in g.artifacts(SPEC, categories=["cursors"], model="krea2"):
        art["path"].parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGB", (32, 32), (255, 255, 255)).save(art["path"])
    sheets = g.contact_sheets(SPEC, root, "krea2")
    ok(len(sheets) == 1 + len(SPEC["variants"]), f"листов {len(sheets)} != 6")
    ok(Image.open(sheets[0]).size[0] >= 1000, "матрица уже 1000 px по ширине")
    ok(all(s.exists() and s.stat().st_size > 1000 for s in sheets), "есть пустой лист")

    # --- борд стиля: в каждой строке первым стоит эталон категории
    for v in SPEC["variants"]:
        d = root / "krea2" / v["id"] / "cursors"
        d.mkdir(parents=True, exist_ok=True)
        Image.new("RGB", (32, 32), (255, 0, 0)).save(d / "c_arrow.webp")
    board = g.style_board(SPEC, root, "krea2")
    ok(board.exists() and Image.open(board).size[0] > 1000, "борд стиля не собран")
    ok(board.name == "board_style_krea2.webp", f"борд не привязан к модели: {board.name}")

print(f"OK: проверок {checks}")

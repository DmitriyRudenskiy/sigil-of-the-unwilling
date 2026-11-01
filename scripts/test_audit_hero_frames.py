#!/usr/bin/env python3
"""Тесты аудитора комплекта фигур (задача 3.6 смены `alpha-battle-field`).

Быстрая проверка из задачи требует ровно двух вещей: аудит **падает на
подставленном файле без альфы** и **проходит на комплекте**. Первый случай —
`test_без_альфы_красно`, второй — `test_чистый_комплект_зелено` (он же держит
допуски: живой комплект 2026-10-30 проходит с теми же числами). Остальные
кейсы закрывают каждую ось по отдельности — иначе «красно» не отличимо от
«покраснело не по той причине».
"""
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audit_hero_frames as ah  # noqa: E402

CANVAS, FEET_Y, FIGURE_H = 64, 56, 48


def _manifest(hero_dir: Path) -> None:
    (hero_dir / "frames_manifest.json").write_text(
        json.dumps({"canvas": CANVAS, "feet_y": FEET_Y, "figure_h": FIGURE_H,
                    "frames": {}}), encoding="utf-8")


def _frame(hero_dir: Path, name: str, box=(20, 8, 44, 56), canvas=CANVAS,
           mode="RGBA", fills=()) -> Path:
    """Кадр с силуэтом в прямоугольнике box (правая/нижняя граница исключаются).

    По умолчанию силуэт стоит ногами на y=55 при опоре 448-масштаба 56 и имеет
    рост 48 — то есть проходит допуски аудитора.
    """
    image = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    for x in range(box[0], box[2]):
        for y in range(box[1], box[3]):
            image.putpixel((x, y), (200, 160, 120, 255))
    for x, y in fills:
        image.putpixel((x, y), (0, 255, 0, 255))
    if mode != "RGBA":
        image = image.convert(mode)
    path = hero_dir / name
    image.save(path)
    return path


def _kit(tmp_path: Path, frames=None) -> Path:
    """Комплект из одного героя с двумя чистыми кадрами (или тем, что передали)."""
    sprites = tmp_path / "game/assets/sprites"
    hero = sprites / "knights"
    hero.mkdir(parents=True)
    _manifest(hero)
    for name in (frames or ["knights_idle_01.png", "knights_walk_01.png"]):
        if not (hero / name).exists():
            _frame(hero, name)
    return sprites


def _audit(tmp_path: Path, frames=None):
    sprites = _kit(tmp_path, frames)
    return ah.audit(sprites)


def test_чистый_комплект_зелено(tmp_path):
    res = _audit(tmp_path)
    assert res["checked"] == 2 and res["rejected"] == 0, res["files"]


def test_без_альфы_красно(tmp_path):
    sprites = tmp_path / "game/assets/sprites"
    hero = sprites / "knights"
    hero.mkdir(parents=True)
    _manifest(hero)
    _frame(hero, "knights_idle_01.png", mode="RGB")
    _frame(hero, "knights_walk_01.png")
    res = ah.audit(sprites)
    assert res["rejected"] == 1
    bad = [r for r in res["files"] if not r["ok"]][0]
    assert bad["file"] == "knights_idle_01.png"
    assert "нет альфа-канала" in bad["problems"][0]


def test_чужой_холст_красно(tmp_path):
    sprites = tmp_path / "game/assets/sprites"
    hero = sprites / "knights"
    hero.mkdir(parents=True)
    _manifest(hero)
    _frame(hero, "knights_idle_01.png", canvas=32, box=(10, 4, 22, 28))
    res = ah.audit(sprites)
    assert any("размер 32×32" in p for p in res["files"][0]["problems"])


def test_ноги_ниже_опоры_красно(tmp_path):
    """Силуэт, уехавший за опорную линию, — кадр «проваленного в землю» героя."""
    sprites = tmp_path / "game/assets/sprites"
    hero = sprites / "knights"
    hero.mkdir(parents=True)
    _manifest(hero)
    _frame(hero, "knights_idle_01.png", box=(20, 12, 44, 63))
    res = ah.audit(sprites)
    assert any("опорная точка вне допуска" in p for p in res["files"][0]["problems"])


def test_ноги_выше_опоры_красно(tmp_path):
    """Плавающий над землёй силуэт — тот же дефект, только в другую сторону."""
    sprites = tmp_path / "game/assets/sprites"
    hero = sprites / "knights"
    hero.mkdir(parents=True)
    _manifest(hero)
    _frame(hero, "knights_idle_01.png", box=(20, 4, 44, 40))
    res = ah.audit(sprites)
    assert any("опорная точка вне допуска" in p for p in res["files"][0]["problems"])


def test_касание_края_красно(tmp_path):
    sprites = tmp_path / "game/assets/sprites"
    hero = sprites / "knights"
    hero.mkdir(parents=True)
    _manifest(hero)
    _frame(hero, "knights_idle_01.png", box=(0, 8, 44, 56))
    res = ah.audit(sprites)
    assert any("касается края кадра" in p for p in res["files"][0]["problems"])


def test_кривой_рост_красно(tmp_path):
    sprites = tmp_path / "game/assets/sprites"
    hero = sprites / "knights"
    hero.mkdir(parents=True)
    _manifest(hero)
    _frame(hero, "knights_idle_01.png", box=(20, 40, 44, 56))
    res = ah.audit(sprites)
    assert any("рост силуэта вне допуска" in p for p in res["files"][0]["problems"])


def test_хромакей_в_углу_красно(tmp_path):
    sprites = tmp_path / "game/assets/sprites"
    hero = sprites / "knights"
    hero.mkdir(parents=True)
    _manifest(hero)
    _frame(hero, "knights_idle_01.png", fills=[(0, 0)])
    res = ah.audit(sprites)
    assert any("хромакей в углу" in p for p in res["files"][0]["problems"])


def test_пустой_кадр_красно(tmp_path):
    sprites = tmp_path / "game/assets/sprites"
    hero = sprites / "knights"
    hero.mkdir(parents=True)
    _manifest(hero)
    Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0)).save(hero / "knights_idle_01.png")
    res = ah.audit(sprites)
    assert any("пустой кадр" in p for p in res["files"][0]["problems"])


def test_без_манифеста_красно_по_происхождению(tmp_path):
    """Кадр без записи сборки не с чем связать: геометрия становится проверима
    только по дефолтам, а происхождение — потеряно."""
    sprites = tmp_path / "game/assets/sprites"
    hero = sprites / "knights"
    hero.mkdir(parents=True)
    _frame(hero, "knights_idle_01.png")
    res = ah.audit(sprites)
    assert any(p.startswith("происхождение") for p in res["files"][0]["problems"])


def test_манифест_без_геометрии_берёт_дефолты():
    """Манифесты ранних сборок (`backfilled`) не несут canvas/feet_y/figure_h —
    аудитор обязан взять числа HERO-ANIM.md, а не упасть и не взять нули."""
    assert ah.geometry({}) == (ah.CANVAS_DEFAULT, ah.FEET_Y_DEFAULT, ah.FIGURE_H_DEFAULT)
    assert ah.geometry({"canvas": 256, "feet_y": 224, "figure_h": 192}) == (256, 224, 192)


def test_посторонние_файлы_не_считаются(tmp_path):
    """Контактный лист и чужой каталог не кадры дорожки: аудит меряет только
    `<hero>_<action>_<NN>.png` своего героя."""
    sprites = tmp_path / "game/assets/sprites"
    hero = sprites / "knights"
    hero.mkdir(parents=True)
    _manifest(hero)
    _frame(hero, "knights_idle_01.png")
    _frame(hero, "contact_sheet.png")
    _frame(hero, "archers_idle_01.png")
    other = sprites / "00_notes"
    other.mkdir()
    _frame(other, "stray_idle_01.png")
    res = ah.audit(sprites)
    assert res["checked"] == 1, [r["file"] for r in res["files"]]


def test_отчёт_пишется_и_код_возврата(tmp_path):
    sprites = _kit(tmp_path)
    report = tmp_path / "a.json"
    assert ah.main([str(sprites), "--quiet", "--report", str(report)]) == 0
    data = json.loads(report.read_text(encoding="utf-8"))
    assert data["checked"] == 2 and data["rejected"] == 0
    _frame(sprites / "knights", "knights_hit_01.png", mode="RGB")
    assert ah.main([str(sprites), "--quiet"]) == 1

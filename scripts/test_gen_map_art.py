"""Сборка листа карты (`gen_map_art.py --assemble`): то, что молча ломает кадр, а не
то, что ломает pytest. Ассемблер — чистая функция над кэшем прогона, поэтому тесты
читают уже собранные артефакты (`game/assets/…`), а не зовут модель.

Запускается из корня репо: `python3 -m pytest scripts/test_gen_map_art.py -q`."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import numpy as np
import pytest
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_map_art as art  # noqa: E402


@pytest.fixture(scope="module")
def objects() -> dict:
    return json.loads(art.OBJ_JSON.read_text(encoding="utf-8"))


def test_object_sheet_has_a_row_per_manifest_cell(objects: dict) -> None:
    """Каждая клетка манифеста обязана влезать в лист: тайлсет вырезает по `atlas`,
    и клетка за краем текстуры — это молча пустой слой (ровно тот дефект, что
    прятался под «palm»/«cactus»)."""
    cols, rows = objects["grid"]
    with Image.open(art.OBJ_IMG) as sheet:
        assert sheet.size == (cols * art.TILE, rows * art.TILE)
        for cell in objects["cells"]:
            x, y = cell["atlas"]
            assert 0 <= x < cols and 0 <= y < rows, cell["id"]


def test_object_sheet_cells_are_not_empty(objects: dict) -> None:
    """Пустая клетка листа — это не «объект не виден», это «слоя нет»: спавнер
    ставит id, тайл есть, пикселей ноль. Порог низкий намеренно: силуэты
    полупрозрачные по краям."""
    with Image.open(art.OBJ_IMG) as sheet:
        pixels = np.asarray(sheet.convert("RGBA"))
    for cell in objects["cells"]:
        x, y = cell["atlas"]
        cell_px = pixels[y * art.TILE:(y + 1) * art.TILE, x * art.TILE:(x + 1) * art.TILE]
        assert (cell_px[..., 3] > 32).mean() > 0.02, f"пустая клетка листа: {cell['id']}"


def test_fog_twin_is_the_sheet_dimmed_by_the_engine_factor(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """Туман войны кладёт тот же объект вторым источником (`MapObjects.FOG_SOURCE_ID`),
    и кратность обязана совпасть с базой — иначе «затемнённая база при ярком
    дереве» возвращается с другой стороны. Альфа обязана остаться: тень — альфа,
    а не цвет."""
    out = tmp_path / "fog.webp"
    monkeypatch.setattr(art, "OBJ_FOG_IMG", out)
    art.fog_twin()
    with Image.open(art.OBJ_IMG) as base_img, Image.open(out) as fog_img:
        base = np.asarray(base_img.convert("RGBA")).astype(np.float64)
        fog = np.asarray(fog_img.convert("RGBA")).astype(np.float64)
    assert fog.shape == base.shape
    opaque = base[..., 3] > 200
    assert fog[..., 3][opaque].mean() == pytest.approx(base[..., 3][opaque].mean(), abs=2)
    assert fog[..., :3][opaque].mean() == pytest.approx(
        base[..., :3][opaque].mean() * art.MAP_FOG_DIM, rel=0.02)


def test_fog_dim_mirrors_the_engine_constant() -> None:
    """`MAP_FOG_DIM` здесь — зеркало `GameNumbersMap.MAP_FOG_DIM`. Разъедутся —
    туман на объектах станет темнее тумана на базе."""
    gd = (art.ROOT / "game/scripts/constants/game_numbers_map.gd").read_text(encoding="utf-8")
    engine = re.search(r"const MAP_FOG_DIM := ([0-9.]+)", gd)
    assert engine is not None, "в game_numbers_map.gd нет MAP_FOG_DIM"
    assert float(engine.group(1)) == pytest.approx(art.MAP_FOG_DIM)


def test_mountain_decor_density_stays_under_the_gate() -> None:
    """Плотность объектов на мерзлоте ограничена не вкусом: при 0.55 дорога
    тонула в камне (ΔE «асфальт↔валун» 11.4 при пороге 12 — кадр relief-t71).
    Константа лежит в `map_spawner.gd`, тест держит её под запертым значением."""
    gd = (art.ROOT / "game/scripts/world/map_spawner.gd").read_text(encoding="utf-8")
    chance = float(re.search(r"const DECOR_MOUNTAIN_CHANCE := ([0-9.]+)", gd).group(1))
    assert 0.0 < chance <= 0.35

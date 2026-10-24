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


def test_fog_twin_is_the_sheet_dimmed_by_the_engine_factor(tmp_path: Path) -> None:
    """Туман войны кладёт тот же объект вторым источником (`MapObjects.FOG_SOURCE_ID`),
    и кратность обязана совпасть с базой — иначе «затемнённая база при ярком
    дереве» возвращается с другой стороны. Альфа обязана остаться: тень — альфа,
    а не цвет.

    Куда писать — **аргумент**, не `monkeypatch` по `OBJ_FOG_IMG`: дефолт
    `dst=OBJ_FOG_IMG` связывается в момент `import`, и подмена глобалии тесту не
    подчинялась — тест писал в отслеживаемый ассет и читал несуществующий
    tmp-путь (T-161).
    """
    out = tmp_path / "fog.webp"
    art.fog_twin(dst=out)
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




# ---------------------------------------------------------------------------
# --recolor (T-163): перекраска уже принятого листа без новой генерации.
# ---------------------------------------------------------------------------

def _manifest() -> dict:
    return json.loads(art.ATLAS_JSON.read_text(encoding="utf-8"))


def _cell(img: Path, atlas_cell: list[int]) -> np.ndarray:
    """Клетка листа как RGBA float: альфа нужна, потому что декаль границы
    непрозрачен лишь на узкой полосе, а у базы прозрачны угловые треугольники."""
    with Image.open(img) as sheet:
        px = np.asarray(sheet.convert("RGBA")).astype(np.float64)
    x, y = int(atlas_cell[0]) * art.TILE, int(atlas_cell[1]) * art.TILE
    return px[y:y + art.TILE, x:x + art.TILE]


def _opaque(cell: np.ndarray) -> np.ndarray:
    """Содержимое клетки — только непрозрачные пиксели. Под альфой 0 цвет не
    содержание: webp-кодировщик имеет право менять его как хочет, и мера по
    шестиугольнику ловила эти невидимые пиксели (на декале границы — 85 % выборки)."""
    return cell[..., 3] > 200


def _lab_mean(cell: np.ndarray) -> np.ndarray:
    lab = art.PB.rgb_to_lab(cell[..., :3] / 255.0)
    return lab[_opaque(cell)].reshape(-1, 3).mean(0)


def _near_blue_share(cell: np.ndarray) -> float:
    """Доля пикселей у ледяного тона полосы — та же мера, что печатает `recolor`
    (`de76` до `#95cde5` < 12), а не своя линейка: иначе тест и печать вердикта
    меряли бы разное."""
    blue = art.PB.tone_lab(art.PB.parse_hex("#95cde5"))
    lab = art.PB.rgb_to_lab(cell[..., :3] / 255.0)
    hits = art.PB.de76(lab, blue) < 12
    op = _opaque(cell)
    return float(hits[op].mean())


def _base_cell(biome: str, man: dict | None = None) -> list[int]:
    """Адрес базовой клетки биома (вариант 0) — из манифеста, не из головы: порядок
    клеток в листе менялся вместе с составом биомов."""
    for c in (man or _manifest())["cells"]:
        if c.get("biome") == biome and c.get("kind") == "base" and c.get("variant") == 0:
            return c["atlas"]
    raise AssertionError(f"в манифесте нет базовой клетки биома {biome}")


def _identity() -> dict[str, list[str]]:
    return {b: art.ramp_of(b) for b in sorted({c["biome"] for c in _manifest()["cells"]})}


@pytest.fixture(scope="module")
def recolored_identity(tmp_path_factory) -> tuple[Path, dict]:
    """Перекраска «в себя»: каждый биом возвращается на свою же рампу. Это не
    noop-тест — так видно, что механизм сохраняет порядок тонов, фактуру и средние
    тона вариантов (на последнем держится гейт `atlas/variant-tone`)."""
    out = tmp_path_factory.mktemp("recolor") / "identity.webp"
    assert art.recolor(_identity(), out) == 0
    return out, _manifest()


def test_recolor_identity_preserves_layout_and_mean(recolored_identity: tuple[Path, dict]) -> None:
    """Клетка — адрес: тайлсет вырезает по `atlas`, поэтому перекраска не имеет
    права менять сетку, порядок и идентификаторы клеток; а перекраска «в себя» не
    имеет права уводить цвет, иначе кандидат — это уже новая генерация."""
    sheet, man = recolored_identity
    shipped = _manifest()
    assert sheet.exists() and sheet.with_suffix(".json").exists()
    new = json.loads(sheet.with_suffix(".json").read_text(encoding="utf-8"))
    assert new["grid"] == shipped["grid"]
    assert [c["id"] for c in new["cells"]] == [c["id"] for c in shipped["cells"]]
    assert [c["atlas"] for c in new["cells"]] == [c["atlas"] for c in shipped["cells"]]
    assert new["image"] == sheet.name, "манифест кандидата смотрит на носитель"
    with Image.open(art.ATLAS_IMG) as base_img, Image.open(sheet) as new_img:
        assert base_img.size == new_img.size
    for c in shipped["cells"]:
        de = float(np.abs(_lab_mean(_cell(art.ATLAS_IMG, c["atlas"]))
                          - _lab_mean(_cell(sheet, c["atlas"]))).max())
        assert de <= 2.0, f"{c['id']}: перекраска «в себя» ушла по цвету на ΔE {de:.1f}"


def test_recolor_keeps_cell_texture(recolored_identity: tuple[Path, dict]) -> None:
    """Наивная перекраска = плоская заливка тоном: лист становится пластиковым,
    `atlas/contrast` и глаз владельца гибнут одновременно. `recolor_cell` хранит
    отклонение пикселя от тона, значит разброс яркости обязан уцелеть; порог
    относительный (60 % исходного), потому что у светлых биомов он и в носителях
    низкий — снег даёт σ≈3 против σ≈40 у болота."""
    sheet, man = recolored_identity
    lum = lambda c: (c[..., :3] @ np.array([0.2126, 0.7152, 0.0722]))  # noqa: E731
    for c in man["cells"]:
        if c["kind"] != "base":
            continue
        was, now = lum(_cell(art.ATLAS_IMG, c["atlas"])), lum(_cell(sheet, c["atlas"]))
        s0 = float(was[_opaque(_cell(art.ATLAS_IMG, c["atlas"]))].std())
        s1 = float(now[_opaque(_cell(sheet, c["atlas"]))].std())
        assert s1 >= 0.6 * s0, f"{c['id']}: фактура просела {s0:.1f} → {s1:.1f}"


def test_recolor_keeps_variant_mean_on_base_tone(recolored_identity: tuple[Path, dict]) -> None:
    """Четыре варианта биома TileSet подмешивает к базе как variety-шум: уедет
    средний тон варианта — кадр начнёт мерцать пятнами. За это отвечает гейт
    `atlas/variant-tone` (ΔE ≤ 8), и `recolor` обязан выравнивать варианты заново
    после смены тонов, а не перекрашивать их в новую рампу."""
    sheet, man = recolored_identity
    for biome in sorted({c["biome"] for c in man["cells"]}):
        cells = [c for c in man["cells"] if c["biome"] == biome and c["kind"] == "base"]
        assert len(cells) >= 2, f"{biome}: вариантов меньше двух"
        base = _lab_mean(_cell(sheet, cells[0]["atlas"]))
        for c in cells[1:]:
            de = float(np.abs(base - _lab_mean(_cell(sheet, c["atlas"]))).max())
            assert de <= 8.0, f"{c['id']}: тон варианта уехал на ΔE {de:.1f}"


def test_recolor_moves_rock_off_the_ice_blue_ramp(tmp_path: Path) -> None:
    """Корень T-163: тон берётся по рангу яркости пикселя, а самый светлый тон
    полосы M — ледяной `#95cde5`; у скалы он стоит третьим, светлым тоном, поэтому
    светлые пиксели камня красятся в него (на карте — «скала = замёрзшее озеро»).
    Перекраска на рампу без ледяного тона обязана убрать долю у `#95cde5` в ноль
    и реально изменить клетку."""
    out = tmp_path / "rock.webp"
    assert art.recolor({"rock": art.ramp_of("grass")}, out) == 0
    was, now = _cell(art.ATLAS_IMG, _base_cell("rock")), _cell(out, _base_cell("rock"))
    assert _near_blue_share(was) > 0.20, "мера перестала ловить дефект — тест стал пустым"
    got = _near_blue_share(now)
    assert got == 0.0, f"около-голубого осталось {100.0 * got:.1f}%"
    de = float(np.abs(_lab_mean(was) - _lab_mean(now)).max())
    assert de > 8.0, f"перекраска не изменила клетку (ΔE {de:.1f})"


def test_recolor_refuses_to_overwrite_the_shipped_sheet(tmp_path: Path, monkeypatch) -> None:
    """Лист в репо — принятый владельцем арт. Режим обязан отказать, если кандидата
    просят положить на то же место: одна опечатка в `--recolor-out` иначе заменяет
    канон кандидатом без вердикта владельца."""
    before = art.ATLAS_IMG.read_bytes()
    monkeypatch.setattr(sys, "argv", ["gen_map_art.py", "--recolor", '{"rock": ["#354845"]}',
                                      "--recolor-out", str(art.ATLAS_IMG)])
    with pytest.raises(SystemExit) as exit_info:
        art.main()
    assert exit_info.value.code != 0
    assert art.ATLAS_IMG.read_bytes() == before, "принятый лист перезаписан"


def test_recolor_requires_an_output_path(monkeypatch) -> None:
    """Без адреса кандидата перекраска не имеет права ни писать в носитель, ни
    молча уйти в обычную генерацию — `main()` обязан упасть, а не рисовать сырьё."""
    monkeypatch.setattr(sys, "argv", ["gen_map_art.py", "--recolor", '{"rock": ["#354845"]}'])
    with pytest.raises(SystemExit) as exit_info:
        art.main()
    assert exit_info.value.code != 0

"""Тесты сверщика карты hero-экрана (`check_hero_layout_map.py`).

Сверщик заведён именно тестами: у обещанной проверки четыре отношения, и у
каждого — своё «зелёное» состояние, в котором она молчит. Без тестов она
превратилась бы в ещё одну строку вывода, которая ничего не обязана замечать
(ровно так в своё время умерла ratchet-проверка в `audit_docs_vs_code`).

Запуск: `python3 -m pytest scripts/test_check_hero_layout_map.py -q`
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_hero_layout_map as check_map  # noqa: E402

LAYOUT = """const BLOCKS := {
\t"Left": Rect2(14, 8, 488, 885),           # A1–D10, пергамент
\t"Portrait": Rect2(13, 6, 463, 333),       # A1–D4, рама
\t"Stats": Rect2(12, 474, 476, 94),         # A6–D7, характеристики
\t"ItemTip": Rect2(571, 300, 460, 240),
}
"""
# У Stats узла нет намеренно: он координатный (политика — параметром check()).
SCENE = (
    '[node name="ArtifactInventoryScreen" type="Control"]\n'
    '[node name="Left" type="Control" parent="."]\n'
    '[node name="Portrait" type="TextureRect" parent="."]\n'
    '[node name="ItemTip" type="Panel" parent="."]\n'
)
DOC = """## 2. Замер макета

| Блок | Пиксели | Адрес |
| --- | --- | --- |
| Левая колонка | 24,14,884,1572 | A1–D10 |
| Портрет | 48,26,862,612 | A1–D4 |
| Характеристики | 60,848,862,1014 | A6–D7 |
| Габарит куклы | 1275,67,2018,874 | E1–H6 |

## 5. Зоны переноса

| Зона | Адрес / геометрия |
| --- | --- |
"""
CONSUMER = (
    'var a := _L.BLOCKS["Left"]\n'
    'var b := _L.anchor_rect("Portrait", "Left")\n'
    'var c := _L.BLOCKS["Stats"]\n'
    'var d := _L.BLOCKS["ItemTip"]\n'
)
COORD = {"Stats": "генератор раскладывает строки напрямую по rect'у"}
NO_MOCKUP = {"ItemTip": "всплывающая панель, макет её не занимает"}
DOC_ONLY = {"E1–H6": "габарит куклы — DOLL[], а не блок"}


def _check(**over):
    args = {
        "layout_text": LAYOUT,
        "scene_text": SCENE,
        "doc_text": DOC,
        "consumers": [CONSUMER],
        "coordinate_keys": COORD,
        "no_mockup_address": NO_MOCKUP,
        "doc_only_addresses": DOC_ONLY,
    }
    args.update(over)
    return check_map.check(**args)


def _red(res: dict) -> list[str]:
    return [k for k, v in res.items() if isinstance(v, list) and v]


def test_consistent_world_is_green():
    res = _check()
    assert not _red(res), res
    assert res["blocks"] == 4 and res["doc_rows"] == 4, res


def test_key_without_node_is_red_unless_declared_coordinate():
    """Ровно координатные ключи не имеют узла; для остальных — краснота (T-277)."""
    assert _check()["orphan_nodes"] == [], "Stats координатный — не долг"
    res = _check(scene_text=SCENE.replace('name="Portrait"', 'name="Portrit"'))
    assert res["orphan_nodes"] == ["Portrait"], res


def test_key_nobody_reads_is_a_dead_rect():
    res = _check(consumers=['var a := _L.BLOCKS["Left"]\nvar c := _L.BLOCKS["Stats"]\n'
                            'var d := _L.BLOCKS["ItemTip"]\n'])
    assert res["dead_keys"] == ["Portrait"], res


def test_code_naming_an_absent_key_is_red():
    res = _check(consumers=[CONSUMER + 'var e := _L.BLOCKS["Figure"]\n'])
    assert res["ghost_keys"] == ["Figure"], res


def test_coordinate_stub_that_lost_its_key_is_reported():
    """Поправка на «координатный» ключ не имеет права пережить сам ключ."""
    assert _check(coordinate_keys={**COORD, "Ghost": "ни keys, ни rect'а"})["unmapped_coordinate_keys"] == ["Ghost"]


def test_block_address_outside_the_map_is_red():
    res = _check(layout_text=LAYOUT.replace("# A1–D4, рама", "# K7–L9, рама"))
    assert [k for k, _ in res["block_address_without_doc_row"]] == ["Portrait"], res


def test_map_row_that_moved_is_red():
    """Обратное направление строгое: «внутри левой колонки» — не покрытие."""
    res = _check(doc_text=DOC.replace("| Портрет | 48,26,862,612 | A1–D4 |",
                                      "| Портрет | 48,26,862,612 | B2–B3 |"))
    assert [row for row, _ in res["doc_rows_without_block"]] == ["B2–B3"], res


def test_block_without_address_must_be_declared_as_outside_the_mockup():
    res = _check(layout_text=LAYOUT.replace("# A1–D4, рама", "# рама без адреса"))
    assert res["blocks_without_address"] == ["Portrait"], res
    assert "ItemTip" not in res["blocks_without_address"], "заявленное исключение — не долг"


def test_exemption_that_became_wrong_is_stale():
    """Исключение, которое больше ничего не исключает, обязано уехать из файла."""
    res = _check(layout_text=LAYOUT.replace(
        '"ItemTip": Rect2(571, 300, 460, 240),', '"ItemTip": Rect2(571, 300, 460, 240), # A1–D10, панель'))
    assert "ItemTip" in res["stale_exemptions"], res
    res2 = _check(doc_text=DOC.replace("| Габарит куклы | 1275,67,2018,874 | E1–H6 |", ""))
    assert "E1–H6" in res2["stale_exemptions"], res2


def test_real_repository_files_agree():
    """Живые файлы репо сверщик считает согласованными — иначе красен гейт."""
    res = check_map.check(
        check_map.LAYOUT.read_text(encoding="utf-8"),
        check_map.SCENE.read_text(encoding="utf-8"),
        check_map.DOC.read_text(encoding="utf-8"),
        [p.read_text(encoding="utf-8") for p in check_map.CONSUMERS],
    )
    assert not _red(res), res

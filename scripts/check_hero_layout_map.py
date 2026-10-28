#!/usr/bin/env python3
"""Сверка таблицы `HeroLayout.BLOCKS` со сценой, кодом и адресной картой §2.

Зачем (T-277): `docs/20-ux-hero-screen.md` §8 обещал тест, сверяющий таблицу
геометрии с адресами карты, и в репо его не было — расхождение карты §2, таблицы
`hero_layout.gd` и генератора `gen_inventory_scene.gd` измерялось только
ux-review. GdUnit-тест сверку вести не может: `res://` не читает `docs/`, а
сравнивать надо именно документ с кодом, поэтому носитель — сверщик здесь, по
образцу `audit_docs_vs_code` (строка в `doc_gates.sh`).

Проверяются четыре отношения:

1. **таблица → сцена.** у каждого ключа `BLOCKS` есть узел с тем же именем в
   `scenes/ui/artifact_inventory_screen.tscn`, кроме координатных ключей
   (`COORDINATE_KEYS` — генератор раскладывает их содержимое напрямую, узла с
   таким именем в сцене нет и быть не должно);
2. **таблица → код.** каждый ключ кто-то читает (генератор сцены или скрипт
   экрана): мёртвый rect — это обещанная геометрия, которую никто не рисует;
3. **код → таблица.** каждый ключ, названный в потребителе, есть в таблице:
   иначе `BLOCKS["…"]` падает на генерации;
4. **таблица ↔ карта §2/§5.** адрес из комментария блока лежит внутри адреса
   строки документа, и наоборот — адрес документа накрывается хотя бы одним
   блоком. Расхождение измеряется, а не чинится молча: исключение возможно
   только записью с причиной.

Запуск: `python3 scripts/check_hero_layout_map.py` (0 — расхождений нет).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAYOUT = ROOT / "game/scripts/ui/hero_layout.gd"
SCENE = ROOT / "game/scenes/ui/artifact_inventory_screen.tscn"
DOC = ROOT / "docs/20-ux-hero-screen.md"
CONSUMERS = (
    ROOT / "game/scripts/build/gen_inventory_scene.gd",
    ROOT / "game/scripts/ui/artifact_inventory_screen.gd",
)

#: Ключи без узла-тёзки: геометрия нужна, контейнера — нет.
COORDINATE_KEYS = {
    "Stats": "генератор раскладывает 4 пары «иконка/имя/значение» напрямую по rect'у",
    "EquipList": "генератор раскладывает 7 строк EquipRow_* напрямую по rect'у",
    "CardScroll": "лента карточек юнитов собирается скриптом экрана в ScrollContainer",
}

#: Блоки, у которых нет адреса макета (не исключение «забыли», а факт макета).
NO_MOCKUP_ADDRESS = {
    "ItemTip": "всплывающая панель предмета, макет её не занимает (§5, зона D)",
}

#: Адреса документа, которым не обязан соответствовать ни один блок.
DOC_ONLY_ADDRESSES = {
    "E1–H6": "габарит куклы — это DOLL[], а не блок BLOCKS",
    "D1–E6": "зона переноса A (§5): блок BandMana лежит внутри неё, своей строки макета нет",
    "H1–I6": "зона переноса C (§5): блок BandSkills лежит внутри неё, своей строки макета нет",
}

CELL = re.compile(r"\b([A-Z])(\d+)(?:–([A-Z])(\d+))?\b")


def _block_rows(text: str) -> dict[str, str]:
    """Ключи `BLOCKS` и комментарии-адреса к ним (одна строка на блок)."""
    body = text[text.index("const BLOCKS := {") :]
    body = body[: body.index("\n}")]
    rows = {}
    for m in re.finditer(r'^\t"([A-Za-z0-9_]+)": Rect2\([^)]*\),?\s*(?:#\s*(.*))?$', body, re.M):
        rows[m.group(1)] = (m.group(2) or "").strip()
    return rows


def _ranges(comment: str) -> list[tuple[int, int, int, int]]:
    """Адреса вида `A1–D10` / `J1` из комментария или строки таблицы."""
    out = []
    for m in CELL.finditer(comment):
        c1, r1 = ord(m.group(1)) - 65, int(m.group(2))
        c2 = ord(m.group(3)) - 65 if m.group(3) else c1
        r2 = int(m.group(4)) if m.group(4) else r1
        out.append((min(c1, c2), min(r1, r2), max(c1, c2), max(r1, r2)))
    return out


def _doc_rows(text: str, sections: tuple[str, ...]) -> list[str]:
    """Ячейка «Адрес» из таблиц указанного раздела (строки `| … | A1–D10 |`)."""
    rows = []
    for section in sections:
        start = text.index(section)
        tail = text[start + len(section) :]
        end = tail.find("\n## ")
        body = tail if end < 0 else tail[:end]
        for line in body.splitlines():
            if not line.startswith("|") or line.startswith("| ---"):
                continue
            for cell in (c.strip() for c in line.strip("|").split("|")):
                # Адресная ячейка: только адрес, либо адрес с пояснением в скобках.
                if re.fullmatch(r"[A-J]\d+(–[A-J]\d+)?", cell.replace(" ", "")):
                    rows.append(cell)
    return rows


def _inside(inner, outer) -> bool:
    return outer[0] <= inner[0] and outer[1] <= inner[1] and outer[2] >= inner[2] and outer[3] >= inner[3]


def check(
    layout_text: str,
    scene_text: str,
    doc_text: str,
    consumers: list[str],
    coordinate_keys: dict[str, str] | None = None,
    no_mockup_address: dict[str, str] | None = None,
    doc_only_addresses: dict[str, str] | None = None,
) -> dict:
    """Сверка четырёх отношений. Исключения — параметром: политика репозитория
    живёт в константах ниже, а тесты обязаны уметь собрать свой мир."""
    coordinate_keys = COORDINATE_KEYS if coordinate_keys is None else coordinate_keys
    no_mockup_address = NO_MOCKUP_ADDRESS if no_mockup_address is None else no_mockup_address
    doc_only_addresses = DOC_ONLY_ADDRESSES if doc_only_addresses is None else doc_only_addresses
    blocks = _block_rows(layout_text)
    nodes = set(re.findall(r'^\[node name="([^"]+)"', scene_text, re.M))
    code = "\n".join(consumers)

    orphan_nodes = [k for k in blocks if k not in nodes and k not in coordinate_keys]
    dead_keys = [k for k in blocks if f'"{k}"' not in code]
    ghost_keys = sorted(
        {k for k in re.findall(r'BLOCKS\["([^"]+)"\]', code) if k not in blocks}
    )
    unmapped_coord = sorted(k for k in coordinate_keys if k not in blocks)

    doc_rows = _doc_rows(doc_text, ("## 2.", "## 5."))
    doc_ranges = [(r, row) for row in doc_rows for r in _ranges(row)]

    block_addr: dict[str, list] = {}
    for key, comment in blocks.items():
        block_addr[key] = _ranges(comment)

    no_address = sorted(k for k, r in block_addr.items() if not r and k not in no_mockup_address)
    outside = []
    for key, ranges in block_addr.items():
        for r in ranges:
            if not any(_inside(r, outer) for outer, _ in doc_ranges):
                outside.append((key, r))
    # Обратное направление строгое: адрес строки карты обязан совпадать с адресом
    # блока. Накрывание («строка лежит внутри левой колонки») ничего не ловит —
    # любая уехавшая строка остаётся где-то внутри A1–D10.
    block_ranges = {br for ranges in block_addr.values() for br in ranges}
    uncovered = [(row, r) for r, row in doc_ranges if r not in block_ranges and row not in doc_only_addresses]
    stale_exempt = sorted(k for k in no_mockup_address if block_addr.get(k))
    stale_exempt += sorted(k for k in doc_only_addresses if k not in doc_rows)

    return {
        "blocks": len(blocks),
        "doc_rows": len(doc_rows),
        "orphan_nodes": orphan_nodes,
        "dead_keys": dead_keys,
        "ghost_keys": ghost_keys,
        "unmapped_coordinate_keys": unmapped_coord,
        "block_address_without_doc_row": outside,
        "doc_rows_without_block": uncovered,
        "blocks_without_address": no_address,
        "stale_exemptions": stale_exempt,
    }


def main() -> int:
    res = check(
        LAYOUT.read_text(encoding="utf-8"),
        SCENE.read_text(encoding="utf-8"),
        DOC.read_text(encoding="utf-8"),
        [p.read_text(encoding="utf-8") for p in CONSUMERS],
    )
    print(f"HERO-LAYOUT-MAP: блоков {res['blocks']}, адресных строк карты {res['doc_rows']}")
    bad = False
    labels = {
        "orphan_nodes": "ключ BLOCKS без узла в сцене и без поправки на координатный",
        "dead_keys": "ключ BLOCKS не читается ни генератором, ни экраном",
        "ghost_keys": "код зовёт BLOCKS[\"…\"], которого нет в таблице",
        "unmapped_coordinate_keys": "координатная поправка ссылается на несуществующий ключ",
        "block_address_without_doc_row": "адрес блока не накрывается ни одной строкой карты",
        "doc_rows_without_block": "адрес строки карты не совпадает ни с одним блоком",
        "blocks_without_address": "у блока нет адреса и он не заявлен как «макета нет»",
        "stale_exemptions": "исключение больше не нужно — убери его",
    }
    for key, label in labels.items():
        rows = res[key]
        if rows:
            bad = True
            print(f"  {label} ({len(rows)}):")
            for r in rows:
                print(f"    {r}")
    if not bad:
        print("  расхождений нет")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())

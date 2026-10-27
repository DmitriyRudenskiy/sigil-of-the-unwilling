#!/usr/bin/env python3
"""Аудит письменных описаний: лист + 12 сюжетов -> правки по ячейкам.

Судья — та же `pi -p --no-tools`, что шлюз intake и STY-судья прогона.
Сырые ответы — docs/corrections-raw/unit-0X.md, парсики — stdout.
Ничего не применяет: применить правки — отдельный шаг (queue.json/spec.json).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from concept_art import sweep as s
from concept_art import jobloop as j

BRIEF = """Перед тобой лист из 12 клеток персонажей (строки сверху вниз, слева направо:
ячейка 1 — верхний левый угол). Ниже 12 письменных описаний тех же персонажей,
по одному на ячейку, в порядке ячеек. Это prompt для генерации: он обязан
воспроизвести персонажа, а не просто нарисовать похожего.
Сверь каждое описание с картинкой: поза, телосложение, одежда, цвета, предметы
и их положение, лицо, волосы. Пропущенный крупный предмет или неверный цвет —
это ошибка; тонкая стилизация — не ошибка.
Ответь ровно 12 строками вида:
IMG-NNN: OK
или
IMG-NNN: <коротко: что в описании неверно и как должно быть, по-английски>"""


def main() -> int:
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--cat", nargs="*", help="только эти категории (unit-01..05)")
    a = ap.parse_args()
    q = j.load()
    spec = __import__("json").loads(j.SPEC.read_text())
    raw = j.DOCS / "corrections-raw"
    raw.mkdir(exist_ok=True)
    cats = a.cat or [f"unit-{n:02d}" for n in range(1, 6)]
    for cat in cats:
        items = sorted(spec["categories"][cat]["items"],
                       key=lambda i: q[i["id"]]["cell"])
        subjects = "\n".join(f"ячейка {q[i['id']]['cell']}: {q[i['id']]['subject']}"
                             for i in items)
        sheet = j.LAB / "references" / f"{cat}.jpeg"
        # Судья читает 1024: лист 2048 таймаутится на входе (проверено).
        small = Path("/tmp") / f"audit-{cat}.png"
        from PIL import Image
        Image.open(sheet).convert("RGB").resize((1024, 1024)).save(small)
        out = s.ask([small], BRIEF + "\n\n" + subjects)
        (raw / f"{cat}.md").write_text(f"лист: {sheet}\n\n{out}\n")
        print(f"--- {cat} (сырые: {raw / (cat + '.md')}) ---")
        for line in out.splitlines():
            line = line.strip()
            if line.startswith("IMG-"):
                print(line[:200])
    return 0


if __name__ == "__main__":
    sys.exit(main())

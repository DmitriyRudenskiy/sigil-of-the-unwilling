#!/usr/bin/env python3
"""Чекер происхождения ассетов (ASSET-1, [[13-art-bible]] §12).

Падает, если:
  1. у ассета нет строки в game/assets/PROVENANCE.md (ни файловой, ни классовой);
  2. строка реестра ведёт в никуда (файла/каталога нет);
  3. у файла статус «красный» — чужой пиксель лежать в репо не может.

Ассеты = изображения, аудио, шрифты. Данные (.json), .tres и .gd — авторский код
репо, не проверяются. Запуск: python3 scripts/check_asset_provenance.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "game", "assets")
REGISTRY = os.path.join(ASSETS, "PROVENANCE.md")
MEDIA_EXT = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".svg",
             ".ttf", ".otf", ".mp3", ".ogg", ".wav"}
ROW = re.compile(r"^\|\s*`?([^|`]+?)`?\s*\|")


def parse_registry():
    """-> ({путь ассета: статус}, {каталог: статус}) из таблиц реестра."""
    files, classes = {}, {}
    with open(REGISTRY, encoding="utf-8") as fh:
        for line in fh:
            m = ROW.match(line)
            if not m:
                continue
            path = m.group(1).strip()
            if not path.startswith("game/assets/"):
                continue
            cells = [c.strip().strip("`") for c in line.strip().strip("|").split("|")]
            status = cells[-1].split(" ")[0] if len(cells) >= 5 else ""
            if path.endswith("/"):
                classes[path] = status
            else:
                files[path] = status
    return files, classes


def walk_assets():
    for dirpath, _dirs, names in os.walk(ASSETS):
        for name in sorted(names):
            if os.path.splitext(name)[1].lower() in MEDIA_EXT:
                yield os.path.relpath(os.path.join(dirpath, name), ROOT).replace(os.sep, "/")


def main():
    files, classes = parse_registry()
    # Каталог с файловыми строками — «поимённый»: классовая строка внутри него не
    # работает, иначе новый файл в таком каталоге прошёл бы молча.
    named = {p[:p.rfind("/") + 1] for p in files}
    problems = []
    covered = 0
    total = 0
    for rel in walk_assets():
        total += 1
        dir_ = rel[:rel.rfind("/") + 1]
        status = files.get(rel) or ("" if dir_ in named else classes.get(dir_, ""))
        if not status:
            problems.append("нет строки провенанса: %s" % rel)
            continue
        covered += 1
        if status == "красный":
            problems.append("статус «красный» (чужой пиксель в репо): %s" % rel)
    for path in sorted(files):
        if not os.path.exists(os.path.join(ROOT, path)):
            problems.append("строка реестра без файла: %s" % path)
    for path in sorted(classes):
        if not os.path.isdir(os.path.join(ROOT, path)):
            problems.append("строка реестра без каталога: %s" % path)

    if problems:
        print("ПРОВЕНАНС: %d проблем" % len(problems))
        for p in problems:
            print("  - %s" % p)
        print("  (правь game/assets/PROVENANCE.md — строка на каждый новый ассет)")
        return 1
    print("ПРОВЕНАНС: %d/%d ассетов покрыто (%d классов, %d файлов)"
          % (covered, total, len(classes), len(files)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Чекер происхождения ассетов (ASSET-1, [[13-art-bible]] §12).

Падает, если:
  1. у ассета нет строки в game/assets/PROVENANCE.md (ни файловой, ни классовой);
  2. строка реестра ведёт в никуда (файла/каталога нет);
  3. у файла статус «красный» — чужой пиксель лежать в репо не может.

Ассеты = изображения, аудио, шрифты. Данные (.json), .tres и .gd — авторский код
репо, не проверяются. Чекер НЕ проверяет: очищены ли права (статусы «неизвестно» и
«жёлтый» проходят), и не трогает §«Снятые позиции» — там записи об удалённых файлах,
существование которых проверять нечего. Вывод печатает свой охват (D-206).
Запуск: python3 scripts/check_asset_provenance.py
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
    """-> ({путь ассета: статус}, {каталог: статус}, сколько снятых позиций)."""
    files, classes = {}, {}
    withdrawn = 0
    in_withdrawn = False
    with open(REGISTRY, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("## "):
                in_withdrawn = "Снятые позиции" in line
                continue
            if in_withdrawn and line.lstrip().startswith("-"):
                withdrawn += 1
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
    return files, classes, withdrawn


def walk_assets():
    for dirpath, _dirs, names in os.walk(ASSETS):
        for name in sorted(names):
            if os.path.splitext(name)[1].lower() in MEDIA_EXT:
                yield os.path.relpath(os.path.join(dirpath, name), ROOT).replace(os.sep, "/")


def main():
    files, classes, withdrawn = parse_registry()
    # Каталог с файловыми строками — «поимённый»: классовая строка внутри него не
    # работает, иначе новый файл в таком каталоге прошёл бы молча.
    named = {p[:p.rfind("/") + 1] for p in files}
    problems = []
    covered = 0
    total = 0
    statuses = {}
    kind = {}
    for rel in walk_assets():
        total += 1
        dir_ = rel[:rel.rfind("/") + 1]
        status = files.get(rel) or ("" if dir_ in named else classes.get(dir_, ""))
        if not status:
            problems.append("нет строки провенанса: %s" % rel)
            continue
        covered += 1
        statuses[status] = statuses.get(status, 0) + 1
        # Однородная разбивка по СТАТУСУ. Срез «уровень строки» и срез «статус»
        # ортогональны, и любая двухчленная разбивка теряет третий угол: внутри
        # «закрытых строкой класса» сидят и неизвестно-классовые, и жёлтые-по-наследству.
        if status != "чисто":
            k = ("жёлтый поимённо (своя строка)" if rel in files
                 else "неизвестно по классу" if status == "неизвестно"
                 else "жёлтый по наследству класса")
            kind[k] = kind.get(k, 0) + 1
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
    # Знаменатель сам говорит, что он покрывает (D-206: число обязано печатать свой
    # охват — «покрыто» читается шире, чем проверяет машина).
    order = sorted(statuses.items(), key=lambda kv: -kv[1])
    not_clean = covered - statuses.get("чисто", 0)
    # Два вида незнания не сводятся в одно число: «покрыто наличием записи» значит разное
    # для строки класса (семейство известно, файл внутри него не проверялся) и для
    # строки файла (файл известен, права не установлены).
    named = sorted(r for r in files
                   if files[r] != "чисто" and os.path.exists(os.path.join(ROOT, r)))
    print("  охват: «покрыто» = у файла есть строка провенанса, НЕ «права очищены». "
          "Статусы: %s." % ", ".join("%s %d" % (s, n) for s, n in order))
    print("         у %d из %d права не подтверждены (§8.4 открыт), и exit 0 этого НЕ ловит "
          "— он ловит только отсутствие строки и статус «красный»"
          % (not_clean, covered))
    print("         однородная разбивка по статусу: %s"
          % ", ".join("%s %d" % (k, kind[k]) for k in sorted(kind)))
    print("         (срез «%d строкой класса / %d поимённо» — ДРУГАЯ проекция, по уровню "
          "строки, а не по статусу: внутри «строкой класса» и неизвестно-классовые, и "
          "жёлтые-по-наследству, поэтому однородной считается разбивка по статусу)"
          % (not_clean - len(named), len(named)))
    if named:
        print("         поимённые файлы вне «чисто» (%d): %s"
              % (len(named), ", ".join(os.path.basename(r) for r in named[:6])))
    if withdrawn:
        print("         ещё %d записей в §«Снятые позиции» (ассеты, удалённые из репо) — "
              "чекером не проверяются by design: существование нечего проверять, след "
              "происхождения держится в прозе" % withdrawn)
    return 0


if __name__ == "__main__":
    sys.exit(main())

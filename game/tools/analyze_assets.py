#!/usr/bin/env python3
"""
Поиск неиспользуемых асетов в res://assets/.

used-set = static-референсы (.gd/.tscn/.json, без %s-шаблонов)
         ∪ data-driven (артефакты из ArtifactRegistry, юниты из UnitRegistry,
           иконки из _STAT_ICON).

Асет неиспользуемый, если ни один used-путь не резolves в его res://.
.import-файлы игнорируются.

Категории: artifacts / audio / cursors / data / raw / textures / tiles / ui / units / other.

Использование:
    python3 analyze_assets.py            # dry-run (отчёт)
    python3 analyze_assets.py --archive  # перемещение в _archive (требует флага)
"""
import os
import re
import sys
import shutil
import json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # res://game
ASSETS = os.path.join(ROOT, "assets")
ARCHIVE = os.path.join(os.path.dirname(ROOT), "_archive")  # repo root /_archive (вне game/)

CATEGORIES = ["artifacts", "audio", "cursors", "data", "raw",
              "textures", "tiles", "ui", "units"]

STATIC_EXTS = (".gd", ".tscn", ".tres", ".json")
ASSET_EXTS = (".png", ".jpg", ".jpeg", ".mp3", ".wav", ".ogg")


def _res(path):
    return "res://" + os.path.relpath(path, ROOT).replace(os.sep, "/")


def _category(path):
    rel = os.path.relpath(path, ASSETS)
    parts = rel.split(os.sep)
    # <cat>/... под assets/
    cat = parts[0] if parts else "other"
    return cat if cat in CATEGORIES else "other"


def _iter_assets():
    for dirpath, _dirs, files in os.walk(ASSETS):
        if ".godot" in dirpath:
            continue
        for f in files:
            if f.endswith(".import") or f == ".DS_Store":
                continue
            if not f.lower().endswith(ASSET_EXTS):
                continue
            yield os.path.join(dirpath, f)


def _read_text(path):
    try:
        with open(path, "r", encoding="utf-8", errors="ignore") as fh:
            return fh.read()
    except OSError:
        return ""


def _static_refs():
    """Литеральные res://assets/... (без %s-шаблонов) из .gd/.tscn/.json."""
    refs = set()
    pat = re.compile(r'res://assets/([^\s"\')\]]+\.(?:png|jpg|jpeg|mp3|wav|ogg))')
    for dirpath, _dirs, files in os.walk(ROOT):
        # game/tools/ — только инструменты генерации: их референсы не считаются
        # (задача 2.4, ambiguous -> keep).
        if ".godot" in dirpath or "/tools/" in dirpath + "/":
            continue
        for f in files:
            if not f.lower().endswith(STATIC_EXTS):
                continue
            fp = os.path.join(dirpath, f)
            if os.path.basename(fp) == os.path.basename(__file__):
                continue
            text = _read_text(fp)
            for m in pat.finditer(text):
                refs.add(m.group(0))
    return refs


def _data_driven():
    """Артефакты / юниты / иконки, определяемые из данных (data-driven)."""
    used = set()

    # Артефакты: _register(&"id", ...) -> res://assets/artifacts/<id>.png
    reg = os.path.join(ROOT, "scripts", "autoload", "ArtifactRegistry.gd")
    text = _read_text(reg)
    for m in re.finditer(r'_register\(\s*&"([^"]+)"', text):
        used.add("res://assets/artifacts/%s.png" % m.group(1))

    # Юниты: "key": [ ... ] в UnitRegistry -> <key>.png и <key>_s.png
    ureg = os.path.join(ROOT, "scripts", "autoload", "UnitRegistry.gd")
    text = _read_text(ureg)
    for m in re.finditer(r'"([^"]+)":\s*\[', text):
        k = m.group(1)
        used.add("res://assets/units/%s.png" % k)
        used.add("res://assets/units/%s_s.png" % k)

    # Иконки: значения _STAT_ICON dict -> res://assets/ui/icons/<val>.png
    ais = os.path.join(ROOT, "scripts", "ui", "ArtifactInventoryScreen.gd")
    text = _read_text(ais)
    dm = re.search(r'_STAT_ICON\s*:=\s*\{(.*?)\}', text, re.S)
    if dm:
        for m in re.finditer(r'"([^"]+)":\s*"([^"]+)"', dm.group(1)):
            used.add("res://assets/ui/icons/%s.png" % m.group(2))

    return used


def _restore():
    """Задача 4.2: откат из manifest.json — возвращает каждый перемещённый
    ассет (+ .import sidecar) на исходный fs-путь, удаляет manifest."""
    man_path = os.path.join(ARCHIVE, "manifest.json")
    if not os.path.exists(man_path):
        print("Manifest не найден: %s (нечего восстанавливать)" % man_path)
        return
    with open(man_path, "r", encoding="utf-8") as fh:
        manifest = json.load(fh)
    restored = 0
    for e in manifest:
        dest = e["destination"]
        if not os.path.exists(dest):
            continue
        rel = e["original"][len("res://"):].replace("/", os.sep)
        src = os.path.join(ROOT, rel)
        os.makedirs(os.path.dirname(src), exist_ok=True)
        shutil.move(dest, src)
        imp = dest + ".import"
        if os.path.exists(imp):
            shutil.move(imp, src + ".import")
        restored += 1
    print("Восстановлено: %d" % restored)
    os.remove(man_path)


def main():
    if "--restore" in sys.argv:
        _restore()
        return
    archive = "--archive" in sys.argv
    static = _static_refs()
    data = _data_driven()
    used = static | data

    assets = list(_iter_assets())
    unused = []
    by_cat = {c: [] for c in CATEGORIES + ["other"]}
    for a in assets:
        rp = _res(a)
        if rp not in used:
            unused.append((a, rp, _category(a), "no used path resolves to it"))
            by_cat[_category(a)].append((a, rp))

    # Отчёт
    print("=" * 70)
    print("АНАЛИЗ НЕИСПОЛЬЗУЕМЫХ АСЕТОВ")
    print("=" * 70)
    print("Static-референсов: %d | data-driven: %d | асетов всего: %d"
          % (len(static), len(data), len(assets)))
    print("Неиспользуемых: %d" % len(unused))
    print("-" * 70)
    for c in CATEGORIES + ["other"]:
        items = by_cat[c]
        if items:
            print("\n[%s] — %d" % (c, len(items)))
            for _a, rp in by_cat[c]:
                print("   %s  (no used path resolves to it)" % rp)

    if archive:
        os.makedirs(ARCHIVE, exist_ok=True)
        manifest = []
        for a, rp, _c, _reason in unused:
            dest = os.path.join(ARCHIVE, os.path.basename(a))
            i = 0
            while os.path.exists(dest):
                i += 1
                dest = os.path.join(ARCHIVE, "%s_%d%s"
                                    % (os.path.splitext(a)[0], i,
                                       os.path.splitext(a)[1]))
            shutil.move(a, dest)
            # перемещаем .import sidecar
            imp = a + ".import"
            if os.path.exists(imp):
                shutil.move(imp, dest + ".import")
            manifest.append({"original": rp, "destination": dest,
                             "category": _c, "reason": "no used path resolves to it"})
        man_path = os.path.join(ARCHIVE, "manifest.json")
        with open(man_path, "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)
        print("\nПеремещено: %d. Manifest: %s" % (len(manifest), man_path))
    else:
        print("\nDRY-RUN. Перемещение не выполнено. Используйте --archive.")


if __name__ == "__main__":
    main()

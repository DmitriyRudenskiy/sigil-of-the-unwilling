#!/usr/bin/env python3
r"""Гейт «путь узла из скрипта существует в сцене» (T-296).

Почему это отдельная проверка, а не GdUnit-тест. Экраны собираются генераторами
(`game/scripts/build/gen_*.gd`), пути узлов в скриптах — строковые литералы.
Переезд блока (D-280) меняет сцену, скрипт остаётся, а идиома
`get_node_or_null(...) is Label` делает отказ неотличимым от успеха: тест экрана
проходит, подпись на экране пустая. Так потерялись левая колонка (D-280), строки
надетого (T-254), рамки куклы (T-294), полоса маны и навыков (T-295).

Что делает. Для каждой пары «скрипт ↔ сцена» (связь из `ext_resource
type="Script"` + `script=ExtResource(...)` в `game/scenes/**/*.tscn`) собирает
строковые литералы путей (`get_node*`, `has_node`, `$Path`, `const ПУТЬ` как
аргумент вызова), превращает `%d`/`%s` в регулярку (`Slot%d` → `Slot\d+`) и
краснеет, если непрерывная цепочка имён не встречается в дереве сцены — включая
влитые поддеревья `instance=`, которые разворачиваются рекурсивно.

Почему цепочка «от любого узла», а не «от якоря скрипта»: `get_node` берёт путь
от того узла, на котором его вызвали (`box.get_node("MusicRow/MusicLabel")`), а
статика без dataflow-анализа этого не знает. Мера ловит ровно исходный класс
дефектов — блок переименовали или сняли, цепочка оборвалась; и не красит вызовы
от рантайм-узлов.

Границы меры (печатает чекер, чтобы «не проверил» не читалось как «проверил»):
  · переезд блока, сохранившего цепочку целиком, не видится (для hero-экрана на
    это есть `scripts/check_hero_layout_map.py`);
  · конкатенация путей (`"Row" + str(i)`) и пути из данных/сигналов не видны;
  · узлы, создаваемые рантаймом, — исключение с обязательной причиной
    (`scripts/node_paths_allowlist.txt`); запись без причины и устаревшая запись
    красные: список обязан гнить в обе стороны, иначе это корзина;
  · имена, которые скрипт присваивает сам (`.name = "…"`, `.name = КОНСТАНТА`,
    цикл по литеральному списку), вычитаются автоматически — тот же класс, что
    исключение, но он виден из кода;
  · пути от `/root/…` глобальные, к сцене не относятся;
  · нижняя граница счётчиков: измеритель, переставший что-либо видеть, обязан
    краснеть, а не рапортовать «чисто». Урок T-296: первая версия замера молча
    объявляла нерезолвленным всё — `re.escape` не экранирует `%`, замена искала
    экранированную форму, и шаблон не матчился никогда. Счётчик «плохо везде»
    читается как «много проблем», а не как «измеритель сломался».

Запуск: python3 scripts/check_node_paths.py
"""

from __future__ import annotations

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, os.pardir))
GAME = os.path.join(REPO, "game")
SCENES = os.path.join(GAME, "scenes")
ALLOWLIST = os.path.join(HERE, "node_paths_allowlist.txt")

# Нижняя граница: на 2026-10-29 скан видит 50 скриптов и 314 литерала. Падение
# вдвое означает сломанный скан (другой формат сцен или вызовов), а не то, что
# путей в игре стало вдвое меньше.
SCRIPTS_FLOOR = 12
LITERALS_FLOOR = 80

CALL_RE = re.compile(
    r"(?:get_node|get_node_or_null|get_node_or_default|has_node)\s*\(\s*"
    r"(?:\"([^\"]*)\"|([A-Za-z_][A-Za-z0-9_]*)\s*[,)])")
DOLLAR_QUOTED_RE = re.compile(r"\$\"([^\"]+)\"")
DOLLAR_RE = re.compile(r"\$([A-Za-z_][A-Za-z0-9_]*(?:/[A-Za-z_][A-Za-z0-9_]*)*)")
CONST_RE = re.compile(r"const\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=\n]*)?=\s*\"([^\"]*)\"")
ASSIGNED_NAME_RE = re.compile(r"(?:\.name|\bname)\s*(?::=|[+*-]?=)\s*\"([^\"]+)\"")
# `.name = DATE_LABEL_NAME` — то же присвоение имени, но через константу: без её
# разворота гейт красит узел, который скрипт создал сам (campaign_hud.gd:511).
ASSIGNED_IDENT_RE = re.compile(
    r"(?:\.name|\bname)\s*(?::=|[+*-]?=)\s*([A-Za-z_][A-Za-z0-9_]*)\s*$", re.M)
# `for action_name in ["BuildFarm", "Hire", …]: action.name = action_name` —
# имя из литерального списка; без этого правила city_screen потребовал бы семь
# записей исключений вместо нуля.
FOR_LIST_RE = re.compile(r"for\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s+\[([^\]]*)\]")
NODE_HDR_RE = re.compile(r"^\[node\s+(.*?)\]\s*$")
ATTR_RE = re.compile(r"(\w+)=\"([^\"]*)\"")
EXT_RE = re.compile(r"ext_resource\s+([^\n]*)")
# `instance=ExtResource("1")` — значение НЕ в кавычках, ATTR_RE его не видит.
INSTANCE_RE = re.compile(r'instance\s*=\s*ExtResource\(\s*"([^"]+)"\s*\)')
FMT_RE = re.compile(r"%[ds]")


def _attrs(chunk: str) -> dict:
    return dict(ATTR_RE.findall(chunk))


def _ext_resources(text: str) -> dict:
    """id → (type, res://путь). Порядок атрибутов в .tscn не фиксирован."""
    out = {}
    for m in EXT_RE.finditer(text):
        a = _attrs(m.group(1))
        if {"id", "path", "type"} <= set(a):
            out[a["id"]] = (a["type"], a["path"])
    return out


def _res_local(path: str) -> str:
    return (os.path.normpath(os.path.join(GAME, path[len("res://"):]))
            if path.startswith("res://") else "")


def _matcher(lit: str) -> re.Pattern:
    """«Хвост» для литерала пути: `%d` → `\\d+`, `%s` → `[^/]+`.

    Почему регуляркой, а не подстановкой известных чисел: код метит узлы и
    `Slot0` (army_panel.gd:15, `"Slot%d" % i`), и `EquipIcon_%d`
    (artifact_inventory_screen.gd), а `re.escape` в Python 3.7+ не экранирует
    `%` — на первой версии замера это и стрельнуло.
    """
    parts = []
    i = 0
    while i < len(lit):
        m = FMT_RE.match(lit, i)
        if m:
            parts.append(r"\d+" if m.group(0) == "%d" else r"[^/]+")
            i = m.end()
            continue
        parts.append(re.escape(lit[i]))
        i += 1
    return re.compile("".join(parts) + "$")


class Scene:
    """Имена узлов сцены (пути от корня) + влитые поддеревья `instance=`."""

    def __init__(self, path: str, seen=None):
        self.path = path
        self.paths = set()
        self._seen = seen if seen is not None else set()
        self._load()

    def _merge(self, base: str, sub: "Scene") -> None:
        for p in sub.paths:
            self.paths.add(f"{base}/{p}" if base and p else (base or p))

    def _load(self) -> None:
        real = os.path.normpath(self.path)
        if real in self._seen or not os.path.isfile(real):
            return
        self._seen.add(real)
        with open(self.path, encoding="utf-8") as fh:
            text = fh.read()
        ext = _ext_resources(text)
        cur_rel = ""
        for line in text.splitlines():
            if not line.startswith("[node "):
                continue
            hdr = line.strip()
            m = NODE_HDR_RE.match(hdr)
            if not m:
                continue
            a = _attrs(m.group(1))
            name = a.get("name", "")
            parent = a.get("parent")
            if parent is None:
                cur_rel = ""
                self.paths.add("")          # корень сцены
            else:
                base = "" if parent == "." else parent
                cur_rel = f"{base}/{name}" if base else name
                self.paths.add(cur_rel)
            mi = INSTANCE_RE.search(hdr)
            inst = mi.group(1) if mi else ""
            if ext.get(inst, ("", ""))[0] == "PackedScene":
                local = _res_local(ext[inst][1])
                if local:
                    self._merge(cur_rel, Scene(local, self._seen))

    def resolve(self, rel: str) -> bool:
        """Непрерывная цепочка сегментов встречается в дереве где-нибудь."""
        rel = rel.strip("/")
        if not rel:
            return False
        if "%" not in rel:
            needle = "/" + rel
            return any(p == rel or p.endswith(needle) for p in self.paths)
        rx = _matcher(rel)
        return any(rx.search("/" + p) for p in self.paths)


def iter_scenes(root: str):
    for dirpath, _dirs, files in os.walk(root):
        for f in sorted(files):
            if f.endswith(".tscn"):
                yield os.path.join(dirpath, f)


def scene_script_pairs(root: str) -> dict:
    """rel-путь скрипта → [Scene]; скрипт может висеть на нескольких сценах."""
    pairs = {}
    for sp in iter_scenes(root):
        with open(sp, encoding="utf-8") as fh:
            text = fh.read()
        script_paths = sorted({p for (t, p) in _ext_resources(text).values()
                               if t == "Script"})
        if not script_paths:
            continue
        tree = Scene(sp)
        for rp in script_paths:
            local = _res_local(rp)
            if local and os.path.isfile(local):
                rel = os.path.relpath(local, REPO).replace(os.sep, "/")
                pairs.setdefault(rel, []).append(tree)
    return pairs


def literals_of(script_path: str):
    """({литерал: как найден}, {имена, которые скрипт присваивает себе сам})."""
    with open(script_path, encoding="utf-8") as fh:
        text = fh.read()
    consts = dict(CONST_RE.findall(text))
    out = {}
    for lit, ident in CALL_RE.findall(text):
        if lit:
            out.setdefault(lit, "get_node")
        elif ident in consts:
            out.setdefault(consts[ident], f"const {ident}")
    for lit in DOLLAR_QUOTED_RE.findall(text):
        out.setdefault(lit, "$Path")
    for lit in DOLLAR_RE.findall(text):
        out.setdefault(lit, "$Path")
    assigned = set(ASSIGNED_NAME_RE.findall(text))
    for ident in ASSIGNED_IDENT_RE.findall(text):
        if ident in consts:
            assigned.add(consts[ident])
    for var, items in FOR_LIST_RE.findall(text):
        if not re.search(r"(?:\.name|\bname)\s*(?::=|[+*-]?=)\s*" + var + r"\b", text):
            continue
        assigned.update(re.findall(r"\"([^\"]+)\"", items))
    return out, assigned


def load_allowlist(path: str):
    """(записи, битые строки); запись = (скрипт, литерал, причина)."""
    if not os.path.isfile(path):
        return None, [f"нет файла {os.path.basename(path)} — без него исключения "
                      "живут в головах и превращаются в корзину"]
    rows, bad = [], []
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            s = line.rstrip("\n")
            if not s.strip() or s.strip().startswith("#"):
                continue
            parts = s.split("\t")
            if len(parts) < 3 or not parts[2].strip():
                bad.append(f"{os.path.basename(path)}:{n}: нет причины "
                           f"(формат: скрипт<TAB>литерал<TAB>причина): {s.strip()[:90]}")
                continue
            rows.append((parts[0].strip(), parts[1].strip(), parts[2].strip()))
    return rows, bad


def check(scenes_root: str = SCENES, allowlist: str = ALLOWLIST):
    """→ (код, строки отчёта). Печатает вызывающий: тестам удобнее читать
    возвращаемое, чем перехватывать stdout."""
    pairs = scene_script_pairs(scenes_root)
    allow, allow_bad = load_allowlist(allowlist)
    literals_total = runtime_exempt = global_paths = 0
    unresolved = []
    used = set()
    for script_rel in sorted(pairs):
        abs_path = os.path.join(REPO, script_rel)
        if not os.path.isfile(abs_path):
            continue
        lits, assigned = literals_of(abs_path)
        for lit, how in sorted(lits.items()):
            literals_total += 1
            if lit.startswith("/"):
                global_paths += 1
                continue
            leaf = lit.strip("/").split("/")[-1]
            stem = leaf.split("%")[0].rstrip("_")
            if leaf in assigned or (stem and stem in assigned):
                runtime_exempt += 1
                continue
            if any(sc.resolve(lit) for sc in pairs[script_rel]):
                continue
            reason = next((r for (s, l, r) in (allow or [])
                           if s == script_rel and l == lit), None)
            if reason:
                used.add((script_rel, lit))
                continue
            unresolved.append((script_rel, lit, how))

    lines = ["=== путь узла из скрипта ↔ сцена (T-296) ===",
             f"скриптов в парах со сценами: {len(pairs)}; литералов пути: {literals_total}",
             f"  исключено: рантайм-имена {runtime_exempt}, глобальные /root/… {global_paths}"]
    if allow is None:
        return 1, lines + [f"RED: {b}" for b in allow_bad]
    if allow_bad:
        return 1, lines + [f"RED: {b}" for b in allow_bad]
    stale = [f"{s}\t{l}" for (s, l, _r) in allow if (s, l) not in used]
    if stale:
        return 1, lines + [
            f"RED: устаревших исключений {len(stale)} — путь резолвится, запись "
            "больше не нужна (список обязан гнить в обе стороны):"] + [f"  {s}" for s in stale]
    lines.append(f"  исключений с причиной: {len(allow)}")
    broken = []
    if len(pairs) < SCRIPTS_FLOOR:
        broken.append(f"скриптов {len(pairs)} < {SCRIPTS_FLOOR}")
    if literals_total < LITERALS_FLOOR:
        broken.append(f"литералов {literals_total} < {LITERALS_FLOOR}")
    if broken:
        return 1, lines + ["RED: измеритель сломан (" + "; ".join(broken) + ") — «чисто» "
                           "от «ничего не вижу» отличается только счётчиком"]
    if unresolved:
        return 1, lines + [
            f"RED: нерезолвившихся путей {len(unresolved)} — в сцене нет такого "
            "узла, исключения не покрыли:"] + \
            [f"  {s}: \"{l}\" ({h})" for s, l, h in unresolved] + \
            [f"  правка: починить путь/сцену ИЛИ добавить запись в "
             f"{os.path.basename(allowlist)} с причиной (табы)"]
    lines.append("PATH-GATE: OK — каждый литерал пути либо существует в сцене, "
                 "либо исключён с причиной")
    return 0, lines


def main() -> int:
    code, lines = check()
    print("\n".join(lines))
    return code


if __name__ == "__main__":
    sys.exit(main())

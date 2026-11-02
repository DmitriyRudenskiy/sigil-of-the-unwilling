#!/usr/bin/env python3
"""Читатель слоёв прогона (срез test-suite-restructure, 2026-11-02).

Два инварианта, без которых `run_tests.sh --tier=` бесполезен:

* **карантин не бывает мёртвым** — запись без даты/причины, с наступившим сроком или
  с подстрокой, которая не режет ни один файл сюиты, красит прогон **до** запуска
  (опечатка в карантине маскируется под работающий карантин: `-i` не исключил бы
  ничего, а сюжет продолжил бы красить);
* **слой не имеет права быть тихой выборкой** — то, что раннер реально собрал
  (строки `Run Test Suite:` из его лога), сверяется с деревом `tests/` за вычетом
  исключений слоя. Файл, пропавший из прогона переименованием или маской имени,
  здесь красный, а не «просто не запустился».

Запуск (из корня репо, так же зовёт `game/run_tests.sh`):

    python3 scripts/check_test_tiers.py quarantine --root game/tests
    python3 scripts/check_test_tiers.py coverage --log <лог> --root game/tests --scope full
    python3 scripts/check_test_tiers.py coverage --log <лог> --root game/tests/smoke \
        --scope smoke --require-nonempty

Exit codes: 0 — ок (печатает сводку), 2 — красный (причина в stderr).
"""
from __future__ import annotations

import argparse
import datetime
import re
import sys
from pathlib import Path

# Строка собранной сюиты в логе GdUnit-раннера (ANSI снимается перед матчингом).
COLLECTED_RE = re.compile(r"^Run Test Suite:\s*(\S+)", re.M)
# Сюжетом считается **наследование или тест-функция**, а не маска `test_*.gd`:
# в наборе живые файлы вида `save_roundtrip_state.gd` — маска потеряла бы их и
# покрасовала бы как «не собранные».
SUITE_RE = re.compile(r"^(?:extends\s+\S*Test\b|func test_)", re.M)
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
MAX_NAMED = 10


def canonical(root: Path, path: Path) -> str:
    """Ключ файла набора — путь от каталога `tests` (он один и в `res://…`, и в дереве).

    `--root` бывает и `game/tests`, и `game/tests/smoke` (слой smoke меряется своим
    поддеревом); ключ один и тот же, поэтому лог и дерево сравниваются без поправок
    на то, какой корень передали.
    """
    parts = path.parts
    if "tests" in parts:
        return "/".join(parts[parts.index("tests"):])
    return "/".join(path.relative_to(root).parts)


def suite_files(root: Path, excludes: list[str]) -> list[str]:
    """Файлы набора под корнем `root` (канонические ключи), минус подстроки `excludes`."""
    out = []
    for path in sorted(root.rglob("*.gd")):
        if not path.is_file() or path.name.endswith(".uid"):
            continue
        key = canonical(root, path.resolve())
        if any(needle in key for needle in excludes):
            continue
        if SUITE_RE.search(path.read_text(encoding="utf-8", errors="ignore")):
            out.append(key)
    return out


def _named(keys: list[str]) -> str:
    head = ", ".join(keys[:MAX_NAMED])
    return head + (f", … (+{len(keys) - MAX_NAMED})" if len(keys) > MAX_NAMED else "")


def cmd_quarantine(args: argparse.Namespace) -> int:
    """Активные записи карантина в stdout (`подстрока\tдата\tпричина`), красный — на мёртвых."""
    today = args.today or datetime.date.today().isoformat()
    registry = Path(args.quarantine)
    if not registry.exists():
        return 0
    files = suite_files(Path(args.root), [])
    rows = []
    problems = []
    for lineno, raw in enumerate(registry.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        cols = line.split("\t")
        if len(cols) != 3:
            problems.append(
                f"строка {lineno}: нужно `<подстрока><TAB><ГГГГ-ММ-ДД><TAB><причина>`, "
                f"а в строке {len(cols)} пол(ей): {line!r}"
            )
            continue
        needle, until, reason = (c.strip() for c in cols)
        if not DATE_RE.match(until):
            problems.append(f"строка {lineno}: срок «{until}» — не ГГГГ-ММ-ДД: {needle}")
            continue
        if until < today:
            problems.append(
                f"строка {lineno}: срок карантина {until} наступил ({today}) — "
                f"чинить или переносить срок осознанно: {needle} ({reason})"
            )
            continue
        if not any(needle in key for key in files):
            problems.append(
                f"строка {lineno}: подстрока «{needle}» не режет ни один файл набора — "
                f"карантин выглядит работающим, а `-i` не исключает ничего"
            )
            continue
        rows.append(f"{needle}\t{until}\t{reason}")
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 2
    print("\n".join(rows))
    return 0


def cmd_coverage(args: argparse.Namespace) -> int:
    """Сверка собранного с деревом: ни один файл набора не должен пропасть молча."""
    log = Path(args.log).read_text(encoding="utf-8", errors="ignore")
    log = re.sub(r"\x1b\[[0-9;]*m", "", log)
    root = Path(args.root)
    collected = {
        canonical(root, Path(match.removeprefix("res://")))
        for match in COLLECTED_RE.findall(log)
    }
    expected = set(suite_files(root, args.exclude))
    if not collected and not expected:
        if args.require_nonempty:
            print(
                f"слой {args.scope} не собрал НИ ОДНОЙ сюиты и дерево под {root} пусто — "
                "зелёный тишиной не является результатом",
                file=sys.stderr,
            )
            return 2
        print(f"собрано 0 из 0 (корень {root}, слой {args.scope})")
        return 0
    if not collected:
        print(
            f"слой {args.scope} не собрал НИ ОДНОЙ сюиты из {len(expected)} в дереве {root} — "
            "фильтр слоя не режет ничего, проверь --root и исключения",
            file=sys.stderr,
        )
        return 2
    missing = sorted(expected - collected)
    extra = sorted(collected - expected)
    if missing or extra:
        if missing:
            print(f"СЛОЙ {args.scope}: НЕ СОБРАНО {len(missing)}: {_named(missing)}", file=sys.stderr)
        if extra:
            print(
                f"СЛОЙ {args.scope}: СОБРАНО ВНЕ НАБОРА {len(extra)}: {_named(extra)} — "
                "файл есть в логе, но нет в дереве (переехал? лог от другого прогона?)",
                file=sys.stderr,
            )
        return 2
    print(f"собрано {len(collected)} из {len(expected)} (корень {root}, слой {args.scope})")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="check_test_tiers.py", description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    q = sub.add_parser("quarantine", help="активные записи game/tests/quarantine.txt")
    q.add_argument("--quarantine", default="game/tests/quarantine.txt")
    q.add_argument("--root", default="game/tests")
    q.add_argument("--today", default="", help="ГГГГ-ММ-ДД (для теста даты; по умолчанию сегодня)")
    q.set_defaults(func=cmd_quarantine)

    c = sub.add_parser("coverage", help="собранное раннером против дерева tests/")
    c.add_argument("--log", required=True, help="лог GdUnit-раннера (tee прогона)")
    c.add_argument("--root", default="game/tests")
    c.add_argument("--scope", default="full")
    c.add_argument("--exclude", action="append", default=[], help="подстрока-исключение слоя")
    c.add_argument("--require-nonempty", action="store_true", help="пустой слой красить")
    c.set_defaults(func=cmd_coverage)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())

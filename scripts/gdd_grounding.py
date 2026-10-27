#!/usr/bin/env python3
"""Ре-грундинг-дайджест контура фаз GDD (change `gdd-phase-workflow`, D-274).

Метод требует «каждый вход — перечитать ЦЕЛИКОМ gdd/, DECISIONS.md, CHANGELOG.md».
Замер 2026-10-26: `docs/*.md` — 15 701 строка / 2,62 МБ, реестры — ещё 1,54 МБ,
`docs/mvp/TICKETS.md` — 0,80 МБ. Требование физически неисполнимо, а имитация его
исполнения и убила предыдущий контур (теги `v3-grilled-pass3/4` есть, `v4-locked`
нет). Дайджест даёт то, ради чего шаг существует — противоречия и висящее, — за
лимитируемое число строк.

Запуск: `python3 scripts/gdd_grounding.py [--limit=400]`
"""
from __future__ import annotations

import argparse
import datetime
import pathlib
import re
import subprocess
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
TICKETS = DOCS / "mvp" / "TICKETS.md"

# Порядок отсечки: ⚑ → ⏳ → 🔴 → остальное (D-274). Всё, что не влезло,
# считается в строке «отброшено».
LIFECYCLE = ("draft", "audited", "deepened", "verified", "locked")
EXEMPT = ("reference", "snapshot", "archived", "redirect")
PENDING_RE = r"⏳\s*\*\*Предварительное"
PRIO_RE = "🔴|🟡|🟢"  # тот же словарь приоритетов, что в gdd_gate
VISION_RE = r"⚑\s*\*\*Меняет видение"


def strip_code(line: str) -> str:
    """Инлайн-код — это примеры конвенций, а не данные (та же чистка, что в gdd_gate)."""
    return re.sub(r"`[^`]*`", "", line)


def _rows(name: str, prefix: str) -> list[str]:
    """Строки таблицы реестра, начинающиеся с `| <prefix>`."""
    path = DOCS / name
    if not path.exists():
        return []
    pat = re.compile(r"^\| " + re.escape(prefix))
    return [l for l in path.read_text(encoding="utf-8").split("\n") if pat.match(l)]


def _q_rows() -> list[str]:
    path = DOCS / "QUESTIONS.md"
    return [l for l in path.read_text(encoding="utf-8").split("\n") if l.startswith("| Q-M")]


def _sections() -> dict[str, str]:
    out: dict[str, str] = {}
    for f in sorted(DOCS.glob("[0-9]*.md")):
        m = re.search(r"^status:\s*(.+)$", f.read_text(encoding="utf-8")[:400], re.M)
        out[f.name] = m.group(1).strip() if m else "БЕЗ-STATUS"
    return out


def _head() -> str:
    try:
        sha = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
                             capture_output=True, text=True, timeout=30).stdout.strip()
    except Exception:
        sha = "?"
    return f"HEAD {sha} · {datetime.date.today().isoformat()}"


def blocks() -> list[tuple[int, list[str]]]:
    """(приоритет, строки) — чем меньше число, тем раньше попадает в дайджест."""
    out: list[tuple[int, list[str]]] = [(0, [_head()])]

    drows = _rows("DECISIONS.md", "D-")
    qrows = _q_rows()
    vision = [l for l in drows if re.search(VISION_RE, strip_code(l))]
    pending = [l for l in drows if re.search(PENDING_RE, strip_code(l))]
    for prio, title, rows in ((1, "⚑ меняют видение — проверяются первыми", vision),
                              (2, "⏳ предварительные (рекомендация агента)", pending)):
        block = [f"## {title}: {len(rows)}"]
        block += [f"  {l[:160]}" for l in rows[:10]]
        if len(rows) > 10:
            block.append(f"  … ещё {len(rows) - 10}")
        out.append((prio, block))

    # Открытый = не закрыт и не редирект на другой реестр (`Q-M1 → **K-M1**`).
    # Две ошибки, найденные на живом реестре: (1) «открытый = в строке есть 🔴»
    # давало «🔴 0» при 13 легаси-вопросах без приоритета; (2) любая стрелка со
    # `**` считалась редиректом, из-за чего строки нового формата
    # `Q-M105 → **открыт (…)**` выпадали из счёта и дайджест врал вниз.
    def _closed(l: str) -> bool:
        return bool(re.search(r"→?\s*\*\*(?<!не)закрыт|(?<!не)закрыт \(", l))

    def _redirect(l: str) -> bool:
        return not _closed(l) and bool(re.search(r"→\s*\*\*[A-Z]-", l))

    closed = [l for l in qrows if _closed(l)]
    redirected = [l for l in qrows if _redirect(l)]
    open_rows = [l for l in qrows if not _closed(l) and not _redirect(l)]
    red = [l for l in open_rows if "🔴" in l]
    yellow = [l for l in open_rows if "🟡" in l]
    legacy = [l for l in open_rows if not re.search(PRIO_RE, strip_code(l))]
    block = [f"## Открытые вопросы: {len(open_rows)} (🔴 {len(red)}, 🟡 {len(yellow)}, "
             f"без приоритета {len(legacy)}) · редиректов на K-## {len(redirected)} · "
             f"закрытых {len(closed)} · всего строк {len(qrows)}"]
    listed = red + yellow + [l for l in legacy if l not in red and l not in yellow]
    block += [f"  {l[:160]}" for l in listed[:12]]
    if len(listed) > 12:
        block.append(f"  … ещё {len(listed) - 12}")
    out.append((3, block))

    sec = _sections()
    cnt = Counter(sec.values())
    block = ["## Состояния GDD-секций (docs/[0-9]*.md): " +
             ", ".join(f"{k}={v}" for k, v in sorted(cnt.items()))]
    unproven = [n for n, s in sec.items()
                if s in ("verified", "locked") and not re.search(r"D-\d", (DOCS / n).read_text(encoding="utf-8"))]
    block.append(f"  без ссылки на D-### при verified/locked: {len(unproven)}")
    block += [f"  {n}" for n in unproven[:10]]
    out.append((4, block))

    tail = ["## Хвосты реестров"]
    drows = _rows("DECISIONS.md", "D-")
    tail.append(f"  DECISIONS.md: {len(drows)} записей, последние 5:")
    tail += [f"    {l[:150]}" for l in drows[-5:]]
    tail.append(f"  QUESTIONS.md: {len(qrows)} строк, последние 3:")
    tail += [f"    {l[:150]}" for l in qrows[-3:]]
    if TICKETS.exists():
        heads = re.findall(r"^## (T-\d+.*?)$", TICKETS.read_text(encoding="utf-8"), re.M)
        tail.append(f"  TICKETS.md: {len(heads)} секций, последняя: {heads[-1][:120] if heads else '—'}")
    tail.append("  Полные тексты: docs/00-INDEX.md · проверщики: gdd_gate.py, "
                "check_docs_links.py, audit_docs_vs_code.py")
    out.append((5, tail))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=400)
    args = ap.parse_args()
    emitted = 0
    dropped = 0
    for _, lines in sorted(blocks(), key=lambda b: b[0]):
        for line in lines:
            if emitted < args.limit:
                print(line)
                emitted += 1
            else:
                dropped += 1
    if dropped:
        print(f"… отброшено по лимиту {args.limit}: {dropped} строк "
              f"(приоритет отсечки: ⚑ → ⏳ → 🔴 → прочее)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Гейт контура фаз GDD (change `gdd-phase-workflow`, D-272/D-273).

Проверяет то, что решаемо из репозитория, и только это:

1. Состояние GDD-секции (`docs/[0-9]*.md`) — из жизненного цикла
   `draft → audited → deepened → verified → locked`; `canon` читается как `locked`
   (D-271); не-GDD-роли (`reference`, `snapshot`, `archived`, `redirect`) — вне
   машины.
2. Секция в `verified`/`locked` обязана ссылаться на `D-###`: состояние «зафиксировано»
   без основания — это зафиксированное ничто.
3. Новые записи реестров полны: строка вопроса в новой форме (с «Статус:») обязана
   нести `[agent]`/`[human]` и приоритет; строка решения с «Отвергнутые» обязана нести
   «Контекст» и «Статус».
4. Ratchet (D-272): число старых записей без полей имеет право только сокращаться —
   рост краснит прогон. Базлайн — `scripts/gdd_gate.baseline.json`.
5. Номера рисков `R-##` не повторяются.
6. Каждая ссылка `Q-M##` в `docs/` существует в реестре `docs/QUESTIONS.md`
   (банк `docs/bank/` — зона без гейта). Ссылка на незаведённый вопрос выглядит как
   закрытая дыра и читается как доказательство.
7. Путь в backticks внутри живой GDD-секции существует в репозитории (реестры
   `CHANGELOG`/`DECISIONS`/`QUESTIONS` — история, они исключены). Число мёртвых
   путей — часть ratchet: сокращается, но не растёт.
8. Номер вопроса в `docs/QUESTIONS.md` не задвоен (дубль = закрытие записали новой
   строкой, а «открытую» оставили: счётчик открытых начинает врать). Число дублей —
   часть ratchet'а.
9. Тикет, ссылающийся на предварительное (`⏳`) решение, обязан нести
   `blocked-on: D-xxx` — иначе связь «ждёт решения» теряется.

Выход: 0 — зелено, 1 — нарушения, 2 — базлайн отсутствует/битый.
`--update-baseline` перезаписывает базлайн текущими замерами.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
BASELINE = pathlib.Path(__file__).with_name("gdd_gate.baseline.json")

LIFECYCLE = ("draft", "audited", "deepened", "verified", "locked", "canon")
EXEMPT = ("reference", "snapshot", "archived", "redirect")
PENDING_RE = r"⏳\s*\*\*Предварительное"
TYPE_RE = r"\[(agent|human)\]"
PRIO_RE = "🔴|🟡|🟢"

BACKLOG_KEYS = ("q_without_type", "q_without_priority", "d_without_rejected",
                "risks_without_number", "dead_paths", "q_duplicate_numbers")


def strip_code(line: str) -> str:
    """Убрать инлайн-код: примеры конвенций в реестрах не должны читаться как данные.

    Без этого строка, которая *описывает* префикс `⏳ **Предварительное**`,
    записывается как предварительное решение (первый же прогон на D-272).
    """
    return re.sub(r"`[^`]*`", "", line)


def gdd_sections() -> dict[str, str]:
    out: dict[str, str] = {}
    for f in sorted(DOCS.glob("[0-9]*.md")):
        m = re.search(r"^status:\s*(.+)$", f.read_text(encoding="utf-8")[:400], re.M)
        out[f.name] = m.group(1).strip() if m else "БЕЗ-STATUS"
    return out


def q_rows() -> list[str]:
    return [l for l in (DOCS / "QUESTIONS.md").read_text(encoding="utf-8").split("\n")
            if l.startswith("| Q-M")]


def d_rows() -> list[str]:
    return [l for l in (DOCS / "DECISIONS.md").read_text(encoding="utf-8").split("\n")
            if re.match(r"^\| D-\d", l)]


def risk_rows() -> list[str]:
    """Строки таблиц риска: блок с заголовком `| Риск | ...`.

    Маркдаун-списки в `09-risks.md` — это открытые заметки, а не риски: первая
    версия проверщика считала их рисками и измерила не то (11 строк там, где
    таблицы с 10 рисками).
    """
    path = DOCS / "09-risks.md"
    if not path.exists():
        return []
    rows: list[str] = []
    inside = False
    for line in path.read_text(encoding="utf-8").split("\n"):
        if line.startswith("| Риск"):
            inside = True
            continue
        if inside and re.match(r"^\|[\s:-]+\|", line):
            continue
        if inside and line.startswith("|"):
            rows.append(line)
            continue
        inside = False
    return rows


def measure() -> dict[str, int]:
    q = q_rows()
    d = d_rows()
    r = risk_rows()
    return {
        "q_without_type": sum(1 for l in q if not re.search(TYPE_RE, strip_code(l))),
        "q_without_priority": sum(1 for l in q if not re.search(PRIO_RE, strip_code(l))),
        "d_without_rejected": sum(1 for l in d if "Отвергнутые" not in l),
        "risks_without_number": sum(1 for l in r if not re.search(r"\bR-\d+", l)),
        "dead_paths": len(dead_paths()),
        "q_duplicate_numbers": duplicate_numbers(),
    }


DEAD_PATH_PREFIX = ("docs/", "game/", "scripts/", "openspec/", "design/", "tools/",
                    "assets/")
DEAD_PATH_EXEMPT = ("CHANGELOG", "DECISIONS", "QUESTIONS")


def duplicate_numbers() -> int:
    """Сколько номеров вопросов встречаются больше одного раза.

    Дубль появляется так: закрытие записывают новой строкой, а старую «открытую»
    оставляют. Счётчик открытых вопросов становится призрачным, и шаг 0 аудита
    показывает то, чего нет. Старые строки не переписываются (D-272), поэтому
    номер — бэклог ratchet'а, а не ошибка.
    """
    seen: dict[str, int] = {}
    for l in q_rows():
        m = re.match(r"^\| (Q-M\d+)", l)
        if m:
            seen[m.group(1)] = seen.get(m.group(1), 0) + 1
    return sum(1 for c in seen.values() if c > 1)


def dead_paths() -> list[str]:
    """Пути в backticks внутри GDD-секций, которых нет в репозитории.

    Реестры (`CHANGELOG`/`DECISIONS`/`QUESTIONS`) — история: они вне выборки GDD-секций
    (нет ведущей цифры) и дополнительно исключены по имени; имеют право ссылаться на
    путь, который существовал тогда. Живой документ такого права
    не имеет: ссылка на несуществующий носитель читается как подтверждение.
    Путь разрешается и от корня репо, и от `game/` (в доках — res//-конвенция).
    """
    bad = []
    for f in sorted(DOCS.glob("[0-9]*.md")):
        if any(e in f.stem for e in DEAD_PATH_EXEMPT):
            continue
        for raw in sorted(set(re.findall(r"`([^`\s]+)`", f.read_text(encoding="utf-8")))):
            if not raw.startswith(DEAD_PATH_PREFIX) or any(
                    c in raw for c in "*…<>{}"):
                continue
            rel = raw.split(":")[0]
            if "." not in rel.rsplit("/", 1)[-1]:
                continue
            if (ROOT / rel).exists() or (ROOT / "game" / rel).exists():
                continue
            bad.append(f"{f.name}: {raw}")
    return bad


def question_citations() -> list[str]:
    """Ссылки `Q-M##` вне реестра. Банк исключён (зона без гейта, как везде).

    Без этой проверки аудит может объявить строку закрытой ссылкой на «открытый
    вопрос», которого нет: расхождение становится невидимым, а выглядит как учтённое.
    """
    reg = (DOCS / "QUESTIONS.md").read_text(encoding="utf-8")
    known = set(re.findall(r"Q-M(\d+)", reg))
    bad = []
    for f in sorted(DOCS.rglob("*.md")):
        rel = f.relative_to(DOCS).as_posix()
        if rel.startswith("bank/"):
            continue
        for qid in sorted(set(re.findall(r"Q-M(\d+)", f.read_text(encoding="utf-8")))):
            if qid not in known:
                bad.append(f"ССЫЛКА НА НЕВЕДОМЫЙ ВОПРОС: {rel}: Q-M{qid} нет в реестре")
    return bad


def check() -> tuple[list[str], dict[str, int]]:
    errors: list[str] = []
    sec = gdd_sections()
    for name, status in sec.items():
        if status in EXEMPT:
            continue
        if status == "БЕЗ-STATUS":
            errors.append(f"СЕКЦИЯ БЕЗ СТАТУСА: docs/{name} — жизненный цикл "
                          f"({', '.join(LIFECYCLE)}) требует frontmatter `status:`")
        elif status not in LIFECYCLE:
            errors.append(f"СЕКЦИЯ ВНЕ МАШИНЫ СОСТОЯНИЙ: docs/{name}: status: {status}")
        if status in ("verified", "locked") and not re.search(r"D-\d",
                                                              (DOCS / name).read_text(encoding="utf-8")):
            errors.append(f"FIXED БЕЗ ОСНОВАНИЯ: docs/{name}: status: {status}, ссылки D-### нет")

    for l in q_rows():
        t = strip_code(l)
        if "Статус:" not in t:
            continue  # старая форма — идёт в бэклог, а не в ошибку
        if not re.search(TYPE_RE, t):
            errors.append(f"НОВЫЙ ВОПРОС БЕЗ ТИПА: {l[:90]}")
        if not re.search(PRIO_RE, t):
            errors.append(f"НОВЫЙ ВОПРОС БЕЗ ПРИОРИТЕТА: {l[:90]}")

    for l in d_rows():
        if "Отвергнутые" not in l:
            continue
        t = strip_code(l)
        for field in ("Контекст", "Статус"):
            if field not in t:
                errors.append(f"НОВОЕ РЕШЕНИЕ БЕЗ ПОЛЯ «{field}»: {l[:90]}")

    nums = [n for l in risk_rows() for n in re.findall(r"\bR-(\d+)", l)]
    dupes = {n for n in nums if nums.count(n) > 1}
    for n in sorted(dupes):
        errors.append(f"ДВОЙНОЙ НОМЕР РИСКА: R-{n}")

    pending = [re.match(r"^\| (D-\d+)", l).group(1) for l in d_rows()
               if re.search(PENDING_RE, strip_code(l)) and re.match(r"^\| (D-\d+)", l)]
    tickets = (DOCS / "mvp" / "TICKETS.md")
    if tickets.exists() and pending:
        text = tickets.read_text(encoding="utf-8")
        for sect in re.split(r"(?=^## T-\d)", text, flags=re.M):
            head = re.match(r"^## (T-\d+)", sect)
            if not head:
                continue
            for dnum in pending:
                if dnum in sect and "blocked-on" not in sect:
                    errors.append(f"ТИКЕТ {head.group(1)} ждёт {dnum}, а `blocked-on` не несёт")

    errors += question_citations()

    return errors, measure()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--update-baseline", action="store_true")
    args = ap.parse_args()

    errors, now = check()

    if args.update_baseline:
        BASELINE.write_text(json.dumps(now, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print("БАЗЛАЙН обновлён:", ", ".join(f"{k}={v}" for k, v in sorted(now.items())))
        return 0

    if not BASELINE.exists():
        print("БАЗЛАЙН ОТСУТСТВУЕТ: scripts/gdd_gate.baseline.json "
              "(создать: --update-baseline)")
        return 2
    try:
        base = json.loads(BASELINE.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"БАЗЛАЙН БИТЫЙ: {exc}")
        return 2

    print("бэклог (только сокращается, D-272):")
    for k in BACKLOG_KEYS:
        cur, old = now.get(k, 0), base.get(k, 0)
        mark = "РОСТ" if cur > old else "OK"
        print(f"  {k}: {cur} (базлайн {old}) {mark}")
        if cur > old:
            errors.append(f"RATCHET: {k} вырос с {old} до {cur}")

    if errors:
        print(f"\nНАРУШЕНИЯ ({len(errors)}):")
        for e in errors:
            print(f"  {e}")
        return 1
    print("\nGDD-GATE: GREEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

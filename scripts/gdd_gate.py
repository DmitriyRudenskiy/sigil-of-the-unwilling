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
8. В `docs/QUESTIONS.md` нет **строк-призраков**: строка открыта, хотя по её номеру
   уже есть закрытая. Закрытие оформляли новой строкой, прежнюю «открытую» оставляли —
   дайджест шага 0 звал владельца отвечать отвеченное. Две закрытые строки одного номера
   (ре-опен Q-M18) и соседние id с суффиксом (`Q-M23`/`Q-M23b` — разные вопросы)
   призраками не считаются. Число призраков — часть ratchet'а.
9. Тикет, ссылающийся на предварительное (`⏳`) решение, обязан нести
   `blocked-on: D-xxx` — иначе связь «ждёт решения» теряется.
10. Номер тикета в `docs/mvp/TICKETS.md` принадлежит одной записи: заголовок
    `T-###` встречается один раз. Метрика считается по **лишним** заголовкам
    (на 2026-10-29: 215 заголовков − 208 номеров = 7 лишних, шесть номеров живут
    по два-три заголовка; замер снят после регистрации тикетов T-290/T-291,
    которые сами добавили по заголовку); старые коллизии — базлайн, новые красят
    прогон.
    Там же — число тикетов с двумя футерами `Статус` (`t_multi_footer`, T-292):
    закрытие дописывали новым футером, прежний оставался «открыт». Номера вопросов сюда не входят: там две строки под одним
    номером — документированный приём (ре-опен, «технический дубль», п. 8).

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
                "risks_without_number", "dead_paths", "q_ghost_rows",
                "t_duplicate_headers", "t_multi_footer")


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


TICKET_SPLIT = r"(?m)^(?=#{2,4} (?:Тикет )?T-\d+(?:[ ·.]|$))"


def ticket_sections() -> list[str]:
    """Реестр, нарезанный по заголовкам тикетов (по одному заголовку на кусок)."""
    f = DOCS / "mvp" / "TICKETS.md"
    if not f.exists():
        return []
    return [s for s in re.split(TICKET_SPLIT, f.read_text(encoding="utf-8"))
            if re.match(r"^#{2,4} ", s)]


def ticket_headers() -> list[str]:
    """Заголовки тикетов реестра, в обеих исторических формах.

    `### T-7 · заголовок` (текущая конвенция) и `## T-141. заголовок` (старая,
    45 записей). После номера обязателен разделитель — пробел, `·` или точка:
    без него в заголовки попадали `### T-111-full` (суффикс — другой id, как
    `Q-M23b` в реестре вопросов) и `### T-143, круг 18b` (это статусный подзаголовок
    внутри тикета, а не тикет). Первая версия замера на `` дала 10 «коллизий»
    вместо настоящих 7 — ровно тот класс ошибки, из-за которого D-224 перенумеровывал
    реестры вручную.
    """
    return [re.match(r"^#{2,4} (?:Тикет )?(T-\d+)", s).group(1)
            for s in ticket_sections()]


def t_duplicate_headers() -> int:
    """Сколько заголовков тикетов стоят под уже занятым номером (T-290).

    Дайджест и ссылки `T-###` решаются по номеру; когда под номером две записи,
    ссылка неоднозначна, а «тикет закрыт» перестаёт быть утверждением. О том,
    что это не выдумка, говорит и D-224: три worktree задубляли T-157 и D-226.
    """
    h = ticket_headers()
    return len(h) - len(set(h))


def t_multi_footer() -> int:
    """Сколько тикетов несут два футера `Зависит … Статус` (T-292).

    Закрывая тикет, агенты дописывали новый футер, не убирая прежний, и в одном
    блоке оказывалось «открыт» и «закрыт» подряд. Это тот же класс, что и
    строки-призраки в реестре вопросов (п. 8): счётчик открытых тикетов врёт,
    а «тикет открыт» перестаёт быть утверждением.
    """
    return sum(1 for s in ticket_sections()
               if len(re.findall(r"(?m)^\*\*Зависит:\*\*.*?\*\*Статус:\*\*[^\n]*", s)) > 1)


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
        "q_ghost_rows": ghost_rows(),
        "t_duplicate_headers": t_duplicate_headers(),
        "t_multi_footer": t_multi_footer(),
    }


DEAD_PATH_PREFIX = ("docs/", "game/", "scripts/", "openspec/", "design/", "tools/",
                    "assets/")
DEAD_PATH_EXEMPT = ("CHANGELOG", "DECISIONS", "QUESTIONS")


def redirect_row(l: str) -> bool:
    """Перенаправление вопроса в другой реестр: `→ **K-12**` и т.п."""
    return bool(re.search(r"→\s*\*\*[A-Z]-", l))


def closed_row(l: str) -> bool:
    """Признак закрытия строки реестра — тот же, что у дайджеста `gdd_grounding`.

    `(**закрыт` — маркер статуса; `закрыт (` — закрытие, записанное в колонке «Статус»
    или «Блокирует». Причастие «закрыты» и «не закрыт» маркерами не считаются, иначе
    строка «права так и не были закрыты» читается как отвеченный вопрос.
    """
    return bool(re.search(r"→?\s*\*\*(?<!не)закрыт|(?<!не)закрыт \(", l))


def ghost_rows() -> int:
    """Сколько строк реестра выглядят открытыми, хотя по их номеру есть закрытая.

    Механика дефекта: закрытие оформлялось новой строкой (`| Q-M37 → **закрыт (...)** |`),
    а прежняя открытая строка оставалась жива — дайджест шага 0 звал владельца отвечать
    отвеченное (11 таких строк, 2026-10-27). Две закрытые строки одного номера — история
    ре-опена, не призрак; `Q-M23` и `Q-M23b` — разные вопросы (суффикс значим).
    """
    by: dict[str, list[bool]] = {}
    for l in q_rows():
        m = re.match(r"^\| (Q-M\d+[a-z]?)", l)
        if m:
            by.setdefault(m.group(1), []).append(
                closed_row(l) or bool(re.search(r"→\s*\*\*[A-Z]-", l)))
    return sum(1 for f in by.values() if len(f) > 1 and any(f) and not all(f))


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


def decision_citations() -> list[str]:
    """Двойные номера решений и ссылки `D-###` вне реестра (T-229).

    Зеркало `question_citations`: у реестра решений не было ни проверки коллизий,
    ни проверки призрачных номеров — аудит решал «номер встречается», а не «номер
    один». На `main` две строки жили под номером `D-259`: ссылка из тикета была
    неоднозначной, а молчаливый переименованный дубль никто не ловил.
    """
    nums = [m.group(1) for l in d_rows() if (m := re.match(r"^\| (D-\d+)", l))]
    known = set(nums)
    bad = [f"ДВОЙНОЙ НОМЕР РЕШЕНИЯ: {n} в `docs/DECISIONS.md` {nums.count(n)} строки"
           for n in sorted(known) if nums.count(n) > 1]
    for f in sorted(DOCS.rglob("*.md")):
        rel = f.relative_to(DOCS).as_posix()
        if rel.startswith("bank/"):
            continue  # зона без гейта — как у вопросов
        for did in sorted({d for d in re.findall(r"\bD-\d+\b",
                                                 f.read_text(encoding="utf-8"))
                           if d not in known}):
            bad.append(f"ССЫЛКА НА НЕВЕДОМОЕ РЕШЕНИЕ: {rel}: {did} нет в реестре")
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
    errors += decision_citations()

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

    # Комплект ключей базлайна обязан совпадать с измеряемым: отсутствующий ключ
    # молча означал бы «нулевой допуск», а лишний (опечатка в имени) — метрику,
    # которую никто не проверяет. Оба варианта выглядят как зелёный прогон.
    missing = [k for k in BACKLOG_KEYS if k not in base]
    stale = [k for k in base if k not in BACKLOG_KEYS]
    if missing or stale:
        print("БАЗЛАЙН НЕ СООТВЕТСТВУЕТ МЕТРИКАМ "
              f"(нет: {missing or '—'}; не измеряется: {stale or '—'}) "
              "— обновить: --update-baseline")
        return 2

    print("бэклог (только сокращается, D-272):")
    for k in BACKLOG_KEYS:
        cur, old = now[k], base[k]
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

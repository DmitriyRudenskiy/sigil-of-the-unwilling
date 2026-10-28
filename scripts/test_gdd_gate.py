"""Тесты гейта контура фаз GDD и дайджеста ре-грундинга.

Поведение проверяется, а не подразумевается: у сверщика доков (`audit_docs_vs_code`)
уже был дефект, который не видно по выводу «всё чисто» (ratchet был записан
наоборот). Здесь тот же риск: молча зелёный ratchet и дайджест, который печатает не
то, что должен по приоритету.

Запуск: `python3 -m pytest scripts/test_gdd_gate.py -q`
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gdd_gate as gate  # noqa: E402


@pytest.fixture
def world(tmp_path, monkeypatch):
    docs = tmp_path / "docs"
    (docs / "mvp").mkdir(parents=True)
    (docs / "01-core-loop.md").write_text(
        "---\ntitle: Цикл\nstatus: deepened\n---\n\n# Цикл\n", encoding="utf-8")
    (docs / "02-mechanics.md").write_text(
        "---\ntitle: Механики\nstatus: locked\n---\n\n# Механики\nОснование: D-1.\n", encoding="utf-8")
    (docs / "12-asset-audit.md").write_text(
        "---\ntitle: Аудит\nstatus: reference\n---\n", encoding="utf-8")
    (docs / "QUESTIONS.md").write_text(
        "| # | Вопрос | Контекст | Варианты | Блокирует |\n|---|---|---|---|---|\n"
        "| Q-M1 | старый вопрос без полей | тут | а/б | нет |\n"
        "| Q-M2 | **[human] 🔴** новый | тут | а/б | Статус: открыт |\n",
        encoding="utf-8")
    (docs / "DECISIONS.md").write_text(
        "| D-1 | 2026-10-01 | Старое решение без полей. |\n"
        "| D-2 | 2026-10-26 | Новое. Контекст: Q-M2. Отвергнутые: (а). Статус: ✅ финальное. |\n"
        "| D-3 | 2026-10-26 | Пример конвенции: `⏳ **Предварительное (рекомендация).**` "
        "не является предварительным. Контекст: Q-M2. Отвергнутые: нет. Статус: ✅. |\n",
        encoding="utf-8")
    (docs / "09-risks.md").write_text(
        "---\ntitle: Риски\nstatus: deepened\n---\n\n# Риски\n\n**Риски (пивот):**\n\n"
        "| Риск | Вероятность | Митигация |\n|---|---|---|\n"
        "| R-1 — пожар | высокая | нет |\n| риск без номера | средняя | нет |\n\n"
        "- заметка, а не риск\n", encoding="utf-8")
    (docs / "mvp" / "TICKETS.md").write_text(
        "## T-1 — тикет\n\n**Состояние:** открыт.\n", encoding="utf-8")
    baseline = tmp_path / "baseline.json"
    monkeypatch.setattr(gate, "DOCS", docs)
    monkeypatch.setattr(gate, "BASELINE", baseline)
    return docs, baseline


@pytest.fixture(autouse=True)
def _clean_argv(monkeypatch):
    """argparse внутри main() не должен видеть argv pytest-а (`-q` роняет его на exit 2)."""
    monkeypatch.setattr(sys, "argv", ["script"])


def _green_baseline(world):
    _, baseline = world
    baseline.write_text(json.dumps(gate.measure()), encoding="utf-8")


def test_clean_world_is_green(world, capsys):
    _green_baseline(world)
    assert gate.main() == 0
    assert "GDD-GATE: GREEN" in capsys.readouterr().out


def test_unknown_status_is_red(world, monkeypatch):
    _green_baseline(world)
    (world[0] / "01-core-loop.md").write_text(
        "---\nstatus: audited-ish\n---\n", encoding="utf-8")
    errors, _ = gate.check()
    assert any("СЕКЦИЯ ВНЕ МАШИНЫ СОСТОЯНИЙ" in e for e in errors)


def test_non_gdd_role_is_exempt(world):
    _green_baseline(world)
    errors, _ = gate.check()
    assert not any("12-asset-audit" in e for e in errors)


def test_section_without_status_is_red(world):
    """GDD-секция без `status:` не может быть ни в одном состоянии — это красный."""
    _green_baseline(world)
    (world[0] / "03-progression.md").write_text("# Прогрессия\n\nБез frontmatter.\n",
                                                encoding="utf-8")
    errors, _ = gate.check()
    assert any("СЕКЦИЯ БЕЗ СТАТУСА" in e for e in errors)


def test_locked_without_decision_is_red(world):
    _green_baseline(world)
    (world[0] / "02-mechanics.md").write_text(
        "---\nstatus: locked\n---\n\n# Механики\nОснования нет.\n", encoding="utf-8")
    errors, _ = gate.check()
    assert any("FIXED БЕЗ ОСНОВАНИЯ" in e for e in errors)


def test_new_question_without_type_is_red(world):
    _green_baseline(world)
    q = world[0] / "QUESTIONS.md"
    q.write_text(q.read_text(encoding="utf-8") +
                 "| Q-M3 | новый без типа и приоритета | тут | а/б | Статус: открыт |\n",
                 encoding="utf-8")
    errors, _ = gate.check()
    assert any("НОВЫЙ ВОПРОС БЕЗ ТИПА" in e for e in errors)
    assert any("БЕЗ ПРИОРИТЕТА" in e for e in errors)


def test_legacy_rows_are_backlog_not_error(world):
    _green_baseline(world)
    errors, now = gate.check()
    assert not errors
    assert now["q_without_type"] == 1  # Q-M1 — бэклог, не нарушение


def test_backlog_growth_is_red(world, capsys):
    _green_baseline(world)
    q = world[0] / "QUESTIONS.md"
    q.write_text(q.read_text(encoding="utf-8") + "| Q-M9 | старая форма | тут | а/б | нет |\n",
                 encoding="utf-8")
    assert gate.main() == 1
    assert "RATCHET" in capsys.readouterr().out


def test_markdown_bullets_are_not_risks(world):
    """Заметки списком в 09-risks.md — не риски: их число не входит в бэклог."""
    _green_baseline(world)
    _, now = gate.check()
    assert now["risks_without_number"] == 1  # только строка таблицы без R-##
    r = world[0] / "09-risks.md"
    r.write_text(r.read_text(encoding="utf-8") + "- ещё одна заметка списком\n",
                 encoding="utf-8")
    _, now2 = gate.check()
    assert now2["risks_without_number"] == 1


def test_missing_baseline_exits_two(world, capsys):
    assert gate.main() == 2
    assert "БАЗЛАЙН ОТСУТСТВУЕТ" in capsys.readouterr().out


def test_marker_inside_inline_code_is_not_a_pending_decision(world):
    """D-3 описывает конвенцию в бэктиках — он не предварительное решение."""
    _green_baseline(world)
    errors, _ = gate.check()
    assert not any("blocked-on" in e for e in errors)


def test_ticket_awaiting_pending_decision_needs_blocked_on(world):
    _green_baseline(world)
    d = world[0] / "DECISIONS.md"
    d.write_text(d.read_text(encoding="utf-8") +
                 "| D-4 | 2026-10-27 | ⏳ **Предварительное (рекомендация).** Текст. "
                 "Контекст: Q-M2. Отвергнутые: нет. Статус: ⏳. |\n", encoding="utf-8")
    t = world[0] / "mvp" / "TICKETS.md"
    t.write_text(t.read_text(encoding="utf-8") + "\n## T-2 — ждёт решения\n\nСм. D-4.\n",
                 encoding="utf-8")
    errors, _ = gate.check()
    assert any("ТИКЕТ T-2 ждёт D-4" in e for e in errors)
    t.write_text(t.read_text(encoding="utf-8").replace("См. D-4.", "blocked-on: D-4"),
                 encoding="utf-8")
    errors, _ = gate.check()
    assert not any("ТИКЕТ T-2" in e for e in errors)


def test_question_citation_outside_registry_is_red(world):
    """Ссылка дока на незаведённый вопрос красная: «вопрос задан» ≠ «вопрос существует»."""
    docs, _ = world
    (docs / "01-core-loop.md").write_text(
        (docs / "01-core-loop.md").read_text(encoding="utf-8") + "\nСм. Q-M900 и Q-M901.\n",
        encoding="utf-8")
    bad, _ = gate.check()
    hits = [b for b in bad if "НЕВЕДОМЫЙ ВОПРОС" in b]
    assert len(hits) == 2 and any("Q-M901" in h for h in hits), bad
    (docs / "QUESTIONS.md").write_text(
        (docs / "QUESTIONS.md").read_text(encoding="utf-8")
        + "| Q-M900 | вопрос | тут | а/б | нет | Статус: ⏳ открыт |\n", encoding="utf-8")
    bad, _ = gate.check()
    hits = [b for b in bad if "НЕВЕДОМЫЙ ВОПРОС" in b]
    assert len(hits) == 1 and "Q-M900" not in hits[0], hits


def test_bank_is_exempt_from_question_citations(world):
    """Банк — зона без гейта: ссылка внутри банка не красится."""
    docs, _ = world
    (docs / "bank").mkdir()
    (docs / "bank" / "K-1.md").write_text("Q-M999\n", encoding="utf-8")
    bad, _ = gate.check()
    assert [b for b in bad if "НЕВЕДОМЫЙ ВОПРОС" in b] == [], bad


def test_duplicate_decision_number_is_red(world):
    """Две строки реестра под одним номером — красные: ссылка теряет адресата.

    Дефект жил на `main` молча: `D-259` означал то полосу стиля, то полосу единиц
    замера, и тикет ссылался на обе.
    """
    docs, _ = world
    reg = docs / "DECISIONS.md"
    reg.write_text(reg.read_text(encoding="utf-8")
                   + "| D-1 | 2026-10-27 | Вторая строка под занятым номером. "
                     "Контекст: Q-M2. Отвергнутые: нет. Статус: ✅. |\n", encoding="utf-8")
    bad, _ = gate.check()
    hits = [b for b in bad if "ДВОЙНОЙ НОМЕР РЕШЕНИЯ" in b]
    assert len(hits) == 1 and "D-1" in hits[0] and "2 строки" in hits[0], bad


def test_decision_citation_outside_registry_is_red(world):
    docs, _ = world
    (docs / "01-core-loop.md").write_text(
        (docs / "01-core-loop.md").read_text(encoding="utf-8") + "\nСм. D-900.\n",
        encoding="utf-8")
    bad, _ = gate.check()
    hits = [b for b in bad if "НЕВЕДОМОЕ РЕШЕНИЕ" in b]
    assert len(hits) == 1 and "D-900" in hits[0], bad
    reg = docs / "DECISIONS.md"
    reg.write_text(reg.read_text(encoding="utf-8")
                   + "| D-900 | 2026-10-27 | Заведённое задним числом. "
                     "Контекст: Q-M2. Отвергнутые: нет. Статус: ✅. |\n", encoding="utf-8")
    assert [b for b in gate.check()[0] if "НЕВЕДОМОЕ РЕШЕНИЕ" in b] == []


def test_bank_is_exempt_from_decision_citations(world):
    docs, _ = world
    (docs / "bank").mkdir()
    (docs / "bank" / "K-2.md").write_text("D-999\n", encoding="utf-8")
    bad, _ = gate.check()
    assert [b for b in bad if "НЕВЕДОМОЕ РЕШЕНИЕ" in b] == [], bad


def test_baseline_key_set_must_match_the_metrics(world, tmp_path, monkeypatch):
    """Ключ базлайна не совпадает с метриками → exit 2, а не «нулевой допуск по умолчанию».

    Молча отсутствующий ключ означал бы ноль допуска, лишний (опечатка в имени) —
    метрику без гейта. Оба читаются как зелёный прогон.
    """
    bl = tmp_path / "b.json"
    bl.write_text('{"q_without_type": 97}', encoding="utf-8")
    monkeypatch.setattr(gate, "BASELINE", bl)
    monkeypatch.setattr("sys.argv", ["gdd_gate.py"])
    assert gate.main() == 2


def test_ghost_row_is_measured_reopen_and_suffix_are_not(world):
    """Открытая строка с закрытым двойником = призрак; два закрытых и `Q-M##b` — нет."""
    docs, _ = world
    q = docs / "QUESTIONS.md"
    q.write_text(q.read_text(encoding="utf-8")
                 + "| Q-M501 | **открытая половина** | тут | а | нет |\n"
                 + "| Q-M501 → **закрыт (2026-10-27, владелец)** | | | | |\n"
                 + "| Q-M502 → **закрыт (2026-10-03, владелец)** | | | | |\n"
                 + "| Q-M502 (ре-опен) → **закрыт (2026-10-04, владелец)** | | | | |\n"
                 + "| Q-M503 | **сосед** | тут | а | нет |\n"
                 + "| Q-M503b | **другой вопрос с суффиксом** | тут | а | нет |\n",
                 encoding="utf-8")
    assert gate.ghost_rows() == 1


def test_dead_path_in_gdd_section_is_measured(world, monkeypatch):
    """Путь-призрак в живой секции попадает в замер ratchet'а; живой путь — нет."""
    docs, _ = world
    (world[0].parent / "scripts").mkdir(exist_ok=True)
    (world[0].parent / "scripts" / "gdd_gate.py").write_text("x\n", encoding="utf-8")
    (docs / "01-core-loop.md").write_text(
        (docs / "01-core-loop.md").read_text(encoding="utf-8")
        + "\nНоситель: `game/scripts/nope.gd` и `scripts/gdd_gate.py`.\n", encoding="utf-8")
    monkeypatch.setattr(gate, "ROOT", world[0].parent)
    got = gate.dead_paths()
    assert any("game/scripts/nope.gd" == d.split(": ", 1)[1] for d in got), got
    assert not any("gdd_gate.py" in d for d in got), got


def test_registries_are_exempt_from_dead_paths(world, monkeypatch):
    """Реестры — история: ссылка на несуществующий путь в них не считается."""
    docs, _ = world
    (docs / "00-CHANGELOG.md").write_text("было: `game/scripts/nope.gd`\n", encoding="utf-8")
    monkeypatch.setattr(gate, "ROOT", world[0].parent)
    assert not any("nope.gd" in d for d in gate.dead_paths())


def test_duplicate_risk_number_is_red(world):
    _green_baseline(world)
    r = world[0] / "09-risks.md"
    text = r.read_text(encoding="utf-8").replace(
        "| R-1 — пожар | высокая | нет |",
        "| R-1 — пожар | высокая | нет |\n| R-1 — второй риск на том же номере | низкая | нет |")
    r.write_text(text, encoding="utf-8")
    errors, _ = gate.check()
    assert any("ДВОЙНОЙ НОМЕР РИСКА" in e for e in errors)


def test_ticket_headers_read_both_registry_forms(world):
    """Старая (`## T-141.`) и новая (`### T-7 ·`) формы — один пространственный ряд номеров.

    45 заголовков репо живут в старой форме; гейт, который читает только новую,
    посчитал бы их отсутствующими тикетами, а коллизии — по урезанному множеству.
    """
    docs, _ = world
    (docs / "mvp" / "TICKETS.md").write_text(
        "## T-141. старая форма с точкой\n\n### T-7 · новая форма с медианой\n\n"
        "#### Тикет T-9 · форма со словом\n\n### T-100 · граница номера\n", encoding="utf-8")
    assert gate.ticket_headers() == ["T-141", "T-7", "T-9", "T-100"]


def test_suffixed_id_and_status_subheader_are_not_tickets(world):
    """`T-111-full` — соседний id, `T-143, круг 18b` — подзаголовок статуса, не тикеты.

    Замер на `` считал и то и другое занятыми номерами и рапортовал 10 коллизий
    там, где их семь. Мера обязана быть уже, чем «номер встречается в строке».
    """
    docs, _ = world
    (docs / "mvp" / "TICKETS.md").write_text(
        "### T-111. основной тикет\n\n### T-111-full. суффиксный сосед\n\n"
        "## T-143 — тикет\n\n### T-143, круг 18b (мера направления)\n", encoding="utf-8")
    assert gate.ticket_headers() == ["T-111", "T-143"]
    assert gate.t_duplicate_headers() == 0


def test_duplicate_ticket_number_is_measured(world):
    """Два заголовка под одним номером = один лишний заголовок в замере."""
    docs, _ = world
    (docs / "mvp" / "TICKETS.md").write_text(
        "### T-227 · первая запись\n\n### T-241 · другая\n\n"
        "### T-227 · вторая запись на занятом номере\n", encoding="utf-8")
    assert gate.t_duplicate_headers() == 1
    assert gate.measure()["t_duplicate_headers"] == 1


def test_new_duplicate_ticket_reds_the_ratchet(world, capsys, monkeypatch):
    """Рост коллизий красит прогон: реестр не имеет права плодить неоднозначные номера."""
    docs, baseline = world
    (docs / "mvp" / "TICKETS.md").write_text(
        "### T-1 · первый\n\n### T-1 · второй на том же номере\n", encoding="utf-8")
    bl = dict(gate.measure())
    bl["t_duplicate_headers"] = 0
    baseline.write_text(json.dumps(bl), encoding="utf-8")
    monkeypatch.setattr("sys.argv", ["gdd_gate.py"])
    assert gate.main() == 1
    assert "t_duplicate_headers" in capsys.readouterr().out


def test_two_status_footers_in_one_ticket_are_measured(world):
    """Два футера `Зависит … Статус` в одном тикете = один лишние «статус» (T-292).

    Так выглядит закрытие, дописанное новым футером поверх прежнего: в блоке
    живёт и «открыт», и «закрыт», а счётчик открытых тикетов врёт.
    """
    docs, _ = world
    (docs / "mvp" / "TICKETS.md").write_text(
        "### T-5 · тикет\n\nТело.\n\n"
        "**Зависит:** нет · **Блокирует:** нет · **Владелец:** агент · **Статус:** открыт\n\n"
        "Позже: закрыто.\n\n"
        "**Зависит:** нет · **Блокирует:** нет · **Владелец:** агент · **Статус:** закрыт\n\n"
        "### T-6 · порядок\n\nОдин футер.\n\n"
        "**Зависит:** нет · **Блокирует:** нет · **Владелец:** агент · **Статус:** открыт\n",
        encoding="utf-8")
    assert gate.t_multi_footer() == 1
    assert gate.measure()["t_multi_footer"] == 1

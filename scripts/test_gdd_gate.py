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


def test_duplicate_risk_number_is_red(world):
    _green_baseline(world)
    r = world[0] / "09-risks.md"
    text = r.read_text(encoding="utf-8").replace(
        "| R-1 — пожар | высокая | нет |",
        "| R-1 — пожар | высокая | нет |\n| R-1 — второй риск на том же номере | низкая | нет |")
    r.write_text(text, encoding="utf-8")
    errors, _ = gate.check()
    assert any("ДВОЙНОЙ НОМЕР РИСКА" in e for e in errors)

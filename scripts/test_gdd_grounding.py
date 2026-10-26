"""Тесты дайджеста ре-грундинга (`scripts/gdd_grounding.py`, D-274).

Две вещи, которые легко сломать молча: лимит (дайджест обязан быть коротким) и
приоритет отсечки (`⚑` обязан попадать в вывод даже когда всё остальное отброшено).

Запуск: `python3 -m pytest scripts/test_gdd_grounding.py -q`
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gdd_grounding as grounding  # noqa: E402


@pytest.fixture
def world(tmp_path, monkeypatch):
    docs = tmp_path / "docs"
    (docs / "mvp").mkdir(parents=True)
    (docs / "01-core-loop.md").write_text(
        "---\ntitle: Цикл\nstatus: verified\n---\n\n# Цикл\nОснование: D-7.\n",
        encoding="utf-8")
    (docs / "02-mechanics.md").write_text(
        "---\ntitle: Механики\nstatus: verified\n---\n\n# Механики\nОснования нет.\n",
        encoding="utf-8")
    (docs / "QUESTIONS.md").write_text(
        "| # | Вопрос | Контекст | Варианты | Блокирует |\n"
        "| Q-M1 | **[human] 🔴** горит | тут | а/б | Статус: открыт |\n"
        "| Q-M2 | **[human] 🟡** желтеет | тут | а/б | Статус: открыт |\n"
        "| Q-M3 → **закрыт (D-1)** | зелёный | тут | а | Статус: закрыт (D-1) |\n",
        encoding="utf-8")
    (docs / "DECISIONS.md").write_text(
        "| D-7 | 2026-10-27 | Обычное. Контекст: Q-M1. Отвергнутые: нет. Статус: ✅. |\n"
        "| D-8 | 2026-10-27 | ⏳ **Предварительное (рекомендация).** Текст. "
        "Контекст: Q-M1. Отвергнутые: нет. Статус: ⏳. |\n"
        "| D-9 | 2026-10-27 | ⚑ **Меняет видение.** Текст. Контекст: Q-M1. "
        "Отвергнутые: нет. Статус: ✅. |\n", encoding="utf-8")
    (docs / "mvp" / "TICKETS.md").write_text("## T-1 — тикет\n\nТекст.\n", encoding="utf-8")
    monkeypatch.setattr(grounding, "DOCS", docs)
    monkeypatch.setattr(grounding, "TICKETS", docs / "mvp" / "TICKETS.md")
    return docs


def _out(docs) -> str:
    return "\n".join(" ".join(b) for _, b in grounding.blocks())


def _block(docs, prio: int) -> str:
    return " ".join(next(b for p, b in grounding.blocks() if p == prio))


def test_digest_lists_open_questions_by_priority(world):
    block = _block(world, 3)
    assert "🔴 1, 🟡 1" in block
    assert "Q-M1" in block and "Q-M2" in block
    assert "Q-M3" not in block  # закрытый вопрос в список открытых не попадает


def test_digest_flags_verified_without_decision(world):
    block = _block(world, 4)
    assert "02-mechanics.md" in block       # verified без ссылки D-###
    assert "01-core-loop.md" not in block   # подтверждён D-7


def test_digest_shows_pending_and_vision_flags(world):
    assert "D-9" in _block(world, 1)   # ⚑
    assert "D-8" in _block(world, 2)   # ⏳


def test_digest_is_bounded_and_reports_dropped(world, capsys, monkeypatch):
    monkeypatch.setattr(sys, "argv", ["gdd_grounding.py", "--limit=3"])
    assert grounding.main() == 0
    out = capsys.readouterr().out.strip().split("\n")
    assert len(out) <= 4  # 3 строки + счётчик отброшенного
    assert "отброшено по лимиту" in out[-1]


def test_vision_flags_surive_truncation(world, capsys, monkeypatch):
    """При жёстком лимите первой остаётся строка `⚑`, а не хвост реестров.`"""
    monkeypatch.setattr(sys, "argv", ["gdd_grounding.py", "--limit=4"])
    grounding.main()
    out = capsys.readouterr().out
    assert "D-9" in out
    assert "DECISIONS.md:" not in out  # хвосты реестров отброшены


def test_convention_examples_in_inline_code_are_not_data(world):
    """Описание префикса `⏳ **Предварительное (рекомендация).**` в бэктиках — пример.`"""
    d = world / "DECISIONS.md"
    d.write_text(d.read_text(encoding="utf-8") +
                 "| D-10 | 2026-10-27 | Правило: `⏳ **Предварительное (рекомендация).**` "
                 "не делает эту строку предварительной. Контекст: Q-M1. Отвергнутые: нет. "
                 "Статус: ✅. |\n", encoding="utf-8")
    assert "D-10" not in _block(world, 2)
def test_digest_is_bounded_and_reports_dropped(world, capsys, monkeypatch):
    monkeypatch.setattr(sys, "argv", ["gdd_grounding.py", "--limit=3"])
    assert grounding.main() == 0
    out = capsys.readouterr().out.strip().split("\n")
    assert len(out) <= 4  # 3 строки + счётчик отброшенного
    assert "отброшено по лимиту" in out[-1]



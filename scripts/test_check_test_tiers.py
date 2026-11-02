"""Читатель слоёв прогона (`check_test_tiers.py`): карантин и полнота сбора.

Держит два инварианта, без которых слои бесполезны: карантин не бывает мёртвым
(подстрока обязана резать файл, срок — наступить) и ни один файл набора не
пропадает из прогона молча. Запускается из корня репо:
`python3 -m pytest scripts/test_check_test_tiers.py -q`."""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_test_tiers as tiers  # noqa: E402

TODAY = "2026-11-02"
FILES = [
    "tests/functional/save_roundtrip_state.gd",
    "tests/functional/test_b.gd",
    "tests/unit/test_a.gd",
]
SUITE = "extends BaseTest\n\nfunc test_x() -> void:\n\tpass\n"


def _log(*suites: str) -> str:
    """Кусок лога GdUnit ровно той формы, что печатает раннер (ANSI опционален)."""
    return "\n".join(f"\x1b[0mRun Test Suite: res://{s}\x1b[0m" for s in suites) + "\n"


@pytest.fixture
def root(tmp_path: Path) -> Path:
    for rel in FILES:
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(SUITE, encoding="utf-8")
    # Помощник набора: .gd без тест-функций сюитой не считается.
    helper = tmp_path / "tests/helpers/factories.gd"
    helper.parent.mkdir(parents=True, exist_ok=True)
    helper.write_text("class_name Factories\n\nstatic func hero() -> Node:\n\treturn Node.new()\n", encoding="utf-8")
    return tmp_path / "tests"


def _quar(tmp_path: Path, body: str) -> Path:
    q = tmp_path / "quarantine.txt"
    q.write_text(body, encoding="utf-8")
    return q


def test_quarantine_пусто_не_красит(tmp_path, root, capsys):
    code = tiers.main(["quarantine", "--quarantine", str(_quar(tmp_path, "# заголовок\n")),
                        "--root", str(root), "--today", TODAY])
    assert code == 0
    assert capsys.readouterr().out.strip() == ""


def test_quarantine_активная_запись_печатается(tmp_path, root, capsys):
    q = _quar(tmp_path, f"tests/functional/test_b\t2026-11-30\tгонка на порту\n")
    assert tiers.main(["quarantine", "--quarantine", str(q), "--root", str(root),
                       "--today", TODAY]) == 0
    assert capsys.readouterr().out.strip() == "tests/functional/test_b\t2026-11-30\tгонка на порту"


def test_quarantine_просрочен_красен(tmp_path, root):
    q = _quar(tmp_path, "tests/functional/test_b\t2026-11-01\tпрошлое\n")
    assert tiers.main(["quarantine", "--quarantine", str(q), "--root", str(root),
                       "--today", TODAY]) == 2


def test_quarantine_кривая_строка_красна(tmp_path, root):
    q = _quar(tmp_path, "tests/functional/test_b\t30 ноября\n")
    assert tiers.main(["quarantine", "--quarantine", str(q), "--root", str(root),
                       "--today", TODAY]) == 2


def test_quarantine_мёртвая_подстрока_красна(tmp_path, root):
    """Опечатка в подстроке при `-i` не исключила бы НИЧЕГО — тест продолжил бы красить."""
    q = _quar(tmp_path, "tests/unit/test_aAAAYO\t2026-11-30\tпричина\n")
    assert tiers.main(["quarantine", "--quarantine", str(q), "--root", str(root),
                       "--today", TODAY]) == 2


def test_набором_считается_наследование_а_не_имя(tmp_path, root):
    """`save_roundtrip_*.gd` — сюита с нестандартным именем; маска `test_*.gd`
    потеряла бы восемь живых сюит и покрасовал бы их как «не собранные»."""
    files = tiers.suite_files(root, [])
    assert "tests/functional/save_roundtrip_state.gd" in files
    assert "tests/helpers/factories.gd" not in files


def test_coverage_все_собраны(tmp_path, root):
    log = tmp_path / "gate.log"
    log.write_text(_log(*FILES), encoding="utf-8")
    assert tiers.main(["coverage", "--log", str(log), "--root", str(root)]) == 0


def test_coverage_файл_не_собран_красен(tmp_path, root):
    log = tmp_path / "gate.log"
    log.write_text(_log(FILES[0]), encoding="utf-8")
    assert tiers.main(["coverage", "--log", str(log), "--root", str(root)]) == 2


def test_coverage_исключение_слоя(tmp_path, root):
    log = tmp_path / "gate.log"
    log.write_text(_log("tests/unit/test_a.gd"), encoding="utf-8")
    code = tiers.main(["coverage", "--log", str(log), "--root", str(root),
                       "--exclude", "tests/functional"])
    assert code == 0


def test_coverage_собрано_вне_набора_красно(tmp_path, root):
    log = tmp_path / "gate.log"
    log.write_text(_log(*FILES, "tests/unit/naming_test.gd"), encoding="utf-8")
    assert tiers.main(["coverage", "--log", str(log), "--root", str(root)]) == 2


def test_coverage_пустой_слой_красен(tmp_path, root):
    """`smoke` без тестов зелёный тишиной — тот же дефект, что уровень без причины."""
    log = tmp_path / "gate.log"
    log.write_text("", encoding="utf-8")
    code = tiers.main(["coverage", "--log", str(log), "--root", str(root),
                       "--exclude", "tests/", "--require-nonempty"])
    assert code == 2


def test_coverage_фильтр_ни_о_чём_не_высит_дерево(tmp_path, root, capsys):
    """Пустой фильтр не должен вываливать 380 имён: сообщение короткое и по делу."""
    log = tmp_path / "gate.log"
    log.write_text("", encoding="utf-8")
    assert tiers.main(["coverage", "--log", str(log), "--root", str(root)]) == 2
    err = capsys.readouterr().err
    assert "НИ ОДНОЙ" in err and "tests/unit/test_a.gd" not in err

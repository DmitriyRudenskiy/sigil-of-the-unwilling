"""Самопроверка резачка листа тайлов из кадра (`scripts/slice_kit_atlas.py`).

Проверки живут в самом скрипте (`--self-test`), здесь только запуск: тот же
вход, что у человека, и та же строка в `TESTS` гейта `scripts/doc_gates.sh`
(задача 5.5 спеки `world-map-scene-slicing` — свой тест на резачку).
"""

import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).with_name("slice_kit_atlas.py")


def test_self_test_passes() -> None:
    out = subprocess.run(
        [sys.executable, str(SCRIPT), "--self-test"], capture_output=True, text=True
    )
    assert out.returncode == 0, out.stdout + out.stderr
    assert "FAIL" not in out.stdout, out.stdout


def test_donor_without_accepted_fit_is_named() -> None:
    """Донор без принятого фита — ошибка с sha, а не молчаливый пустой лист."""
    out = subprocess.run(
        [sys.executable, str(SCRIPT), "--sha", "00000000"],
        capture_output=True,
        text=True,
    )
    assert out.returncode != 0
    assert "00000000" in out.stdout + out.stderr

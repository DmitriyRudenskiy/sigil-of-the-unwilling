"""Обёртка Godot для MCP-стенда (T-172): лог движка и семантика kill.

Обёртка — единственное место, где стенд видит слова движка до отказа readiness:
вендорский node-сервер сам решает, как запускать игру, и наружу эти строки не даёт.
Проверяются два свойства, без которых канал хуже молчания:

* `exec` — PID обёртки обязан стать PID движка, иначе `kill()` node-сервера
  убивает shell, а Godot переживает тест и занимает порт/память (тот же симптом,
  который мы расследуем);
* транзит `--version` — сервер читает версию из stdout, перенаправление её съест.
"""

import os
import subprocess
from pathlib import Path
from types import SimpleNamespace

import pytest

import conftest
from godot_mcp import launch_log_tail, readiness_evidence

LAUNCHER = Path(__file__).resolve().parent / "godot_launcher.sh"

FAKE_ENGINE = "#!/bin/sh\necho \"pid=$$ args=$*\"\n"


def _fake_engine(tmp_path: Path, body: str = FAKE_ENGINE) -> Path:
    real = tmp_path / "fake_godot"
    real.write_text(body, encoding="utf-8")
    real.chmod(0o755)
    return real


def _run(real: Path, log: Path, *args: str) -> SimpleNamespace:
    """Запуск обёртки; pid возвращаем вместе с итогом: `exec` обязан сохранить его."""
    env = dict(os.environ, MCP_GODOT_REAL=str(real), MCP_GODOT_LOG=str(log))
    with subprocess.Popen(["sh", str(LAUNCHER), *args], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, text=True, env=env) as proc:
        out, err = proc.communicate(timeout=120)
    return SimpleNamespace(pid=proc.pid, returncode=proc.returncode, stdout=out, stderr=err)


def test_launcher_exists_and_is_executable() -> None:
    assert LAUNCHER.exists(), f"нет обёртки {LAUNCHER}"
    assert os.access(LAUNCHER, os.X_OK), "обёртка не исполняемая: node не сможет её запустить"


def test_launcher_becomes_the_engine_so_kill_reaches_it(tmp_path: Path) -> None:
    """`exec` означает «тот же PID»: PID обёртки и PID, напечатавший лог, совпадают."""
    real, log = _fake_engine(tmp_path), tmp_path / "launch.log"
    done = _run(real, log, "-d", "--path", "res://")
    assert done.returncode == 0, done.stderr
    body = log.read_text(encoding="utf-8")
    assert f"args=-d --path res://" in body
    assert f"pid={done.pid}" in body, (
        f"лог писал не тот процесс, что запускали (pid={done.pid}): {body!r} — "
        "значит exec нет и kill стенда убивает посредника, а не движок"
    )


def test_version_goes_through_without_redirection(tmp_path: Path) -> None:
    real, log = _fake_engine(tmp_path), tmp_path / "launch.log"
    done = _run(real, log, "--version")
    assert done.returncode == 0, done.stderr
    assert "pid=" in done.stdout, "сервер читает версию из stdout — обёртка его перехватила"
    assert not log.exists(), "--version не должен оставлять лог"


def test_without_log_env_launcher_is_transparent(tmp_path: Path) -> None:
    real = _fake_engine(tmp_path)
    log = tmp_path / "unused"
    env = dict(os.environ, MCP_GODOT_REAL=str(real))
    env.pop("MCP_GODOT_LOG", None)
    done = subprocess.run(["sh", str(LAUNCHER), "--path", "res://"], capture_output=True,
                          text=True, timeout=120, env=env)
    assert done.returncode == 0, done.stderr
    assert "args=--path res://" in done.stdout, "без env обёртка обязана быть прозрачной"
    assert not log.exists()


def test_real_engine_writes_the_launch_log() -> None:
    """Настоящий движок обязан оставить в логе хотя бы баннер: иначе канал есть,
    а слов по нему — ноль (именно этот случай и был виден в гейтах)."""
    if not os.path.exists(conftest.GODOT_BIN):
        pytest.skip(f"нет бинаря Godot: {conftest.GODOT_BIN}")
    log = conftest.GAME_DIR / "tmp" / "mcp_boot" / "selftest_launch.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    log.unlink(missing_ok=True)
    env = dict(os.environ, MCP_GODOT_REAL=conftest.GODOT_BIN, MCP_GODOT_LOG=str(log))
    try:
        done = subprocess.run(
            ["sh", str(LAUNCHER), "--headless", "--path", str(conftest.GAME_DIR), "--quit"],
            capture_output=True, text=True, timeout=300, env=env)
        assert done.returncode == 0, done.stderr[-400:]
        text = log.read_text(encoding="utf-8")
    finally:
        log.unlink(missing_ok=True)
    assert "Godot Engine" in text, text[:400:]


def test_launch_log_tail_distinguishes_absent_empty_and_present(tmp_path: Path) -> None:
    missing = str(tmp_path / "missing.log")
    assert "не собирался" in launch_log_tail("")
    assert "не напечатал ни байта" in launch_log_tail(missing)
    empty = tmp_path / "empty.log"
    empty.write_text("\n \n", encoding="utf-8")
    assert "не напечатал ни байта" in launch_log_tail(str(empty))
    full = tmp_path / "full.log"
    full.write_text("Godot Engine v4.7\nERROR: boom\n", encoding="utf-8")
    tail = launch_log_tail(str(full))
    assert "Godot Engine v4.7" in tail and "ERROR: boom" in tail


def test_readiness_error_keeps_signature_and_adds_launch_log(tmp_path: Path) -> None:
    snap = {
        "mem_available_mb": 700, "swap_free_mb": 100, "swap_total_mb": 19000,
        "load1": 7.0, "psi_memory": "some avg10=42.00",
        "godot_processes": 1, "godot_rss_mb": 512, "godot_states": "D:1",
    }
    text = readiness_evidence("", snapshot=snap, launch_log=str(tmp_path / "none.log"))
    assert text.startswith("среда в момент отказа:"), "подпись D-265 не должна съезжать"
    assert "godot_procs=1(rss=512MB, state=D:1)" in text
    assert "лог запуска" in text and "не напечатал ни байта" in text

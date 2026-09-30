"""R2 lifecycle tests for McpInteractionServer (world-controller-decoupling, task 2.5).

Launches Godot headless with the project's autoloads and talks to the MCP
server over raw TCP (newline-delimited JSON) — no godot-mcp bridge required.

Covers:
- restart / reconnect: a new client is accepted after the previous one leaves
  (no peer leak, buffer reset, server keeps serving);
- idempotent start(): re-calling start() on a running server is a no-op;
- EADDRINUSE: a second instance on the same port reports a clear error and
  the first instance keeps serving;
- command registration through the dispatcher path: unknown command ->
  "Unknown command" error, known command -> success.

Skipped when no Godot binary is available (set GODOT_PATH or GODOT_BIN).
"""
from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import pytest

GAME_DIR = Path(__file__).resolve().parent.parent.parent
GODOT_BIN = os.environ.get("GODOT_BIN") or os.environ.get(
    "GODOT_PATH", "/Applications/Godot.app/Contents/MacOS/Godot"
)
READY_TIMEOUT = 60.0
RPC_TIMEOUT = 30.0


class MCPTestError(RuntimeError):
    pass


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _wait_port(port: int, timeout: float = READY_TIMEOUT) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(0.5)
            try:
                s.connect(("127.0.0.1", port))
                return
            except OSError:
                time.sleep(0.5)
    raise MCPTestError(f"MCP-сервер не поднялся на порту {port} за {timeout:.0f} с")


def rpc(port: int, payload: dict) -> dict:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(RPC_TIMEOUT)
        s.connect(("127.0.0.1", port))
        s.sendall((json.dumps(payload) + "\n").encode("utf-8"))
        buf = b""
        while not buf.endswith(b"\n"):
            chunk = s.recv(65536)
            if not chunk:
                raise MCPTestError("соединение закрыто до ответа")
            buf += chunk
    return json.loads(buf.decode("utf-8").strip())


@pytest.fixture
def godot_mcp():
    """Running headless Godot with the MCP server on a fresh port."""
    if not Path(GODOT_BIN).exists():
        pytest.skip(f"Godot не найден: {GODOT_BIN} (задайте GODOT_PATH/GODOT_BIN)")
    port = _free_port()
    proc = subprocess.Popen(
        [GODOT_BIN, "--headless", "--path", str(GAME_DIR), "--quit-after", "1800"],
        env={**os.environ, "MCP_PORT": str(port)},
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    try:
        _wait_port(port)
        yield port
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()


@pytest.fixture
def godot_mcp_second(godot_mcp):
    """A second headless Godot instance on the SAME port (EADDRINUSE)."""
    if not Path(GODOT_BIN).exists():
        pytest.skip("Godot не найден")
    port = godot_mcp
    proc = subprocess.Popen(
        [GODOT_BIN, "--headless", "--path", str(GAME_DIR), "--quit-after", "600"],
        env={**os.environ, "MCP_PORT": str(port)},
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    try:
        yield proc, port
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=15)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()


def test_reconnect_after_client_leave(godot_mcp: int) -> None:
    """Повторный старт клиента: после ухода старого peer новый принимается,
    буфер сброшен, сервер продолжает отвечать (без утечки peers)."""
    r1 = rpc(godot_mcp, {"id": 1, "command": "os_info", "params": {}})
    assert "error" not in r1
    assert r1.get("id") == 1

    # Несколько независимых подключений подряд (каждое — новый peer).
    for i in range(3):
        r = rpc(godot_mcp, {"id": i + 10, "command": "os_info", "params": {}})
        assert "error" not in r, r
        assert r.get("id") == i + 10


def test_unknown_command_reports_error(godot_mcp: int) -> None:
    """Регистрация команд через диспетчер: неизвестная команда -> понятная ошибка."""
    r = rpc(godot_mcp, {"id": 1, "command": "definitely_not_a_command", "params": {}})
    assert "Unknown command" in str(r.get("error", ""))
    assert r.get("id") == 1

    # Сервер не «застревает» в busy: следующая команда проходит.
    r2 = rpc(godot_mcp, {"id": 2, "command": "os_info", "params": {}})
    assert "error" not in r2


def test_start_is_idempotent(godot_mcp: int) -> None:
    """start() по уже запущенному серверу — idempotent no-op (true)."""
    r = rpc(
        godot_mcp,
        {
            "id": 1,
            "command": "eval",
            "params": {"code": "var s = get_node('/root/McpInteractionServer')\nreturn s.start()"},
        },
    )
    assert "error" not in r, r
    assert r.get("result") is True
    # Сервер жив и отвечает после повторного start().
    r2 = rpc(godot_mcp, {"id": 2, "command": "os_info", "params": {}})
    assert "error" not in r2


def test_port_in_use_reports_clear_error(godot_mcp_second) -> None:
    """EADDRINUSE: вторая инстанция на занятом порте даёт понятную ошибку,
    первая продолжает обслуживать клиентов."""
    proc, port = godot_mcp_second
    # Ждём, пока вторая инстанция завершится (--quit-after) и выведет ошибку.
    out, _ = proc.communicate(timeout=120)
    assert "EADDRINUSE" in out or "already in use" in out, (
        f"ожидалась понятная ошибка EADDRINUSE в выводе Godot, получили:\n{out[-2000:]}"
    )
    # Первая инстанция не пострадала.
    r = rpc(port, {"id": 1, "command": "os_info", "params": {}})
    assert "error" not in r

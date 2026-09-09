"""Fixtures для MCP-тестов (официальный mcp SDK, stdio-транспорт).

Каждый тест получает собственный godot-mcp сервер + живой Godot (function scope):
это исключает конфликт порта 9090 между тестами — Godot предыдущего теста
гарантированно остановлен до старта следующего (polling в wait_port_free).

Ключевое ограничение anyio: cancel scope stdio_client нельзя входить/выходить
в разных тасках. pytest-asyncio разносит async-fixture setup/teardown по разным
таскам — поэтому весь серверный цикл (enter stdio_client → ClientSession →
initialize → stop → exit) живёт в ОДНОМ таске на отдельном event loop
(anyio BlockingPortal), а тесты синхронные и ходят на этот loop через портал.

Переменные окружения:
  NODE_BIN   — путь к node (по умолчанию "node" из PATH)
  GODOT_PATH — путь к бинарнику Godot (по умолчанию /Applications/Godot.app/...)
"""
from __future__ import annotations

import os
import sys
import threading
from pathlib import Path

import anyio
import pytest
from anyio.from_thread import start_blocking_portal
from mcp import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

MCP_DIR = Path(__file__).parent
GAME_DIR = MCP_DIR.parent.parent  # <repo>/game
GODOT_MCP_DIR = GAME_DIR / "addons" / "godot-mcp"

sys.path.insert(0, str(MCP_DIR))
from godot_mcp import GodotMCPClient, MCPError  # noqa: E402  локальный модуль

NODE_BIN = os.environ.get("NODE_BIN", "node")
GODOT_BIN = os.environ.get("GODOT_PATH", "/Applications/Godot.app/Contents/MacOS/Godot")

WORLD_SCENE = "res://scenes/World.tscn"
BATTLE_SCENE = "res://scenes/Battle.tscn"

PROJECT_GODOT = GAME_DIR / "project.godot"

# stdio SDK наследует только минимальное окружение (HOME/PATH/...),
# поэтому GODOT_PATH для сервера передаём явно.
SERVER_ENV = {"GODOT_PATH": GODOT_BIN}

# Страховка от нечистого выхода node (SIGKILL-путь SDK-шатдауна): содержимое
# project.godot на момент запуска тестов.
_PRISTINE_PROJECT_GODOT = PROJECT_GODOT.read_text()


def _restore_project_godot_if_dirty() -> None:
    try:
        if PROJECT_GODOT.read_text() != _PRISTINE_PROJECT_GODOT:
            PROJECT_GODOT.write_text(_PRISTINE_PROJECT_GODOT)
            print("[mcp] project.godot восстановлен (node ушёл без rollback)", file=sys.stderr)
    except OSError as e:
        print(f"[mcp] не удалось проверить project.godot: {e}", file=sys.stderr)


def _server_params() -> StdioServerParameters:
    return StdioServerParameters(
        command=NODE_BIN,
        args=[str(GODOT_MCP_DIR / "build" / "index.js")],
        cwd=str(GAME_DIR),
        env=SERVER_ENV,
    )


@pytest.fixture
def mcp():
    """Живой godot-mcp сервер (stdio) + готовый ClientSession.

    Цикл сервера — один таск на loop портала (enter/exit stdio_client вместе).
    Завершение: сигнал stop → stop Godot + восстановление project.godot → выход таска.
    """
    box: dict = {}
    ready = threading.Event()
    done = threading.Event()

    async def main() -> None:
        try:
            async with stdio_client(_server_params()) as (read, write):
                async with ClientSession(read, write) as session:
                    await session.initialize()
                    box["client"] = GodotMCPClient(portal, session, str(GAME_DIR))
                    stop_evt = anyio.Event()
                    box["stop"] = stop_evt
                    ready.set()
                    await stop_evt.wait()
                    await box["client"]._stop_on_loop(120.0)
        except BaseException as e:  # noqa: BLE001 — доставить в тест
            box["error"] = e
            ready.set()
        finally:
            _restore_project_godot_if_dirty()
            done.set()

    with start_blocking_portal() as portal:
        box["portal"] = portal
        portal.start_task_soon(main)
        if not ready.wait(90):
            raise MCPError("godot-mcp сервер не стартовал за 90 с")
        if "error" in box:
            raise box["error"]
        yield box["client"]
        portal.call(box["stop"].set)
        if not done.wait(180):
            print("[mcp] WARNING: очистка сервера не завершилась за 180 с", file=sys.stderr)


@pytest.fixture
def battle_scene(mcp):
    """МCP-клиент с уже запущенной сценой боя (res://scenes/Battle.tscn)."""
    mcp.run_scene(BATTLE_SCENE)
    mcp.wait_ready()
    yield mcp


@pytest.fixture
def world_scene(mcp):
    """МCP-клиент с уже запущенным миром (res://scenes/World.tscn)."""
    mcp.run_scene(WORLD_SCENE)
    mcp.wait_ready()
    yield mcp

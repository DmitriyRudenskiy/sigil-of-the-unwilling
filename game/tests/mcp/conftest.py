"""Фикстуры для MCP-тестов (tugcantopaloglu/godot-mcp)."""
from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path

import pytest
import pytest_asyncio

sys.path.insert(0, str(Path(__file__).parent.parent))
from helpers.mcp_client import GodotMCPClient


# mcp-клиент function-scoped, а не session: stdio-транспорт anyio
# требует, чтобы cancel scope заходил/выходил в одной task; session-фикстура +
# function-тесты живут в разных task и вешают teardown (проверено empirически).

SERVER_JS = os.environ.get(
    "GODOT_MCP_SERVER",
    "/Users/user/sigil-of-the-unwilling/godot-mcp/build/index.js",
)
PROJECT_PATH = os.environ.get(
    "GODOT_PROJECT_PATH",
    "/Users/user/sigil-of-the-unwilling/game",
)


async def _wait_port_free(port: int = 9090, timeout: float = 30.0) -> None:
    """Ждать освобождения порта interaction server."""
    loop = asyncio.get_running_loop()
    deadline = loop.time() + timeout
    while loop.time() < deadline:
        try:
            _, writer = await asyncio.open_connection("127.0.0.1", port)
            writer.close()
            try:
                await writer.wait_closed()
            except OSError:
                pass
        except (ConnectionRefusedError, OSError):
            return
        await asyncio.sleep(0.2)
    raise TimeoutError(f"port {port} still in use after {timeout}s")


@pytest_asyncio.fixture
async def mcp() -> GodotMCPClient:
    """Подключение к tugcantopaloglu/godot-mcp на время теста."""
    client = GodotMCPClient(
        server_command="node",
        server_args=[SERVER_JS],
    )
    await client.connect()
    yield client
    await client.disconnect()


@pytest_asyncio.fixture
async def battle_scene(mcp: GodotMCPClient):
    """Запуск сцены боя через godot-mcp."""
    await _wait_port_free()
    await mcp.run_scene("res://scenes/Battle.tscn")
    await asyncio.sleep(10)
    await mcp.wait_ready(60)
    await mcp.wait_frames(30)
    yield mcp
    await mcp.stop_running_scene()
    await _wait_port_free()


@pytest_asyncio.fixture
async def world_scene(mcp: GodotMCPClient):
    """Запуск мировой сцены через godot-mcp."""
    await _wait_port_free()
    await mcp.run_scene("res://scenes/World.tscn")
    await asyncio.sleep(10)
    await mcp.wait_ready(60)
    await mcp.wait_frames(60)
    yield mcp
    await mcp.stop_running_scene()
    await _wait_port_free()

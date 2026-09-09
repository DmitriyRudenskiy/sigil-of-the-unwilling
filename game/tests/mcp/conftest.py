from __future__ import annotations

import os
import sys
import threading
import time
from pathlib import Path

import anyio
import pytest
from anyio.from_thread import start_blocking_portal
from mcp import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

MCP_DIR = Path(__file__).parent
GAME_DIR = MCP_DIR.parent.parent
GODOT_MCP_DIR = GAME_DIR / "addons" / "godot-mcp"

sys.path.insert(0, str(MCP_DIR))
from godot_mcp import GodotMCPClient, MCPError

NODE_BIN = os.environ.get("NODE_BIN", "node")
GODOT_BIN = os.environ.get("GODOT_PATH", "/Applications/Godot.app/Contents/MacOS/Godot")

WORLD_SCENE = "res://scenes/World.tscn"
BATTLE_SCENE = "res://scenes/Battle.tscn"

PROJECT_GODOT = GAME_DIR / "project.godot"

SERVER_ENV = {"GODOT_PATH": GODOT_BIN}

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
        except BaseException as e:
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
    mcp.run_scene(BATTLE_SCENE)
    mcp.wait_ready()
    yield mcp

@pytest.fixture
def world_scene(mcp):
    mcp.run_scene(WORLD_SCENE)
    mcp.wait_ready()
    yield mcp

@pytest.fixture
def full_game(mcp):
    """World + завершённый ботст랩 (hero и map_gen готовы)."""
    mcp.run_scene(WORLD_SCENE)
    mcp.wait_ready()
    deadline = time.time() + 120
    while time.time() < deadline:
        r = mcp.execute_code(
            "var w = get_tree().current_scene\n"
            "return {\"hero\": w != null and w.get_hero() != null, "
            "\"map\": w != null and w.get_map_gen() != null}"
        )
        if r.get("hero") and r.get("map"):
            break
        time.sleep(1.0)
    else:
        raise MCPError("World не завершил ботст랩 за 120 с")
    yield mcp

from __future__ import annotations

import json
import socket
import time
from typing import Any

import inspect
from datetime import timedelta

import anyio
from mcp import ClientSession
try:
    from mcp.shared.exceptions import MCPError as _SdkMCPError
except ImportError:  #新版 mcp SDK: McpError
    from mcp.shared.exceptions import McpError as _SdkMCPError

MCP_INTERACTION_PORT = 9090
DEFAULT_TIMEOUT = 120.0
READY_TIMEOUT = 900.0
PORT_FREE_TIMEOUT = 60.0

class MCPError(RuntimeError):
    pass

# Новый mcp SDK ожидает timedelta в read_timeout_seconds, старый — float.
try:
    _SDK_WANTS_TIMEDI = "timedelta" in str(inspect.signature(ClientSession.call_tool))
except Exception:
    _SDK_WANTS_TIMEDI = False

def _timeout_for(seconds: float) -> Any:
    return timedelta(seconds=seconds) if _SDK_WANTS_TIMEDI else seconds

async def wait_port_free(
    port: int = MCP_INTERACTION_PORT,
    timeout: float = PORT_FREE_TIMEOUT,
    interval: float = 0.25,
) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(0.25)
            try:
                s.connect(("127.0.0.1", port))
            except (ConnectionRefusedError, socket.timeout, OSError):
                return
        await anyio.sleep(interval)
    raise MCPError(
        f"порт {port} занят {timeout:.0f} с — предыдущий Godot/godot-mcp не остановился"
    )

class GodotMCPClient:

    def __init__(self, portal, session: ClientSession, project_path: str) -> None:
        self._portal = portal
        self._session = session
        self._project_path = project_path
        self._running = False

    def execute_code(self, code: str, timeout: float = DEFAULT_TIMEOUT) -> Any:
        data = self._portal.call(self._execute_code, code, timeout)
        if isinstance(data, dict):
            return data.get("result")
        return data

    def wait_frames(
        self, frames: int = 1, frame_type: str = "render", timeout: float = DEFAULT_TIMEOUT
    ) -> None:
        self._portal.call(self._wait_frames, frames, frame_type, timeout)

    def run_scene(self, scene_path: str, timeout: float = 300.0) -> None:
        self._portal.call(self._run_scene, scene_path, timeout)

    def stop_running_scene(self, timeout: float = DEFAULT_TIMEOUT) -> None:
        self._portal.call(self._stop_on_loop, timeout)

    async def _stop_on_loop(self, timeout: float) -> None:
        if not self._running:
            return
        self._running = False
        try:
            await self._call("stop_project", {}, timeout)
        except MCPError as e:
            print(f"[mcp] stop_project: {e}", flush=True)
        await wait_port_free()

    async def _execute_code(self, code: str, timeout: float) -> Any:
        return await self._call("game_eval", {"code": code}, timeout)

    async def _wait_frames(self, frames: int, frame_type: str, timeout: float) -> None:
        await self._call("game_wait", {"frames": frames, "frameType": frame_type}, timeout)

    async def _run_scene(self, scene_path: str, timeout: float) -> None:
        await wait_port_free()
        await self._call(
            "run_project",
            {"projectPath": self._project_path, "scene": scene_path},
            timeout,
        )
        self._running = True

    def wait_ready(
        self, timeout: float = READY_TIMEOUT, interval: float = 0.5
    ) -> None:
        deadline = time.monotonic() + timeout
        last = ""
        while time.monotonic() < deadline:
            try:

                if self.execute_code("return GameEventBus != null", timeout=60.0) is True:
                    return
            except (MCPError, _SdkMCPError) as e:
                last = str(e)
            time.sleep(interval)
        raise MCPError(f"игра не готова за {timeout:.0f} с (последняя ошибка: {last})")

    async def _call(self, name: str, args: dict, timeout: float) -> Any:
        try:
            result = await self._session.call_tool(name, args, read_timeout_seconds=_timeout_for(timeout))
        except _SdkMCPError as e:

            if "timed out" not in str(e):
                raise
            result = await self._session.call_tool(name, args, read_timeout_seconds=_timeout_for(timeout))
        if _is_error(result):
            raise MCPError(f"тулз {name} вернул ошибку: {_first_text(result)}")
        text = _first_text(result)
        try:
            data: Any = json.loads(text)
        except (TypeError, json.JSONDecodeError):
            return text
        if isinstance(data, dict) and data.get("error"):
            raise MCPError(f"тулз {name}: {data['error']}")
        return data

def _is_error(result) -> bool:
    for attr in ("is_error", "isError"):
        try:
            return bool(getattr(result, attr))
        except AttributeError:
            continue
    return False

def _first_text(result) -> str:
    for block in result.content:
        if getattr(block, "type", None) == "text":
            return block.text
    return ""

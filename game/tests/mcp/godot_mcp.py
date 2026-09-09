"""Клиент godot-mcp поверх официального mcp SDK (stdio-транспорт).

Заменяет hand-rolled JSON-RPC из tests/helpers/mcp_client.py (удалён).
Имена тулзов — вендоренного сервера addons/godot-mcp v3.1.0 (build/index.js):
run_project(projectPath, scene) / stop_project() / game_eval(code) / game_wait(frames).

Лайфсайд stdio_client/ClientSession живёт в ОДНОМ таске на отдельном event loop
(anyio BlockingPortal из conftest) — anyio cancel scope нельзя входить и выходить
в разных тасках (pytest-asyncio разносит fixture setup/teardown по таскам).
Публичный API клиента синхронный: каждый вызов хоппит на loop портала.

Семантика shutdown (проверено по src/index.ts):
- stop_project() убивает Godot и синхронно снимает инжект autoload из project.godot;
- сам node-процесс завершается по EOF stdin (SDK: close stdin → 2s → SIGTERM → SIGKILL,
  с убийством process tree — включая Godot);
- порт 9090 (interaction-сервер) захардкожен в вендоренном сервере, поэтому перед
  запуском и после остановки сцены poll-им, что порт свободен.
"""
from __future__ import annotations

import json
import socket
import time
from typing import Any

import anyio
from mcp import ClientSession
from mcp.shared.exceptions import MCPError as _SdkMCPError

MCP_INTERACTION_PORT = 9090  # INTERACTION_PORT в addons/godot-mcp/src/index.ts
DEFAULT_TIMEOUT = 120.0
READY_TIMEOUT = 300.0
PORT_FREE_TIMEOUT = 60.0


class MCPError(RuntimeError):
    """Ошибка MCP-тулза или транспорта."""


async def wait_port_free(
    port: int = MCP_INTERACTION_PORT,
    timeout: float = PORT_FREE_TIMEOUT,
    interval: float = 0.25,
) -> None:
    """Ждём, пока порт interaction-сервера освободится (polling, не sleep)."""
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
    """Синхронная обёртка над ClientSession godot-mcp v3.1.0 (вызовы через портал)."""

    def __init__(self, portal, session: ClientSession, project_path: str) -> None:
        self._portal = portal
        self._session = session
        self._project_path = project_path
        self._running = False

    # --- синхронный публичный API (вызывается из тестов) ---

    def execute_code(self, code: str, timeout: float = DEFAULT_TIMEOUT) -> Any:
        """Выполнить GDScript в живой игре (game_eval). Возвращает "result"."""
        data = self._portal.call(self._execute_code, code, timeout)
        if isinstance(data, dict):
            return data.get("result")
        return data

    def wait_frames(
        self, frames: int = 1, frame_type: str = "render", timeout: float = DEFAULT_TIMEOUT
    ) -> None:
        self._portal.call(self._wait_frames, frames, frame_type, timeout)

    def run_scene(self, scene_path: str, timeout: float = 300.0) -> None:
        """Запустить проект с указанной сценой. scene — res://-путь."""
        self._portal.call(self._run_scene, scene_path, timeout)

    def stop_running_scene(self, timeout: float = DEFAULT_TIMEOUT) -> None:
        """Остановить Godot и дождаться освобождения порта 9090 (из тестового потока)."""
        self._portal.call(self._stop_on_loop, timeout)

    # --- async-реализация stop (выполняется НА loop портала, без portal.call) ---

    async def _stop_on_loop(self, timeout: float) -> None:
        if not self._running:
            return
        self._running = False
        try:
            await self._call("stop_project", {}, timeout)
        except MCPError as e:
            print(f"[mcp] stop_project: {e}", flush=True)
        await wait_port_free()

    # --- async-реализация (выполняется на loop портала) ---

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
        """Поллинг готовности вместо фиксированного sleep: autoload должен жить в дереве."""
        deadline = time.monotonic() + timeout
        last = ""
        while time.monotonic() < deadline:
            try:
                # 60с > внутренний 30с-timeout сервера: получаем чистый вердикт
                # сервера, а не SDK-таймаут посреди его eval.
                if self.execute_code("return GameEventBus != null", timeout=60.0) is True:
                    return
            except (MCPError, _SdkMCPError) as e:
                last = str(e)
            time.sleep(interval)
        raise MCPError(f"игра не готова за {timeout:.0f} с (последняя ошибка: {last})")

    async def _call(self, name: str, args: dict, timeout: float) -> Any:
        try:
            result = await self._session.call_tool(name, args, read_timeout_seconds=timeout)
        except _SdkMCPError as e:
            # MCP/Godot изредка зависает на game_eval (транзиентно, разные тесты).
            # Один повтор перед тем как считать провалом.
            if "timed out" not in str(e):
                raise
            result = await self._session.call_tool(name, args, read_timeout_seconds=timeout)
        if result.is_error:
            raise MCPError(f"тулз {name} вернул ошибку: {_first_text(result)}")
        text = _first_text(result)
        try:
            data: Any = json.loads(text)
        except (TypeError, json.JSONDecodeError):
            return text
        if isinstance(data, dict) and data.get("error"):
            raise MCPError(f"тулз {name}: {data['error']}")
        return data


def _first_text(result) -> str:
    for block in result.content:
        if getattr(block, "type", None) == "text":
            return block.text
    return ""

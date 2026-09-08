"""
Обёртка над tugcantopaloglu/godot-mcp.
Подключается к MCP-серверу, который, в свою очередь,
управляет Godot через встроенный плагин.
"""
from __future__ import annotations

import asyncio
import json
import os
from dataclasses import dataclass, field
from typing import Any

# Путь к Godot-проекту для run_project (переопределяется GODOT_PROJECT_PATH).
PROJECT_PATH = os.environ.get("GODOT_PROJECT_PATH", "/Users/user/sigil-of-the-unwilling/game")

# транспорт на чистом asyncio (JSON-RPC по строкам), без mcp SDK:
# stdio_client (anyio task group) требует вход/выход cancel scope в одной task,
# а pytest-фикстуры живут в разных — вешал teardown (проверено empirически).


@dataclass
class GodotMCPClient:
    """Асинхронный клиент для tugcantopaloglu/godot-mcp (stdio JSON-RPC)."""

    server_command: str = "node"
    server_args: list[str] = field(default_factory=list)
    _proc: Any = field(default=None, repr=False, init=False)
    _pending: dict = field(default_factory=dict, repr=False, init=False)
    _next_id: int = field(default=0, repr=False, init=False)
    _reader: Any = field(default=None, repr=False, init=False)

    async def connect(self) -> None:
        # limit: ответ stop_project несёт весь stdout/stderr Godot одной строкой;
        # дефолтный лимит StreamReader (64KB) роняет read_loop с LimitOverrunError.
        self._proc = await asyncio.create_subprocess_exec(
            self.server_command,
            *self.server_args,
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            limit=16 * 1024 * 1024,
            stderr=asyncio.subprocess.DEVNULL,
        )
        self._reader = asyncio.create_task(self._read_loop())
        await self._rpc("initialize", {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "gdunit-mcp-tests", "version": "1.0"},
        })
        await self._notify("notifications/initialized", {})

    async def disconnect(self) -> None:
        if self._reader:
            self._reader.cancel()
            try:
                await self._reader
            except (asyncio.CancelledError, Exception):
                pass
        if self._proc and self._proc.returncode is None:
            # SIGTERM: у ноды есть exit-handler, который откатывает inject interaction
            # server'а в project.godot. SIGKILL оставил бы проект испорченным.
            self._proc.terminate()
            try:
                await asyncio.wait_for(self._proc.wait(), 5.0)
            except asyncio.TimeoutError:
                self._proc.kill()
                await self._proc.wait()

    async def _read_loop(self) -> None:
        assert self._proc is not None
        while True:
            line = await self._proc.stdout.readline()
            if not line:
                break
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue
            rid = msg.get("id")
            fut = self._pending.pop(rid, None) if rid is not None else None
            if fut is not None and not fut.done():
                fut.set_result(msg)

    async def _notify(self, method: str, params: dict) -> None:
        assert self._proc is not None
        data = json.dumps({"jsonrpc": "2.0", "method": method, "params": params}) + "\n"
        self._proc.stdin.write(data.encode())
        await self._proc.stdin.drain()

    async def _rpc(self, method: str, params: dict, timeout: float = 120.0) -> Any:
        assert self._proc is not None, "Not connected"
        self._next_id += 1
        rid = self._next_id
        fut: asyncio.Future = asyncio.get_running_loop().create_future()
        self._pending[rid] = fut
        data = json.dumps({"jsonrpc": "2.0", "id": rid, "method": method, "params": params}) + "\n"
        self._proc.stdin.write(data.encode())
        await self._proc.stdin.drain()
        try:
            msg = await asyncio.wait_for(fut, timeout)
        except asyncio.TimeoutError:
            self._pending.pop(rid, None)
            raise TimeoutError(f"MCP request '{method}' timed out after {timeout}s")
        if "error" in msg:
            raise RuntimeError(f"MCP {method} error: {msg['error']}")
        return msg.get("result")

    async def _call_tool(self, name: str, arguments: dict) -> Any:
        result = await self._rpc("tools/call", {"name": name, "arguments": arguments})
        if isinstance(result, dict) and result.get("isError"):
            text = result.get("content", [{}])[0].get("text", str(result))
            raise RuntimeError(f"MCP tool {name} failed: {text}")
        return result

    async def wait_ready(self, timeout: float = 60.0) -> None:
        """Ждать, пока interaction server в игре начнёт отвечать (game_eval)."""
        loop = asyncio.get_running_loop()
        deadline = loop.time() + timeout
        while loop.time() < deadline:
            try:
                await self.execute_code("return 1")
                return
            except (RuntimeError, TimeoutError):
                await asyncio.sleep(1.0)
        raise TimeoutError("Game interaction server did not become ready in time")

    @staticmethod
    def _tool_text(result: Any) -> str:
        return result["content"][0]["text"]

    # ─── Высокоуровневые методы ───────────────────────────────────────

    async def get_scene_tree(self) -> dict:
        """Получить дерево сцены запущенного проекта."""
        r = await self._call_tool("game_get_scene_tree", {})
        return json.loads(self._tool_text(r))

    async def get_node_property(self, path: str, prop: str) -> Any:
        r = await self._call_tool("game_get_property", {"nodePath": path, "property": prop})
        return json.loads(self._tool_text(r))

    async def set_node_property(self, path: str, prop: str, value: Any) -> None:
        await self._call_tool(
            "game_set_property",
            {"nodePath": path, "property": prop, "value": value},
        )

    async def call_method(self, path: str, method: str, args: list | None = None) -> Any:
        r = await self._call_tool(
            "game_call_method",
            {"nodePath": path, "method": method, "args": args or []},
        )
        return json.loads(self._tool_text(r))

    async def find_nodes_by_type(self, node_type: str) -> list[str]:
        r = await self._call_tool("game_find_nodes_by_class", {"className": node_type})
        return json.loads(self._tool_text(r))

    async def run_scene(self, scene_path: str) -> None:
        await self._call_tool("run_project", {"projectPath": PROJECT_PATH, "scene": scene_path})

    async def stop_running_scene(self) -> None:
        await self._call_tool("stop_project", {})

    async def wait_frames(self, frames: int = 10) -> None:
        """Подождать N кадров (эмуляция ожидания)."""
        await asyncio.sleep(frames / 60.0)

    async def execute_code(self, code: str) -> Any:
        """Выполнить произвольный GDScript-код в контексте сцены.

        Возвращает внутреннее `result` из ответа сервера
        (конверт {"id", "result", "success"} разворачивается здесь).
        """
        r = await self._call_tool("game_eval", {"code": code})
        data = json.loads(self._tool_text(r))
        if isinstance(data, dict) and "success" in data and "result" in data:
            return data["result"]
        return data

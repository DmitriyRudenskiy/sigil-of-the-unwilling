from __future__ import annotations

import base64
import json
import os
import socket
import time
from pathlib import Path
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
# CI-4 (2026-10-13): readiness != время теста. Здоровый старт Godot ~10 c (замер:
# 4 теста за 9.7 c); зависший старт при 900 c съедал весь бюджет (setup-таймаут
# 900 c, инцидент раунда 9) и 3 ретрая CI-2. Потолок готовности — 180 c.
# ci-speedup (2026-10-14): MCP_READY_TIMEOUT_S — маржа под contention N воркеров
# (2 Godot на 4-ядерном раннере: старт >180 с, ран 38502715080). Локальный
# дефолт 180 с — не меняется.
READY_TIMEOUT = float(os.environ.get("MCP_READY_TIMEOUT_S", "180"))
PORT_FREE_TIMEOUT = 60.0

class MCPError(RuntimeError):
    pass


# --- T-172: отказ readiness обязан называть причину, а не только дедлайн -------
# До правки жертва прогона выглядела одинаково при трёх разных бедах: Godot не
# стартовал, Godot стартовал медленно (машина в global OOM), и `listen()`
# однажды отказал. Всё, что видел отчёт, — «игра не готова за 180 с».
# Теперь к тексту отказа прилагается снимок среды и boot-трейс самой игры
# (пишет tools/mcp/mcp_interaction_server.gd, env MCP_BOOT_TRACE).

MEMINFO_PATH = "/proc/meminfo"
LOADAVG_PATH = "/proc/loadavg"
PSI_MEMORY_PATH = "/proc/pressure/memory"


def _mb(value: Any) -> str:
    """Мегабайты в отчёте: «не прочитано» и «ноль» — разные новости, `NoneMB` — ни одна."""
    return f"{value}MB" if value is not None else "не прочитано"


def _kb_to_mb(mem: dict[str, int], key: str) -> int | None:
    """КиБ → МБ без подмены «ноль» в «нет данных».

    Прежний `round(kb / 1024) or None` сливал 0 КиБ и отсутствующий ключ в один
    `None`, а отчёт печатал «не прочитано». Первый же прогон канала на машине с
    `swap_free=403/20479MB` дал ровно эту строку на том самом номере, который и
    решал гипотезу о нехватке памяти (T-172): «памяти ноль» — подозреваемый,
    «памяти не видно» — слепое пятно канала.
    """
    kb = mem.get(key)
    return None if kb is None else round(kb / 1024)


def _read_text(path: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def read_meminfo_kb(path: str = MEMINFO_PATH) -> dict[str, int]:
    """/proc/meminfo → {ключ: КиБ}; пустой словарь там, где /proc нет (macOS)."""
    out: dict[str, int] = {}
    for line in _read_text(path).splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[1].isdigit():
            out[fields[0].rstrip(":")] = int(fields[1])
    return out


def read_loadavg(path: str = LOADAVG_PATH) -> float | None:
    fields = _read_text(path).split()
    if not fields:
        return None
    try:
        return float(fields[0])
    except ValueError:
        return None


def read_psi_some(path: str = PSI_MEMORY_PATH) -> str:
    """Первая строка PSI-памяти (`some avg10=…`); пусто, если ядро без PSI."""
    for line in _read_text(path).splitlines():
        if line.startswith("some"):
            return line.strip()
    return ""


def godot_processes(proc_root: str = "/proc", needle: str = "godot") -> list[dict[str, Any]]:
    """Живые процессы движка: имя исполняемого файла, RSS, состояние.

    Ищется по имени бинаря (`/proc/<pid>/exe`, в край — argv[0]), а не по подстроке
    всей командной строки: подстрока «godot» ловит и сам pytest
    (`.venv/godot-mcp-tests/…`), и node-сервер (`godot-mcp/build/index.js`), и этот
    самый модуль — первая версия счётчика докладывала `godot_procs=3` там, где был
    один Godot. Состояние и RSS — потому что «три Godot» и «один Godot в D на
    подкачке» объясняют медленный старт по-разному.
    """
    out: list[dict[str, Any]] = []
    try:
        entries = os.listdir(proc_root)
    except OSError:
        return out
    for pid in entries:
        if not pid.isdigit():
            continue
        name = _proc_exe_name(proc_root, pid)
        if not name.startswith(needle):
            continue
        status = _read_text(f"{proc_root}/{pid}/status")
        rss_kb = 0
        state = "?"
        for line in status.splitlines():
            if line.startswith("VmRSS:"):
                fields = line.split()
                if len(fields) > 1 and fields[1].isdigit():
                    rss_kb = int(fields[1])
            elif line.startswith("State:"):
                rest = line.split()[1:]
                state = rest[0] if rest else "?"
        out.append({"pid": int(pid), "exe": name, "rss_mb": round(rss_kb / 1024),
                    "state": state, **_proc_blockage(proc_root, pid)})
    return out


def _proc_blockage(proc_root: str, pid: str) -> dict[str, Any]:
    """Где именно стоит процесс: точка блокировки в ядре, номер syscall, число fd.

    Два замера отказа readiness (2026-10-28) сошлись на одном хвосте лога при
    разной памяти (MemAvailable 23 MB и 1189 MB) и при процессе в состоянии `S`
    с RSS ~170 MB: движок не крутил CPU и не тонул в подкачке — он ждал. Чем?
    `wchan`+`syscall` отвечают: `0`/read — сокет X11, `202`/futex — внутреннее
    ожидание, `7`/poll и `43`/accept — собственное listen(), т.е. игра уже
    готова и виноват не старт (x86-64).
    """
    wchan = _read_text(f"{proc_root}/{pid}/wchan").strip().strip("\x00") or "?"
    fields = _read_text(f"{proc_root}/{pid}/syscall").split()
    syscall = fields[0] if fields else "?"
    try:
        fds = len(os.listdir(f"{proc_root}/{pid}/fd"))
    except OSError:
        fds = -1
    return {"wchan": wchan, "syscall": syscall, "fds": fds}


def _proc_exe_name(proc_root: str, pid: str) -> str:
    try:
        return Path(os.readlink(f"{proc_root}/{pid}/exe")).name
    except OSError:
        argv0 = _read_text(f"{proc_root}/{pid}/cmdline").split("\0")[0]
        return Path(argv0).name if argv0 else ""


def env_snapshot(
    meminfo_path: str = MEMINFO_PATH,
    loadavg_path: str = LOADAVG_PATH,
    psi_path: str = PSI_MEMORY_PATH,
    proc_root: str = "/proc",
) -> dict[str, Any]:
    """Снимок того, что окружение могло отнять у старта Godot (T-172)."""
    mem = read_meminfo_kb(meminfo_path)
    procs = godot_processes(proc_root)
    states: dict[str, int] = {}
    for p in procs:
        states[p["state"]] = states.get(p["state"], 0) + 1
    return {
        "mem_total_mb": _kb_to_mb(mem, "MemTotal"),
        "mem_available_mb": _kb_to_mb(mem, "MemAvailable"),
        "swap_free_mb": _kb_to_mb(mem, "SwapFree"),
        "swap_total_mb": _kb_to_mb(mem, "SwapTotal"),
        "load1": read_loadavg(loadavg_path),
        "psi_memory": read_psi_some(psi_path) or None,
        "godot_processes": len(procs),
        "godot_rss_mb": sum(p["rss_mb"] for p in procs),
        "godot_states": ",".join(f"{k}:{v}" for k, v in sorted(states.items())) or None,
        "godot_blockage": "; ".join(
            f"pid={p['pid']} {p['state']} wchan={p['wchan']} syscall={p['syscall']} fd={p['fds']}"
            for p in procs) or None,
    }


def boot_trace_tail(trace_path: str, lines: int = 8) -> str:
    """Хвост boot-трейса игры; отдельный текст, если файла нет или он пуст."""
    if not trace_path:
        return "трейс не запрошен (MCP_BOOT_TRACE не задан)"
    text = _read_text(trace_path)
    if not text.strip():
        return (
            f"файл трейса {trace_path} пуст или не создан — Godot не дошёл до "
            "автозагрузки McpInteractionServer (не стартовал/умер на старте)"
        )
    body = text.strip().splitlines()[-lines:]
    return f"{len(body)} строк из {trace_path}:\n    " + "\n    ".join(body)


def launch_log_tail(log_path: str, lines: int = 12) -> str:
    """Хвост лога запуска Godot — того, что движок напечатал до отказа.

    Boot-трейс отвечает «дошла ли игра до автозагрузки»; на «почему нет» он нем,
    потому что до автозагрузки игра — только движок. Его слова (баннер, `-d`
    подробный лог, внятный краш) видны лишь извне — см. `godot_launcher.sh`.
    """
    if not log_path:
        return "лог запуска не собирался (MCP_GODOT_LOG не задан)"
    text = _read_text(log_path)
    if not text.strip():
        return (
            f"лог запуска {log_path} пуст — Godot не напечатал ни байта "
            "(spawn не состоялся или процесс умер до первой строки)"
        )
    body = [l for l in text.strip().splitlines() if l.strip()][-lines:]
    return f"{len(body)} строк из {log_path}:\n    " + "\n    ".join(body)


def probe_listen(port: int | None, host: str = "127.0.0.1", timeout: float = 1.0) -> str:
    """Слушается ли порт и принимает ли игра соединение — различие, которого не хватало.

    Три жертвы гейта 2026-10-28 дали boot-трейс `listen attempt=1 … err=0`: игра
    **забиндилась**, но узел-сервер так и не получил соединения. Разница между
    «порта нет» и «порт есть, а accept не случился» — это разница между «среда»
    и «главный цикл игры не крутится», т.е. между жёлтым и красным вердиктом.
    TCP-хендшейк доигрывает ядро (backlog), поэтому connect проходит и при
    висящем цикле — отсюда честная формулировка «ядро приняло, игра — нет».
    """
    if not port:
        return "не проверялся (порт не задан)"
    try:
        with socket.create_connection((host, int(port)), timeout=timeout):
            return (
                f"{host}:{port} — ядро приняло соединение, игра его не забрала "
                "(главный цикл не крутится: accept вызывается из _process)"
            )
    except ConnectionRefusedError:
        return f"{host}:{port} — порта нет (bind не случился)"
    except OSError as exc:
        return f"{host}:{port} — не проверено ({exc})"


def readiness_evidence(
    trace_path: str = "",
    snapshot: dict[str, Any] | None = None,
    launch_log: str = "",
    port: int | None = None,
) -> str:
    """Текст к исключению readiness: среда + шаги игры + лог движка."""
    snap = env_snapshot() if snapshot is None else snapshot
    return (
        "среда в момент отказа: "
        f"mem_available={_mb(snap['mem_available_mb'])} из "
        f"{_mb(snap.get('mem_total_mb'))} "
        f"swap_free={snap['swap_free_mb']}/{snap['swap_total_mb']}MB "
        f"load1={snap['load1']} godot_procs={snap['godot_processes']}"
        f"(rss={snap['godot_rss_mb']}MB, state={snap['godot_states']}) "
        f"psi_memory={snap['psi_memory']}\n"
        f"  где стоит движок: {snap.get('godot_blockage') or 'ни одного Godot-процесса (или /proc недоступен)'}\n"
        f"  порт: {probe_listen(port)}\n"
        f"  boot-трейс: {boot_trace_tail(trace_path)}"
        f"\n  лог запуска: {launch_log_tail(launch_log)}"
    )

# Новый mcp SDK ожидает timedelta в read_timeout_seconds, старый — float.
try:
    _SDK_WANTS_TIMEDI = "timedelta" in str(inspect.signature(ClientSession.call_tool))
except Exception:
    _SDK_WANTS_TIMEDI = False

def _timeout_for(seconds: float) -> Any:
    return timedelta(seconds=seconds) if _SDK_WANTS_TIMEDI else seconds

def _port_free(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.25)
        try:
            s.connect(("127.0.0.1", port))
        except (ConnectionRefusedError, socket.timeout, OSError):
            return True
    return False


async def wait_port_free(
    port: int = MCP_INTERACTION_PORT,
    timeout: float = PORT_FREE_TIMEOUT,
    interval: float = 0.25,
    immediate: bool = False,
) -> None:
    """Ожидание освобождения MCP-порта.

    immediate=True (setup, перед run_project): порт обязан быть свободен;
    занятость = сиротский godot/node из убитого прогона → немедленный
    диагностический fail, не молчаливая блокировка (CI-1-семья, владелец
    2026-10-05 §1.1, T-120: ~120 c/тест на сиротском порту 9090).
    """
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if _port_free(port):
            return
        if immediate:
            raise MCPError(
                f"порт {port} занят до run_project — сиротский godot/godot-mcp "
                "из убитого прогона (CI-1-семья, T-120). Чистка: "
                "pkill -f 'build/index.js'; pkill -f -- '--path <каталог проекта>'"
            )
        await anyio.sleep(interval)
    raise MCPError(
        f"порт {port} не освободился за {timeout:.0f} с — предыдущий Godot/godot-mcp не остановился"
    )

class GodotMCPClient:

    def __init__(self, portal, session: ClientSession, project_path: str,
                 port: int = MCP_INTERACTION_PORT,
                 boot_trace: str = "", launch_log: str = "") -> None:
        self._portal = portal
        self._session = session
        self._project_path = project_path
        self._port = port  # ci-speedup: порт воркера (gwN → 9090+N)
        # T-172: путь boot-трейса этого Godot (env MCP_BOOT_TRACE тем же значением)
        # и путь лога запуска того же движка (env MCP_GODOT_LOG, см. godot_launcher.sh).
        self.boot_trace = boot_trace
        self.launch_log = launch_log
        self._running = False

    def execute_code(self, code: str, timeout: float = DEFAULT_TIMEOUT) -> Any:
        data = self._portal.call(self._execute_code, code, timeout)
        if isinstance(data, dict):
            return data.get("result")
        return data

    def instantiate_scene(self, scene_path: str, parent_path: str = "/root",
                          timeout: float = DEFAULT_TIMEOUT) -> Any:
        return self._portal.call(
            self._call, "game_instantiate_scene",
            {"scenePath": scene_path, "parentPath": parent_path}, timeout,
        )

    def wait_frames(
        self, frames: int = 1, frame_type: str = "render", timeout: float = DEFAULT_TIMEOUT
    ) -> None:
        self._portal.call(self._wait_frames, frames, frame_type, timeout)

    def run_scene(self, scene_path: str, timeout: float = 300.0) -> None:
        self._portal.call(self._run_scene, scene_path, timeout)

    def stop_running_scene(self, timeout: float = DEFAULT_TIMEOUT) -> None:
        self._portal.call(self._stop_on_loop, timeout)

    def screenshot(self, timeout: float = DEFAULT_TIMEOUT) -> bytes:
        """PNG текущего кадра. `game_screenshot` отдаёт image-блок, а не JSON,
        поэтому `_call`/`_first_text` его теряют — читаем content напрямую."""
        return self._portal.call(self._screenshot, timeout)

    async def _screenshot(self, timeout: float) -> bytes:
        result = await self._session.call_tool(
            "game_screenshot", {}, read_timeout_seconds=_timeout_for(timeout)
        )
        if _is_error(result):
            raise MCPError(f"тулз game_screenshot вернул ошибку: {_first_text(result)}")
        for block in getattr(result, "content", []) or []:
            if getattr(block, "type", None) == "image":
                return base64.b64decode(block.data)
        raise MCPError("game_screenshot не вернул image-блок")

    async def _stop_on_loop(self, timeout: float) -> None:
        if not self._running:
            return
        self._running = False
        try:
            await self._call("stop_project", {}, timeout)
        except MCPError as e:
            print(f"[mcp] stop_project: {e}", flush=True)
        await wait_port_free(port=self._port)

    async def _execute_code(self, code: str, timeout: float) -> Any:
        return await self._call("game_eval", {"code": code}, timeout)

    async def _wait_frames(self, frames: int, frame_type: str, timeout: float) -> None:
        await self._call("game_wait", {"frames": frames, "frameType": frame_type}, timeout)

    async def _run_scene(self, scene_path: str, timeout: float) -> None:
        # setup-only: занятый СВОЙ порт = сироты из убитого прогона → немедленный
        # fail (T-120). ci-speedup: проверяется порт воркера, не дефолт 9090
        # (в параллельном режиме 9090 может легитимно держать соседний воркер).
        await wait_port_free(port=self._port, immediate=True)
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
        raise MCPError(
            f"игра не готова за {timeout:.0f} с (последняя ошибка: {last})\n  "
            + readiness_evidence(self.boot_trace, launch_log=self.launch_log, port=self._port)
        )

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

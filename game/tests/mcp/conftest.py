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

WORLD_SCENE = "res://scenes/archive/world.tscn"
BATTLE_SCENE = "res://scenes/battle.tscn"

PROJECT_GODOT = GAME_DIR / "project.godot"

# mcp SDK наследует только DEFAULT_INHERITED_ENV_VARS (без DISPLAY) — передаём явно,
# иначе Godot без дисплея умирает сразу после spawn (найдено бисекцией, 2026-10-03).
SERVER_ENV = {"GODOT_PATH": GODOT_BIN}
if os.environ.get("DISPLAY"):
    SERVER_ENV["DISPLAY"] = os.environ["DISPLAY"]

# CI-4: карантин флейков — файл quarantine.txt, по записи на тест:
#   <nodeid подстрока>	<ГГГГ-ММ-ДД>	<причина>
# Запись с истёкшим сроком НЕ молчит: тест возвращается в свит, а просроченная
# строка валит прогон (карантин без ревизии = невидимый долг, D-135).
QUARANTINE_FILE = Path(__file__).resolve().parent / "quarantine.txt"


def _quarantine_entries() -> list[tuple[str, str, str]]:
    if not QUARANTINE_FILE.exists():
        return []
    rows = []
    for line in QUARANTINE_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) == 3:
            rows.append((parts[0], parts[1], parts[2]))
        else:
            raise ValueError(f"quarantine.txt: строка не «nodeid\tсрок\tпричина»: {line!r}")
    return rows


def _quarantine_expired(today: str) -> list[str]:
    return [f"{n} (срок {d}: {r})" for n, d, r in _quarantine_entries() if d < today]


def pytest_collection_modifyitems(config, items):
    today = time.strftime("%Y-%m-%d")
    expired = _quarantine_expired(today)
    if expired:
        raise pytest.UsageError(
            "quarantine.txt просрочен (пересобрать/вернуть в свит, молчать нельзя):\n  "
            + "\n  ".join(expired)
        )
    active = [(n, d, r) for n, d, r in _quarantine_entries() if d >= today]
    for item in items:
        for needle, until, reason in active:
            if needle in item.nodeid:
                item.add_marker(pytest.mark.skip(reason=f"CI-4 карантин (срок до {until}): {reason}"))
                break


_PRISTINE_PROJECT_GODOT = PROJECT_GODOT.read_text()

def _restore_project_godot_if_dirty() -> None:
    try:
        if PROJECT_GODOT.read_text() != _PRISTINE_PROJECT_GODOT:
            PROJECT_GODOT.write_text(_PRISTINE_PROJECT_GODOT)
            print("[mcp] project.godot восстановлен (node ушёл без rollback)", file=sys.stderr)
    except OSError as e:
        print(f"[mcp] не удалось проверить project.godot: {e}", file=sys.stderr)
    # Артефакты инжекта MCP-сервера (тот же состав, что чистит run_tests.sh):
    # осиротевший .uid без скрипта красит checker 1 (CI-2, инцидент 4c77f72e).
    for artifact in ("mcp_interaction_server.gd", "mcp_interaction_server.gd.uid"):
        (GAME_DIR / artifact).unlink(missing_ok=True)

def _server_params(extra_env: dict | None = None) -> StdioServerParameters:
    env = dict(SERVER_ENV)
    if extra_env:
        env.update(extra_env)
    return StdioServerParameters(
        command=NODE_BIN,
        args=[str(GODOT_MCP_DIR / "build" / "index.js")],
        cwd=str(GAME_DIR),
        env=env,
    )

@pytest.fixture
def mcp(_server_env: dict = None):
    box: dict = {}
    ready = threading.Event()
    done = threading.Event()

    async def main() -> None:
        try:
            async with stdio_client(_server_params(_server_env)) as (read, write):
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


def _wait_for_scene(mcp, marker: str, timeout: float = 60.0) -> None:
    """Ждём, пока current_scene станет сценой, чей скрипт содержит marker."""
    code = (
        "var s = get_tree().current_scene\n"
        'return {"marker": s != null and s.get_script() != null and '
        's.get_script().resource_path.contains("' + marker + '")}'
    )
    deadline = time.time() + timeout
    while time.time() < deadline:
        r = mcp.execute_code(code)
        if r.get("marker"):
            return
        time.sleep(0.5)
    raise MCPError(f"Сцена {marker} не загрузилась за {timeout:.0f} с")


@pytest.fixture
def full_cycle(mcp):
    """Полный цикл (cutover D-157): меню → создание персонажа → main.tscn
    (K-канон-линия). Профиль персистится в persistence; потребление профиля
    кампанией — слой за репойнтом (MVP-срез)."""
    mcp.run_scene("res://scenes/main_menu.tscn")
    mcp.wait_ready()
    mcp.execute_code(
        "get_tree().current_scene._on_new_game()\nreturn {\"ok\": true}"
    )
    _wait_for_scene(mcp, "character_creation")
    mcp.execute_code(
        "var cc = get_tree().current_scene\n"
        'cc._profile.name = "McpCycleHero"\n'
        "cc._profile.race = cc._race_keys[0]\n"
        "cc._profile.character_class = cc._class_keys[0]\n"
        "cc._profile.culture = cc._culture_keys[0]\n"
        "cc._profile.background = cc._background_keys[0]\n"
        "cc._on_create()\n"
        'return {"ok": true}'
    )
    # T-002: после создания — экран выбора Знака (выбор 1 из 8 на всю игру).
    _wait_for_scene(mcp, "sign_choice")
    mcp.execute_code(
        "var sc = get_tree().current_scene\n"
        'sc._on_sign_pressed("harmony")\n'
        'return {"ok": true}'
    )
    _wait_for_scene(mcp, "scripts/main/main")
    deadline = time.time() + 120
    while time.time() < deadline:
        try:
            r = mcp.execute_code(
                "var s = get_tree().current_scene\n"
                'var c = s.get("composition") if s != null else null\n'
                'return {"alive": c != null and c.campaign != null}',
                timeout=15.0,
            )
            if r.get("alive"):
                # Таймер дня не должен конкурировать с ручными ходами тестов.
                mcp.execute_code(
                    "get_tree().current_scene._is_day_cycle_active = false\n"
                    'return {"ok": true}'
                )
                break
        except Exception:  # noqa: BLE001 — загрузка сцены может блокировать main loop
            pass
        time.sleep(1.0)
    else:
        raise MCPError("CampaignComposition в main.tscn не стартовал за 120 с")
    yield mcp

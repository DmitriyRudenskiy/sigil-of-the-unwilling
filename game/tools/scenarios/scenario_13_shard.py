"""
scenario_13_shard.py — Сценарий «Shard abstraction» (astral-macro Stage 1).

Проверяет три требования Stage 1:
  1. Второй фрагмент (shard #2) определяет фиксированный сид — мир с этим сидом
     детерминирован: два запуска с GAME_RUN_SEED=SHARD_2_SEED дают ОДИН и тот же
     карту (ресурсы/герой на одинаковых клетках). «Мир совпадает с сидом».
  2. Сохранение v7 кладёт активный фрагмент под shards[active] с
     active_shard_id — сериализованный сейв содержит shards и версия 7.
  3. Round-trip: SAVE -> LOAD восстанавливает состояние мира без потерь.

Shard #2: name="Забвение", seed=0x2A1F3C7, biome="waste" (см. ShardManager.gd).
Сид пробрасывается через GAME_RUN_SEED: WorldBootstrap.run(shard_seed=0) →
get_run_seed() читает GAME_RUN_SEED → session.run_seed=0x2A1F3C7 → MapGenerator
детерминирован.

Запуск:
    python3 tools/scenarios/scenario_13_shard.py
    # или через оркестратора (с передачей сида):
    GAME_RUN_SEED=0x2A1F3C7 ./tools/shell/play_scenario.sh 13
"""

import json
import os
import socket
import subprocess
import sys
import time

# Astral-macro Stage 1: сид второго фрагмента (ShardManager.SHARD_2_SEED).
SHARD_2_SEED = 0x2A1F3C7
PORT = 9095
HERE = os.path.dirname(os.path.abspath(__file__))
# scenario_13_shard.py -> game/tools/scenarios -> game/tools -> game -> REPO_ROOT
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
GODOT_BIN = os.environ.get("GODOT_BIN", "/Applications/Godot.app/Contents/MacOS/Godot")
SCENARIOS_TIMEOUT = float(os.environ.get("SCENARIOS_TIMEOUT", "60"))


def log(msg: str) -> None:
    print(msg, flush=True)


class ScenarioError(Exception):
    """Фатальная ошибка — сценарий провален."""


# --------------------------- сокет-утилиты ---------------------------

def connect(port: int, timeout: float) -> socket.socket:
    for _ in range(int(timeout)):
        try:
            s = socket.create_connection(("127.0.0.1", port), timeout=1)
            s.settimeout(5)
            return s
        except OSError:
            time.sleep(1)
    raise ScenarioError(f"Не дождались сокета на порту {port}")


def send_cmd(sock: socket.socket, action: str, **args) -> dict:
    payload = {"id": "shard", "action": action, **args}
    sock.sendall((json.dumps(payload) + "\n").encode("utf-8"))
    # Читаем ответ: строки до пустой строки (JSON-объект + разделитель).
    buf = b""
    while b"\n" not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            raise ScenarioError("Соединение закрыто сервером без ответа")
        buf += chunk
    line = buf.split(b"\n", 1)[0].decode("utf-8")
    resp = json.loads(line)
    # Пропускаем промежуточные строки (WorldReady / progress), если есть.
    if b"\n" in buf:
        rest = buf.split(b"\n", 1)[1]
        rest = rest.strip()
        if rest:
            try:
                json.loads(rest)  # валидация: не ломаем парсинг
            except json.JSONDecodeError:
                pass  # лог-строка, игнорируем
    return resp


def wait_world_ready(sock: socket.socket, timeout: float) -> dict:
    """Ждём, пока START_GAME не выдаст мир (hero_pos + map_resources)."""
    deadline = time.time() + timeout
    state = {}
    while time.time() < deadline:
        state = send_cmd(sock, "GET_STATE")
        if state.get("mode") == "world" and state.get("hero_pos") and state.get("map_resources"):
            return state
        time.sleep(0.5)
    raise ScenarioError(f"Мир не загрузился за {timeout}с. state={state}")


def map_signature(state: dict) -> tuple:
    """Детерминированный отпечаток мира: позиции ресурсов + герой + города."""
    res = sorted(
        (r.get("x"), r.get("y"))
        for r in state.get("map_resources", [])
        if isinstance(r, dict) and "x" in r and "y" in r
    )
    hero = state.get("hero_pos") or {}
    # Клетки городов — dicts (непорядковые); сериализуем через json для сравнения.
    cities = sorted(
        json.dumps((c.get("cell") if isinstance(c.get("cell"), dict) else {}), sort_keys=True)
        for c in state.get("cities", [])
    )
    return (tuple(res), (hero.get("x"), hero.get("y")), tuple(cities))


def launch_server(env_seed: int) -> subprocess.Popen:
    env = dict(os.environ)
    env["GAME_RUN_SEED"] = str(env_seed)
    log(f"  🚀 Запуск Godot (GAME_RUN_SEED=0x{env_seed:X}, pid={os.getpid()})")
    return subprocess.Popen(
        [
            GODOT_BIN,
            "--path", REPO_ROOT + "/game",
            "--headless",
            "--test-server",
            "--scene", "scenes/MainMenu.tscn",
        ],
        env=env,
        stdout=open(os.path.join(REPO_ROOT, "tmp", "shard_server.log"), "ab"),
        stderr=subprocess.STDOUT,
    )


def wait_socket_ready(timeout: float) -> socket.socket:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            s = socket.create_connection(("127.0.0.1", PORT), timeout=1)
            s.settimeout(5)
            return s
        except OSError:
            time.sleep(0.5)
    raise ScenarioError(f"Не дождались сокета на порту {PORT} за {timeout}с")


def boot_and_capture(sock: socket.socket, timeout: float) -> dict:
    send_cmd(sock, "START_GAME")
    state = wait_world_ready(sock, timeout)
    return state


def main() -> None:
    log("=== Сценарий 13: Shard abstraction (astral-macro Stage 1) ===")
    log(f"  shard #2 seed = 0x{SHARD_2_SEED:X} (GAME_RUN_SEED)")

    failures = []

    # --- 1. Детерминированность: два запуска с одинаким сидом = одинакий мир. ---
    log("\n🧪 Тест 1: мир совпадает с сидом (детерминированность)")
    proc1 = launch_server(SHARD_2_SEED)
    try:
        sock1 = wait_socket_ready(SCENARIOS_TIMEOUT)
        try:
            sig1 = map_signature(boot_and_capture(sock1, SCENARIOS_TIMEOUT))
            log(f"  🌍 Запуск 1: ресурсов={len(sig1[0])}, герой={sig1[1]}, городов={len(sig1[2])}")
        finally:
            sock1.close()
    finally:
        proc1.terminate()
        try:
            proc1.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc1.kill()

    proc2 = launch_server(SHARD_2_SEED)
    try:
        sock2 = wait_socket_ready(SCENARIOS_TIMEOUT)
        try:
            sig2 = map_signature(boot_and_capture(sock2, SCENARIOS_TIMEOUT))
            log(f"  🌍 Запуск 2: ресурсов={len(sig2[0])}, герой={sig2[1]}, городов={len(sig2[2])}")
        finally:
            sock2.close()
    finally:
        proc2.terminate()
        try:
            proc2.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc2.kill()

    if sig1 != sig2:
        failures.append("Детерминированность: два запуска с сидом 0x%X дали разную карту" % SHARD_2_SEED)
        log("  ❌ карты отличаются между запусками")
    else:
        log("  ✅ два запуска с одинаким сидом → одинакий мир")

    # --- 2. Сохранение v7: shards + active_shard_id в сериализованном сейве. ---
    log("\n🧪 Тест 2: сейв v7 содержит fragments (shards) и active_shard_id")
    proc3 = launch_server(SHARD_2_SEED)
    try:
        sock3 = wait_socket_ready(SCENARIOS_TIMEOUT)
        try:
            boot_and_capture(sock3, SCENARIOS_TIMEOUT)
            save = send_cmd(sock3, "SAVE_GAME")
            if save.get("status") != "saved":
                failures.append(f"SAVE_GAME не сохранил: {save}")
                log(f"  ❌ SAVE_GAME вернул: {save}")
            else:
                log(f"  💾 save.version={save.get('version')}, "
                    f"active_shard_id={save.get('active_shard_id')}, "
                    f"run_seed=0x{save.get('run_seed', 0):X}")
                if save.get("version") != 7:
                    failures.append(f"version={save.get('version')} (ожидалось 7)")
                if save.get("active_shard_id") != "shard_1":
                    failures.append(f"active_shard_id={save.get('active_shard_id')} (ожидалось shard_1)")
                shards = save.get("shards", {})
                if not shards:
                    failures.append("shards пуст в сериализованном сейве")
                else:
                    active = shards.get("shard_1", {})
                    if not active.get("world"):
                        failures.append("shards.shard_1.world пуст (нет мира в сейве)")
                    else:
                        log(f"  ✅ shards.shard_1.world: cities={len(active['world'].get('cities', []))}, "
                            f"hero={active['world'].get('hero')}")
        finally:
            sock3.close()
    finally:
        proc3.terminate()
        try:
            proc3.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc3.kill()

    # --- 3. Round-trip: SAVE -> LOAD восстанавливает мир. ---
    log("\n🧪 Тест 3: round-trip SAVE -> LOAD без потерь")
    proc4 = launch_server(SHARD_2_SEED)
    try:
        sock4 = wait_socket_ready(SCENARIOS_TIMEOUT)
        try:
            before = boot_and_capture(sock4, SCENARIOS_TIMEOUT)
            sig_before = map_signature(before)
            save = send_cmd(sock4, "SAVE_GAME")
            if save.get("status") != "saved":
                failures.append("SAVE перед round-trip не удался")
                log("  ❌ SAVE перед round-trip не удался")
            else:
                loaded = send_cmd(sock4, "LOAD_GAME")
                if loaded.get("status") != "loaded":
                    failures.append(f"LOAD_GAME: {loaded}")
                    log(f"  ❌ LOAD_GAME вернул: {loaded}")
                else:
                    after = wait_world_ready(sock4, SCENARIOS_TIMEOUT)
                    sig_after = map_signature(after)
                    if sig_before != sig_after:
                        failures.append("Round-trip: состояние мира изменилось после LOAD")
                        log("  ❌ мир после LOAD отличается до LOAD")
                    else:
                        log("  ✅ round-trip: мир до и после LOAD совпадает")
        finally:
            sock4.close()
    finally:
        proc4.terminate()
        try:
            proc4.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc4.kill()

    # ---------- итог ----------
    log("\n=== Итог ===")
    if failures:
        for f in failures:
            log(f"  ❌ {f}")
        log("❌ Сценарий ПРОВАЛЕН")
        sys.exit(1)
    log("✅ Все проверки пройдены: детерминированность + сейв v7 + round-trip")
    sys.exit(0)


if __name__ == "__main__":
    main()

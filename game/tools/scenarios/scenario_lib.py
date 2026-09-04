"""
scenario_lib.py — общая библиотека для сокет-сценариев (cycle: auto-game-scenarios).

Единая реализация того, что раньше дублировалось в каждом из сценариев 1–12:
  - connect / send_cmd — протокол (newline-delimited JSON, MOVE_TO читает x/y
    из top-level, остальные — из args);
  - poll / wait_arrival — опрос GET_STATE с таймаутом;
  - Reporter — ассерт-хелпер (check/require/summary) вместо локальных
    check() + FAILURES в каждом сценарии;
  - scan_server_log — скан лога сервера по таксономии operability-гейта
    (docs/CONSOLE_ALLOWLIST.md): error-класс, warning-класс, вырезка app-логгера
    ([color=]).

Протокол: {id, action, args}, MOVE_TO читает x/y из top-level, остальные — из args.
PORT 9095, как в play_scenario.sh / run_operability.sh.

    from scenario_lib import connect, send_cmd, Reporter, scan_server_log
"""

import json
import os
import socket
import time

DEFAULT_PORT = 9095
DEFAULT_LOG = os.environ.get("SCENARIO_LOG", "/tmp/godot_scenario.log")

# Таксономия маркеров — КОПИЯ гейта check_console_clean.sh / run_operability.sh
# (ERROR_RE + WARN_RE + EXCLUDE_RE). Один источник «чистоты»: error-класс —
# регрессия, warning-класс — только если НЕ в allowlist
# (docs/CONSOLE_ALLOWLIST.md). Ложные срабывания — лог САМОго приложения
# (GameLogger: каждая строка несёт [color=тег]); его намеренные проверки
# (SaveManager: parse error / Unknown template / File not found) — не регрессия
# кода. Реальные ошибки движка (SCRIPT ERROR / parse / leak) цвет-тегов не несут.
ERROR_PATTERNS = (
    "SCRIPT ERROR", "Parse error", "Invalid call", "Nonexistent function",
    "Nonexistent class", "Nonexistent base", "Too many arguments",
    "Cannot infer", "Invalid get/set", "Failed to load script",
    "Can't load script", "Could not find type", "does not inherit from",
)
WARN_PATTERNS = ("WARNING", "NOTICE", "LEAK", "leaked", "deprecated", "W 0:")
EXCLUDE_PATTERNS = ("[color=", "SaveManager: parse error", "Unknown template", "File not found")
# В allowlist docs/CONSOLE_ALLOWLIST.md (warning-класс, не валит гейт):
ALLOWLIST_PATTERNS = (
    "Loaded resource as image file",  # pre-existing фолбэкс загрузки UI-ассетов
    "ObjectDB instances were leaked at exit",  # teardown-шум Godot 4.7 (N<=20)
)


def connect(port=DEFAULT_PORT, timeout=10.0):
    """Подключение к тестовому сокет-серверу. Возвращает сокет (не закрытый)."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    sock.connect(("localhost", port))
    return sock


def send_cmd(sock, action, args=None, top=None, cmd_id=0):
    """
    Отправить команду, вернуть один ответ (dict).

    MOVE_TO читает x/y из top-level; остальные действия — из args.
    """
    if args is None:
        args = {}
    msg = {"id": cmd_id, "action": action, "args": args}
    if top:
        msg.update(top)
    sock.sendall((json.dumps(msg) + "\n").encode("utf-8"))
    sock.settimeout(10.0)
    buf = ""
    while "\n" not in buf:
        chunk = sock.recv(65536)
        if not chunk:
            break
        buf += chunk.decode("utf-8")
    line = buf.split("\n", 1)[0]
    try:
        return json.loads(line)
    except json.JSONDecodeError:
        return {"raw": line}


def poll(sock, predicate, timeout=30.0, interval=0.1):
    """Опросить GET_STATE, пока predicate(state) истинна или не исчерпан таймаут."""
    deadline = time.time() + timeout
    state = send_cmd(sock, "GET_STATE")
    while not predicate(state) and time.time() < deadline:
        time.sleep(interval)
        state = send_cmd(sock, "GET_STATE")
    return state


# fog-of-war: по не изученным клеткам A* не строит путь (INF-стоимость),
# поэтому одиночный MOVE_TO на далёкую цель падает с 'unreachable' даже на
# связанной карте. move_toward шлёт героя к waypoint'у на доли пути к цели —
# клетка внутри explored-диска (sight=3) достижима, и каждый день герой
# продвигается и расширяет explored ещё на радиус зрения.
_FOG_FRACTIONS = (1.0, 0.6, 0.4, 0.25, 0.12)


def move_toward(sock, st, target):
    """MOVE_TO к target; если туман режет путь — к ближайшему waypoint'у
    на прямой hero->target. True — команда принята (герой пошёл)."""
    pos = st.get("hero_pos") or {}
    hx, hy = pos.get("x"), pos.get("y")
    if hx is None or hy is None:
        return False
    tx, ty = target["x"], target["y"]
    for f in _FOG_FRACTIONS:
        if f >= 1.0:
            wx, wy = tx, ty
        else:
            wx = hx + round((tx - hx) * f)
            wy = hy + round((ty - hy) * f)
        if (wx, wy) == (hx, hy):
            continue
        r = send_cmd(sock, "MOVE_TO", {}, top={"x": wx, "y": wy})
        if "error" not in r:
            return True
    return False


def wait_arrival(sock, target, tries=100):
    """Ждать, пока hero доберётся до target={x,y}. True — дошёл; False — нет/застрял."""
    for _ in range(tries):
        s = send_cmd(sock, "GET_STATE")
        pos = s.get("hero_pos")
        if pos == {"x": target["x"], "y": target["y"]}:
            return True
        if not s.get("moving", True) and pos != {"x": target["x"], "y": target["y"]}:
            return False
        time.sleep(0.1)
    return False


# hero-survival: в поле потребности (rest/social/inspiration) только распаляются
# (смерть — 3 дня у нуля), в городе восстанавливаются в hero-темпе. keep_alive
# возвращает героя в столицу при min < TRIGGER и держит до min >= TARGET.
# Цикл ~3.3 полевых + ~2 городских дня: устойчивый запас по inspiration
# (иначе burnout-дедлайн ~день 20 убивает любой длинный сценарий).
KEEP_ALIVE_TRIGGER = 0.50
KEEP_ALIVE_TARGET = 0.95


def keep_alive(sock, st):
    """Если любая потребность < TRIGGER — герой в столицу, сидим до TARGET.

    Возвращает свежий GET_STATE. Если герой умер — возвращает state с
    hero_pos=None (сценарий обрабатывает как обычный провал). Кап 20 ходов:
    не зависаем, если что-то пошло не так.
    """
    needs = st.get("needs") or {}
    capital = (st.get("capital") or {}).get("center")
    if not needs or not capital or min(needs.values()) >= KEEP_ALIVE_TRIGGER:
        return st
    cx, cy = capital["x"], capital["y"]
    for _ in range(20):
        st = send_cmd(sock, "GET_STATE")
        if st.get("mode") != "world":
            return st  # бой на пути и т.п. — сценарий обработает в своём цикле
        needs = st.get("needs") or {}
        if not needs:
            return st  # герой умер
        if min(needs.values()) >= KEEP_ALIVE_TARGET:
            return st
        pos = st.get("hero_pos") or {}
        if (pos.get("x"), pos.get("y")) != (cx, cy):
            if move_toward(sock, st, {"x": cx, "y": cy}):
                wait_arrival(sock, {"x": cx, "y": cy})
        send_cmd(sock, "END_TURN")
    return send_cmd(sock, "GET_STATE")


class Reporter:
    """Ассерт-хелпер: замена локальным check() + FAILURES в сценариях."""

    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.failures = []

    def check(self, label, cond, detail=""):
        cond = bool(cond)
        suffix = f" — {detail}" if (detail and not cond) else ""
        print(f"    {'PASS' if cond else 'FAIL'}  {label}{suffix}")
        if cond:
            self.passed += 1
        else:
            self.failed += 1
            self.failures.append(f"{label}{suffix}")
        return cond

    def require(self, label, cond, detail=""):
        """check(), но с бросанием AssertionError — для инвариантов, дальше не идём."""
        if not self.check(label, cond, detail):
            raise AssertionError(f"required invariant failed: {label}")
        return cond

    @property
    def ok(self):
        return self.failed == 0

    def summary(self):
        total = self.passed + self.failed
        return f"{self.passed}/{total} passed"


def scan_log(text):
    """
    Скан текста лога по таксономии operability-гейта.

    Возвращает (errors, warnings) — списки строк. error-класс и warning-класс
    классифицируются как в check_console_clean.sh; app-логгер ([color=]) и
    allowlisted-шум (ALLOWLIST_PATTERNS) исключаются.
    """
    errors, warnings = [], []
    if not text:
        return errors, warnings
    for line in text.splitlines():
        if not line.strip():
            continue
        if any(pat in line for pat in EXCLUDE_PATTERNS):
            continue
        if any(pat in line for pat in ALLOWLIST_PATTERNS):
            continue
        if any(pat in line for pat in ERROR_PATTERNS):
            errors.append(line.strip())
        elif any(pat in line for pat in WARN_PATTERNS):
            warnings.append(line.strip())
    return errors, warnings


def scan_server_log(path=DEFAULT_LOG):
    """Считать лог сервера и сканировать (см. scan_log). Пустой список, если файла нет."""
    try:
        with open(path, "r", errors="replace") as f:
            text = f.read()
    except (FileNotFoundError, OSError):
        return [], []
    return scan_log(text)

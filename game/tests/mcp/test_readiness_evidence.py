"""T-172: отказ readiness обязан называть причину, а не только дедлайн.

До правки три разные беды печатались одной строкой «игра не готова за 180 с
(… Not connected to game interaction server.)»: Godot не стартовал, Godot
стартовал медленно (машина в global OOM — см. замеры T-172 и D-265), и `listen()`
однажды отказал и больше не повторялся. Тесты ниже проверяют то, что делает
различение возможным: разбор среды, хвост boot-трейса и сам факт, что живая игра
этот трейс пишет.

Бога не требуют: первые четыре теста — чистая логика (прецедент — test_capture.py).
Пятый поднимает Godot: он и есть рэтчет того, что механизм наблюдаемости работает
в настоящем стенде, а не только на фейковых /proc.
"""

from __future__ import annotations

import socket
from pathlib import Path

import pytest

import godot_mcp  # noqa: F401  (sys.path для соседних модулей стенда настраивает conftest)
from godot_mcp import (
    boot_trace_tail,
    env_snapshot,
    godot_processes,
    read_loadavg,
    read_meminfo_kb,
    read_psi_some,
    probe_listen,
    readiness_evidence,
)

MEMINFO = """MemTotal: 48000000 kB
MemAvailable: 3500000 kB
SwapTotal: 19000000 kB
SwapFree: 8000000 kB
"""


def _fake_proc(tmp_path: Path) -> dict:
    """Фейковый /proc: meminfo, loadavg, PSI и два «процесса» (godot и чужой)."""
    mem = tmp_path / "meminfo"
    mem.write_text(MEMINFO, encoding="utf-8")
    load = tmp_path / "loadavg"
    load.write_text("4.25 3.10 2.00 1/234 99999\n", encoding="utf-8")
    psi = tmp_path / "psi"
    psi.write_text("some avg10=12.34 avg60=5.60 avg300=1.20 total=99\nfull avg10=0.00\n", encoding="utf-8")
    root = tmp_path / "proc"
    fake = (
        ("111", "/usr/bin/godot --path game", "State:\tR (running)\nVmRSS:\t 1200000 kB\n"),
        ("222", "node index.js", "State:\tS (sleeping)\nVmRSS:\t  90000 kB\n"),
        # Сосед по имени, которым предыдущая версия счётчика звала Godot'ом:
        # python-стенд и node-сервер содержат «godot» в пути, но движком не являются.
        ("333", "/home/user/.venv/godot-mcp-tests/bin/python -m pytest tests/mcp",
         "State:\tS (sleeping)\nVmRSS:\t  60000 kB\n"),
        ("444", "/usr/bin/godot_headless --headless", "State:\tD (disk)\nVmRSS:\t 400000 kB\n"),
    )
    # Точка, в которой процесс стоит: wchan + syscall + набор fd (у «чужого» 222
    # и у соседа 333 файлов нет намеренно — проверка не должна на них спотыкаться).
    wait = {"111": ("poll_schedule_timeout", "7 0x7 0x1 0xffffffff 0x0 0x0 0x0 0x7ffd 0x7f8"),
            "444": ("0", "running")}
    for pid, cmd, status in fake:
        d = root / pid
        d.mkdir(parents=True)
        (d / "cmdline").write_text(cmd.replace(" ", "\0") + "\0", encoding="utf-8")
        (d / "status").write_text(status, encoding="utf-8")
        if pid in wait:
            wchan, syscall = wait[pid]
            (d / "wchan").write_text(wchan, encoding="utf-8")
            (d / "syscall").write_text(syscall + "\n", encoding="utf-8")
            for n in range(5 if pid == "111" else 2):
                fd = d / "fd" / str(n)
                fd.parent.mkdir(parents=True, exist_ok=True)
                fd.write_text("", encoding="utf-8")
    return {
        "meminfo_path": str(mem),
        "loadavg_path": str(load),
        "psi_path": str(psi),
        "proc_root": str(root),
    }


def test_meminfo_and_loadavg_parse_absent_files_as_none(tmp_path: Path) -> None:
    missing = tmp_path / "nope"
    assert read_meminfo_kb(str(missing)) == {}
    assert read_loadavg(str(missing)) is None
    assert read_psi_some(str(missing)) == ""


def test_env_snapshot_reads_memory_load_and_godot_processes(tmp_path: Path) -> None:
    snap = env_snapshot(**_fake_proc(tmp_path))
    assert snap["mem_available_mb"] == 3418          # 3 500 000 КиБ
    assert snap["mem_total_mb"] == 46875             # 48 000 000 КиБ — масштаб «мало»
    assert snap["swap_free_mb"] == 7812              # 8 000 000 КиБ → 7812.5 → round
    assert snap["swap_total_mb"] == 18555
    assert snap["load1"] == 4.25
    assert snap["psi_memory"].startswith("some avg10=12.34")
    # godot и godot_headless — движки; pytest с «godot» в пути и node — нет.
    assert snap["godot_processes"] == 2
    assert snap["godot_rss_mb"] == 1172 + 391        # 1 200 000 и 400 000 КиБ
    assert snap["godot_states"] == "D:1,R:1"
    # Где стоит каждый движок — то, чего не хватало второму замеру T-172: процесс
    # в состоянии S при 1189 MB свободной памяти ждёт, но чего именно — из state не видно.
    blockage = snap["godot_blockage"]
    assert "pid=111 R wchan=poll_schedule_timeout syscall=7 fd=5" in blockage
    assert "pid=444 D wchan=0 syscall=running fd=2" in blockage


def test_zero_mem_available_is_not_rendered_as_unread(tmp_path: Path) -> None:
    """«Памяти ноль» и «памяти не видно» — разные новости, и вторая была ложной.

    Прогон гейта 2026-10-28 на машине с `swap_free=403/20479MB` напечатал
    «mem_available=не прочитано» — при том что MemAvailable в /proc был и мог
    быть нулевым. `round(kb / 1024) or None` терял ноль, и единственный номер,
    способный подтвердить или снять гипотезу нехватки памяти (T-172, Q-M115),
    превращался в слепое пятно.
    """
    src = _fake_proc(tmp_path)
    (tmp_path / "meminfo").write_text(
        "MemTotal: 19000000 kB\nMemAvailable: 0 kB\n"
        "SwapTotal: 19000000 kB\nSwapFree: 0 kB\n",
        encoding="utf-8",
    )
    snap = env_snapshot(**src)
    assert snap["mem_available_mb"] == 0
    assert snap["swap_free_mb"] == 0
    text = readiness_evidence(snapshot=snap)
    assert "mem_available=0MB" in text
    assert "из 18555MB" in text
    assert "не прочитано" not in text
    assert "swap_free=0/18555MB" in text  # 19 000 000 КиБ = 18555 МБ, не 19000


def test_godot_processes_ignores_processes_with_godot_in_path(tmp_path: Path) -> None:
    """Счётчик по подстроке командной строки врал про `godot_procs=3` там, где был
    один движок: «godot» носят в себе pytest-венв и node-сервер."""
    procs = godot_processes(str(_fake_proc(tmp_path)["proc_root"]))
    assert sorted(p["exe"] for p in procs) == ["godot", "godot_headless"]
    assert {p["state"] for p in procs} == {"R", "D"}


def test_godot_processes_survives_missing_proc(tmp_path: Path) -> None:
    assert godot_processes(str(tmp_path / "absent")) == []


def test_blockage_degrades_without_kernel_files(tmp_path: Path) -> None:
    """Без `wchan`/`syscall`/`fd` (чужие pid, macOS, урезанный /proc) отчёт обязан
    остаться читаемым: «?» лучше, чем исключение в тексте другой ошибки."""
    procs = godot_processes(str(_fake_proc(tmp_path)["proc_root"]))
    by_pid = {p["pid"]: p for p in procs}
    assert (by_pid[444]["wchan"], by_pid[444]["syscall"], by_pid[444]["fds"]) == ("0", "running", 2)
    assert by_pid[111]["fds"] == 5


def test_evidence_names_absent_godot_instead_of_blaming_proc() -> None:
    """Строка «нет /proc» наврёт, если /proc на месте, а движок уже умер.

    Readiness-отказ наступает и после завершения Godot; винить /proc — значит
    отправить расследование искать примонтированный /proc вместо правды «никого
    нет» (тот же класс лжи, что и «не прочитано» вместо нуля).
    """
    empty = {
        "mem_available_mb": 1200, "mem_total_mb": 47242,
        "swap_free_mb": 9000, "swap_total_mb": 20479,
        "load1": 1.0, "psi_memory": None,
        "godot_processes": 0, "godot_rss_mb": 0, "godot_states": None,
        "godot_blockage": "",
    }
    text = readiness_evidence(snapshot=empty)
    assert "ни одного Godot-процесса" in text
    assert "нет /proc" not in text
    # Третье состояние — снапшот вообще без измерения: «никого нет» наврёт и тут.
    partial = {k: v for k, v in empty.items() if k != "godot_blockage"}
    assert "не измерено" in readiness_evidence(snapshot=partial)


def test_evidence_survives_an_empty_snapshot() -> None:
    """Канал не имеет права быть второй поломкой: пустой снапшот — отчёт, не KeyError.

    `readiness_evidence` вызывается из текста другой ошибки; исключение здесь
    съело бы и причину, и подпись классификатора D-265 — ровно та цена, которую
    заплатили за `port=self.port` (T-275).
    """
    text = readiness_evidence(snapshot={})
    assert text.startswith("среда в момент отказа:")
    assert "None" not in text
    assert "не прочитано" in text


def test_boot_trace_tail_separates_missing_from_empty(tmp_path: Path) -> None:
    absent = str(tmp_path / "absent.log")
    assert "не дошёл до автозагрузки" in boot_trace_tail(absent)
    empty = tmp_path / "empty.log"
    empty.write_text("   \n", encoding="utf-8")
    assert "не дошёл до автозагрузки" in boot_trace_tail(str(empty))
    assert "не запрошен" in boot_trace_tail("")


def test_boot_trace_tail_keeps_the_last_lines(tmp_path: Path) -> None:
    trace = tmp_path / "boot.log"
    body = "\n".join(f"100{i} pid=7 listen attempt={i} port=9090 err=4096" for i in range(1, 12))
    trace.write_text(body + "\n", encoding="utf-8")
    tail = boot_trace_tail(str(trace), lines=3)
    assert "attempt=11" in tail
    assert "attempt=9" in tail
    assert "attempt=8" not in tail


def test_probe_listen_tells_backlog_from_no_port() -> None:
    """«Порта нет» и «порт есть, но игра не приняла» — разные вердикты.

    Первый чинит среда, второй — наш главный цикл. Без этой развилки три жертвы
    гейта выглядели как «среда», хотя игра отбиндилась успешно.
    """
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen(1)  # accept не вызывается — ровно то состояние, что у зависшей игры
    port = listener.getsockname()[1]
    try:
        assert "ядро приняло" in probe_listen(port)
        assert "не забрала" in probe_listen(port)
    finally:
        listener.close()
    dead = socket.socket()
    dead.bind(("127.0.0.1", 0))
    dead_port = dead.getsockname()[1]
    dead.close()
    assert "порта нет" in probe_listen(dead_port)
    assert "не проверялся" in probe_listen(None)


def test_readiness_evidence_names_memory_and_trace(tmp_path: Path) -> None:
    trace = tmp_path / "boot.log"
    trace.write_text("12 pid=7 ready: enabled=true port=9090 debug=true\n", encoding="utf-8")
    snap = {
        "mem_available_mb": 311, "mem_total_mb": 47242,
        "swap_free_mb": 0, "swap_total_mb": 19000,
        "load1": 9.9, "psi_memory": "some avg10=88.00",
        "godot_processes": 2, "godot_rss_mb": 1563, "godot_states": "D:1,S:1",
        "godot_blockage": "pid=711 S wchan=poll_schedule_timeout syscall=7 fd=41",
    }
    text = readiness_evidence(str(trace), snapshot=snap)
    assert "mem_available=311MB" in text
    assert "из 47242MB" in text, "без MemTotal «311MB» нераспознаваемо: мало это или много"
    assert "swap_free=0/19000MB" in text
    assert "godot_procs=2(rss=1563MB, state=D:1,S:1)" in text
    assert "где стоит движок: pid=711 S wchan=poll_schedule_timeout syscall=7 fd=41" in text
    assert "порт: не проверялся" in text, "порт в снимок не передан — молчание о порте запрещено"
    assert "mem_available=не прочитано" in readiness_evidence(
        snapshot={**snap, "mem_available_mb": None})
    assert "ready: enabled=true" in text


def test_readiness_error_text_keeps_the_classifier_signature() -> None:
    """D-265 ловит readiness по подписке «игра не готова за» — она обязана остаться
    в начале сообщения, иначе жёлтый перестанет сниматься и среда снова станет
    регрессией."""
    client_src = (Path(__file__).parent / "godot_mcp.py").read_text(encoding="utf-8")
    assert 'f"игра не готова за {timeout:.0f} с' in client_src


def test_live_game_writes_boot_trace(battle_scene) -> None:
    """Живой Godot пишет трейс: без этого пункта наблюдаемость осталась бы
    «работает на фейковых файлах»."""
    path = Path(battle_scene.boot_trace)
    assert path.exists(), f"Godot не создал boot-трейс {path}"
    text = path.read_text(encoding="utf-8")
    assert "ready:" in text
    assert "listen attempt=1" in text


def test_wait_ready_failure_carries_the_evidence_block(tmp_path) -> None:
    """Отказ readiness обязан дойти до отчёта блоком «среда в момент отказа», а не
    traceback'ом из конструктора сообщения.

    Прецедент: в сообщении стояло `port=self.port` при атрибуте `_port` — и вместо
    наблюдаемости T-172 получатель видел `AttributeError: 'GodotMCPClient' object
    has no attribute 'port'`. Тест держит именно склейку `wait_ready` →
    `readiness_evidence`: мокается только транспорт (`portal.call`), путь трейса и
    лог — настоящие временные файлы.
    """
    trace = tmp_path / "boot_trace.log"
    trace.write_text("1 pid=1 ready: enabled=true port=9090 debug=true\n", encoding="utf-8")
    launch = tmp_path / "launch.log"
    launch.write_text("[World] Scene ready\n", encoding="utf-8")

    class StubPortal:
        def call(self, _fn, *_args):
            raise godot_mcp.MCPError("Not connected to game interaction server")

    client = godot_mcp.GodotMCPClient(
        StubPortal(), None, ".", port=9099,
        boot_trace=str(trace), launch_log=str(launch))
    with pytest.raises(godot_mcp.MCPError) as exc:
        client.wait_ready(timeout=0.6, interval=0.2)
    text = str(exc.value)
    assert "игра не готова за" in text, "подписи D-265 нет — жёлтый перестанет сниматься"
    assert "среда в момент отказа" in text, "среда не приложена — причина снова неизвестна"
    assert "ready: enabled=true" in text, "boot-трейс этого Godot не приложен"
    assert "AttributeError" not in text

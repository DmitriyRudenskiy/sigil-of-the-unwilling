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
    for pid, cmd, status in fake:
        d = root / pid
        d.mkdir(parents=True)
        (d / "cmdline").write_text(cmd.replace(" ", "\0") + "\0", encoding="utf-8")
        (d / "status").write_text(status, encoding="utf-8")
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
    assert snap["swap_free_mb"] == 7812              # 8 000 000 КиБ → 7812.5 → round
    assert snap["swap_total_mb"] == 18555
    assert snap["load1"] == 4.25
    assert snap["psi_memory"].startswith("some avg10=12.34")
    # godot и godot_headless — движки; pytest с «godot» в пути и node — нет.
    assert snap["godot_processes"] == 2
    assert snap["godot_rss_mb"] == 1172 + 391        # 1 200 000 и 400 000 КиБ
    assert snap["godot_states"] == "D:1,R:1"


def test_godot_processes_ignores_processes_with_godot_in_path(tmp_path: Path) -> None:
    """Счётчик по подстроке командной строки врал про `godot_procs=3` там, где был
    один движок: «godot» носят в себе pytest-венв и node-сервер."""
    procs = godot_processes(str(_fake_proc(tmp_path)["proc_root"]))
    assert sorted(p["exe"] for p in procs) == ["godot", "godot_headless"]
    assert {p["state"] for p in procs} == {"R", "D"}


def test_godot_processes_survives_missing_proc(tmp_path: Path) -> None:
    assert godot_processes(str(tmp_path / "absent")) == []


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


def test_readiness_evidence_names_memory_and_trace(tmp_path: Path) -> None:
    trace = tmp_path / "boot.log"
    trace.write_text("12 pid=7 ready: enabled=true port=9090 debug=true\n", encoding="utf-8")
    snap = {
        "mem_available_mb": 311, "swap_free_mb": 0, "swap_total_mb": 19000,
        "load1": 9.9, "psi_memory": "some avg10=88.00",
        "godot_processes": 2, "godot_rss_mb": 1563, "godot_states": "D:1,S:1",
    }
    text = readiness_evidence(str(trace), snapshot=snap)
    assert "mem_available=311MB" in text
    assert "swap_free=0/19000MB" in text
    assert "godot_procs=2(rss=1563MB, state=D:1,S:1)" in text
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

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
    count_processes,
    env_snapshot,
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
    for pid, cmd in (("111", "/usr/bin/godot --path game"), ("222", "node index.js")):
        d = root / pid
        d.mkdir(parents=True)
        (d / "cmdline").write_text(cmd.replace(" ", "\0"), encoding="utf-8")
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


def test_env_snapshot_reads_memory_load_and_godot_count(tmp_path: Path) -> None:
    snap = env_snapshot(**_fake_proc(tmp_path))
    assert snap["mem_available_mb"] == 3418          # 3 500 000 КиБ
    assert snap["swap_free_mb"] == 7812              # 8 000 000 КиБ → 7812.5 → round
    assert snap["swap_total_mb"] == 18555
    assert snap["load1"] == 4.25
    assert snap["psi_memory"].startswith("some avg10=12.34")
    assert snap["godot_processes"] == 1


def test_count_processes_survives_missing_proc(tmp_path: Path) -> None:
    assert count_processes("godot", str(tmp_path / "absent")) == 0


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
        "load1": 9.9, "psi_memory": "some avg10=88.00", "godot_processes": 3,
    }
    text = readiness_evidence(str(trace), snapshot=snap)
    assert "mem_available=311MB" in text
    assert "swap_free=0/19000MB" in text
    assert "godot_procs=3" in text
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

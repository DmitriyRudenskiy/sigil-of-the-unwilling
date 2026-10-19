"""Тесты хелпера съёмки + точка запуска съёмки.

Логика хелпера (размер канона, IHDR, манифест) покрывается без Godot и входит
в обычный прогон. Сама съёмка — только по запросу: без `CAPTURE_SCENE` тест
помечен skipped, чтобы гейт не тратил живой Godot на инструмент.
"""

from __future__ import annotations

import os

import pytest

import capture
from capture import CaptureError


def _png(width: int, height: int) -> bytes:
    return (
        capture.PNG_MAGIC + b"\x00\x00\x00\rIHDR"
        + width.to_bytes(4, "big") + height.to_bytes(4, "big") + b"\x00" * 8
    )


def test_parse_size_принимает_канон_и_variants():
    assert capture.parse_size("1920x1080") == (1920, 1080)
    assert capture.parse_size(" 1920×1080 ") == (1920, 1080)


@pytest.mark.parametrize("bad", ["", "1920", "1920xx1080", "a x b", "0x100", "-5x10"])
def test_parse_size_отклоняет_мусор(bad):
    with pytest.raises(CaptureError):
        capture.parse_size(bad)


def test_canonical_size_дефолт_и_override():
    assert capture.canonical_size({}) == capture.CANONICAL_SIZE
    assert capture.canonical_size({capture.SIZE_ENV: "1024x768"}) == (1024, 768)


def test_png_size_читает_IHDR():
    assert capture.png_size(_png(1920, 1080)) == (1920, 1080)


def test_png_size_отклоняет_не_PNG_и_обрезанный():
    with pytest.raises(CaptureError):
        capture.png_size(b"BM....")
    with pytest.raises(CaptureError):
        capture.png_size(capture.PNG_MAGIC + b"\x00\x00")


def test_verify_frame_требует_канон():
    assert capture.verify_frame(_png(1920, 1080), (1920, 1080)) == (1920, 1080)


def test_verify_frame_падает_на_чужом_размере_с_диагностикой():
    with pytest.raises(CaptureError) as e:
        capture.verify_frame(_png(1900, 1007), (1920, 1080))
    text = str(e.value)
    assert "1900×1007" in text and "1920×1080" in text
    # диагностика обязана говорить, что делать: дисплей и Xvfb
    assert "Xvfb" in text and capture.SIZE_ENV in text


def test_pin_window_code_выбирает_полный_экран_для_канона():
    code = capture.pin_window_code((1920, 1080))
    assert "Vector2i(1920, 1080)" in code
    assert "Window.MODE_FULLSCREEN" in code
    assert "DisplayServer.screen_get_size()" in code
    # меньший размер идёт окном, а не полным экраном
    assert "MODE_WINDOWED" in capture.pin_window_code((1024, 768))


def test_render_manifest_содержит_обязательные_поля():
    meta = {
        "title": "бой", "HEAD": "a" * 40, "База": "b (origin/main)",
        "Дата/время": "2026-10-20 00:00:00 UTC",
        "Инструмент": "game_screenshot", "Фикстура": "res://scenes/battle.tscn",
        "Канонический размер": "1920×1080", "Команда воспроизведения": "pytest ...",
        "Сравнение валидно": "да", "notes": ["окно не закреплено хостом"],
    }
    rows = [{"file": "battle.png", "state": "после", "size": (1920, 1080),
             "bytes": 123, "sha256": "f" * 64}]
    text = capture.render_manifest(meta, rows)
    for needle in ("HEAD", "Фикстура", "Канонический размер", "SHA-256",
                   "battle.png", "f" * 64, "1920×1080", "Оговорка"):
        assert needle in text


def test_reserve_dir_вне_репозитория(tmp_path, monkeypatch):
    monkeypatch.setattr(capture.Path, "home", classmethod(lambda cls: tmp_path))
    out = capture.reserve_dir("shot-test")
    assert out == tmp_path / ".local" / "share" / "sigil-reserve" / "shot-test"
    assert out.is_dir()


# ── съёмка по запросу ──────────────────────────────────────────────────────

CAPTURE_REASON = (
    "съёмка только по запросу: CAPTURE_SCENE=res://... "
    "(см. docs/mvp/CAPTURE-HELPER.md)"
)


@pytest.mark.skipif(not os.environ.get("CAPTURE_SCENE"), reason=CAPTURE_REASON)
def test_capture(mcp):
    scene = os.environ["CAPTURE_SCENE"]
    size = capture.canonical_size()
    label = os.environ.get("CAPTURE_LABEL", "после")
    name = os.environ.get("CAPTURE_NAME", os.path.splitext(os.path.basename(scene))[0])
    out_dir = capture.reserve_dir(os.environ.get("CAPTURE_OUT", "shots"))
    command = (
        f"CAPTURE_SCENE={scene} CAPTURE_LABEL={label} CAPTURE_NAME={name} "
        "CAPTURE_OUT=<каталог> pytest tests/mcp/test_capture.py -q --timeout=900"
    )
    notes = [n for n in [os.environ.get("CAPTURE_NOTE", "").strip()] if n]

    row = capture.capture_scene(mcp, scene, out_dir, name, label, size=size)
    meta = capture.manifest_meta(
        title=f"{label}: {name}", fixture=scene, size=size, command=command, notes=notes,
    )
    manifest = out_dir / "MANIFEST.md"
    block = capture.render_manifest(meta, [row])
    with manifest.open("a", encoding="utf-8") as fh:
        fh.write(block + "\n")
    print(f"CAPTURED {row['path']} {row['size']} {row['sha256']}", flush=True)

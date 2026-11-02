#!/usr/bin/env python3
"""Проверка `check_hero_frames.py` (T-318).

Запуск: /home/user/.venv/map-art/bin/python -m pytest scripts/test_check_hero_frames.py -q
(в общем гейте уровень живёт в `scripts/doc_gates.sh` рядом с провенансом ассетов.)
"""
import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_hero_frames import check, hero_dirs  # noqa: E402

FRAME = "knights_idle_01.png"


def make_hero(sprites: Path, hero: str = "knights", manifest: bool = True,
              frames=(FRAME,)):
    d = sprites / hero
    d.mkdir(parents=True, exist_ok=True)
    body = {"hero": hero, "frames": {}}
    for name in frames:
        (d / name).write_bytes(f"пиксели {name}".encode())
        body["frames"][name] = {
            "track": name.split("_")[1],
            "sha256": hashlib.sha256(f"пиксели {name}".encode()).hexdigest(),
        }
    if manifest:
        (d / "frames_manifest.json").write_text(
            json.dumps(body, ensure_ascii=False), encoding="utf-8")
    return d


def test_комплект_совпадает(tmp_path):
    make_hero(tmp_path)
    assert check(tmp_path) == []


def test_без_манифеста_красно(tmp_path):
    make_hero(tmp_path, manifest=False)
    problems = check(tmp_path)
    assert len(problems) == 1
    assert "frames_manifest.json" in problems[0]
    assert "integrate.py knights" in problems[0]


def test_кадр_перезаписан(tmp_path):
    d = make_hero(tmp_path)
    (d / FRAME).write_bytes("другая пересъёмка".encode())
    problems = check(tmp_path)
    assert len(problems) == 1
    assert FRAME in problems[0] and "не совпадает с манифестом" in problems[0]


def test_лишний_кадр_без_вердикта(tmp_path):
    d = make_hero(tmp_path)
    (d / "knights_idle_02.png").write_bytes("мимо вердикта".encode())
    problems = check(tmp_path)
    assert len(problems) == 1
    assert "knights_idle_02.png" in problems[0]
    assert "без вердикта" in problems[0]


def test_кадр_из_манифеста_пропал(tmp_path):
    d = make_hero(tmp_path)
    (d / FRAME).unlink()
    problems = check(tmp_path)
    assert len(problems) == 1
    assert FRAME in problems[0] and "не на диске" in problems[0]


def test_каталог_без_дорожек_не_трогается(tmp_path):
    """Статичные каталоги ассетов (иконок, юнит-карточек) — не герои."""
    d = tmp_path / "icons"
    d.mkdir(parents=True)
    (d / "sword.png").write_bytes("иконка".encode())
    assert hero_dirs(tmp_path) == []
    assert check(tmp_path) == []


def test_несколько_героев_считаются_раздельно(tmp_path):
    make_hero(tmp_path)
    make_hero(tmp_path, hero="archers", frames=("archers_walk_01.png",))
    (tmp_path / "archers" / "archers_walk_01.png").write_bytes("не то".encode())
    problems = check(tmp_path)
    assert len(problems) == 1 and "archers" in problems[0]

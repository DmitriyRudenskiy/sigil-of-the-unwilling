#!/usr/bin/env python3
"""Машинная проверка конвейера кадров (смена `battle-demo-donor-transfer`).

Две вещи, которые ломает перенос и которые не ловит «модуль импортируется»:

1. Пути. До переноса `ROOT` значил то корень стенда, то корень репозитория.
   Проверка держит инвариант: вывод прогона живёт вне дерева и не в git, а в
   стенд путём может смотреть только `paths.STAND`.
2. Приёмка. Кадр, который не прошёл, обязан быть завернут с причиной — иначе
   «годен» из отчёта ничего не значит.

Запуск: python3 scripts/character_kit/test_character_kit.py
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

import audit_sprites
import gen_clip
import paths


def test_paths() -> None:
    faults = []
    if paths.STAND in paths.OUT.parents:
        faults.append(f"вывод {paths.OUT} снова внутри стенда")
    for name, value in (("gen_clip.CLIPS", gen_clip.CLIPS),
                        ("gen_clip.VERDICTS", gen_clip.VERDICTS),
                        ("audit_sprites.UNITS", audit_sprites.UNITS)):
        if "battle-demo" in str(value) and paths.STAND not in value.parents:
            faults.append(f"{name} смотрит в стенд мимо paths.STAND: {value}")
    if paths.PKG not in paths.RUNS.parents:
        faults.append(f"запись прогонов {paths.RUNS} съехала из пакета")
    ignored = subprocess.run(
        ["git", "-C", str(paths.REPO), "check-ignore", "-q", "character_kit"],
        capture_output=True)
    if ignored.returncode != 0:
        faults.append("вывод character_kit/ не закрыт .gitignore — пиксели поедут в git")
    assert not faults, "; ".join(faults)


def test_verdict() -> None:
    """Сломанный клип — это «брак» с причиной, а не исключение и не «годен»."""
    report = {
        "anim": "idle",
        "corner_before_clip": (250, 250, 250),          # не хромакей
        "audit": {"motion_first_last": 0.4, "sharpness_min": 9.0,
                  "sharpness_median": 10.0, "contact_slide_x": 40,
                  "pivot_slide_x": 3, "chroma_share": 0.02,
                  "chroma_pixels_kept": 400, "flat_white_share": 0.6},
    }
    verdict = gen_clip.verdict(report)
    faults = []
    if not verdict.startswith("брак:"):
        faults.append(f"сломанный клип принят: {verdict}")
    if verdict == "брак:":
        faults.append("вердикт без причины")
    assert not faults, "; ".join(faults)


def test_audit() -> None:
    """Кдр без альфа-канала — нарушение, валидный кадр — чист (проверка не протухла)."""
    faults = []
    with tempfile.TemporaryDirectory() as tmp:
        rgb = Path(tmp) / "rgb.png"
        Image.new("RGB", (512, 512), (10, 20, 30)).save(rgb)
        problems, _ = audit_sprites.check_file(rgb)
        if not problems:
            faults.append("кадр без альфа-канала прошёл приёмку")
        good = Path(tmp) / "good.png"
        image = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        for x in range(200, 320):
            for y in range(160, 440):
                image.putpixel((x, y), (30, 40, 50, 255))
        image.save(good)
        problems, _ = audit_sprites.check_file(good)
        if problems:
            faults.append(f"чистый кадр забракован: {problems}")
    assert not faults, "; ".join(faults)


def main() -> int:
    """Ручной запуск: python3 scripts/character_kit/test_character_kit.py"""
    failed = []
    for check in (test_paths, test_verdict, test_audit):
        try:
            check()
        except AssertionError as fault:
            failed.append(f"{check.__name__}: {fault}")
    for fault in failed:
        print(f"FAIL {fault}")
    print("OK: пути, приёмка" if not failed else f"{len(failed)} проверки упали")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

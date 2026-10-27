"""Хелпер съёмки экрана — визуальная приёмка «экран ↔ макет».

Зачем: снимки «до/после» сравнимы по пикселям только при равном размере кадра,
а размер окна Godot зависит от хоста. Замер 2026-10-20: запуск по умолчанию даёт
то 1900×1007, то 1818×1007; оконный режим зажат полезной областью экрана
(1920×1027 вместо запрошенных 1920×1080); Xvfb в run_tests.sh поднимается
1024×768. Поэтому хелпер: (1) выставляет канонический размер, (2) проверяет
фактический по IHDR снимка, (3) падает при расхождении вместо молчаливой записи
несравнимого кадра.

PNG в git не кладутся (пересоздаваемые бинари; политика хранения в репозитории
ещё не решена): файлы — в `~/.local/share/sigil-reserve/<имя>/`, в тред ревью
идёт манифест текстом вместе с командой воспроизведения.
"""

from __future__ import annotations

import hashlib
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# Кадр = размер вьюпорта проекта (project.godot) и макетов reference/*.png.
CANONICAL_SIZE = (1920, 1080)
# Сколько кадров ждём между праймингом и отчётным снимком (см. capture_scene).
PRIME_SETTLE_FRAMES = 5
SIZE_ENV = "CAPTURE_SIZE"
SCENE_ENV = "CAPTURE_SCENE"
SETUP_ENV = "CAPTURE_SETUP"
# Где искать состояние по голому имени: `CAPTURE_SETUP=inventory_grid` →
# tools/capture/inventory_grid.gd (тот же приём, что `CAPTURE_SCENE` для сцен).
FIXTURE_DIR = Path(__file__).resolve().parents[2] / "tools" / "capture"
PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


class CaptureError(RuntimeError):
    """Съёмка не удалась или кадр недействителен (размер ≠ канон)."""


def parse_size(text: str) -> tuple[int, int]:
    """"1920x1080" → (1920, 1080)."""
    parts = str(text).lower().replace("×", "x").strip().split("x")
    if len(parts) != 2:
        raise CaptureError(f"размер надо задать как ШxВ, получено: {text!r}")
    try:
        width, height = int(parts[0]), int(parts[1])
    except ValueError as e:
        raise CaptureError(f"размер должен быть числом: {text!r}") from e
    if width <= 0 or height <= 0:
        raise CaptureError(f"размер должен быть положительным: {text!r}")
    return width, height


def canonical_size(env: dict[str, str] | None = None) -> tuple[int, int]:
    """Канон кадра: CAPTURE_SIZE или CANONICAL_SIZE."""
    raw = (os.environ if env is None else env).get(SIZE_ENV, "").strip()
    return parse_size(raw) if raw else CANONICAL_SIZE


def png_size(raw: bytes) -> tuple[int, int]:
    """Размер из IHDR — без зависимостей от PIL."""
    if not raw.startswith(PNG_MAGIC):
        raise CaptureError("это не PNG — game_screenshot вернул не изображение")
    if len(raw) < 24:
        raise CaptureError("PNG обрезан — заголовка IHDR не хватает")
    header = raw[16:24]
    return int.from_bytes(header[:4], "big"), int.from_bytes(header[4:], "big")


def sha256_hex(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def pin_window_code(size: tuple[int, int]) -> str:
    """GDScript выставления кадра: канонический размер без ухода в полный экран.

    Рамка без полей (`borderless`) даёт ровно канон: у обычного окна высота
    зажимается менюбаром (1920×1080 превращается в 1920×1027 — замер на macOS).

    `MODE_FULLSCREEN` для канонического размера давать НЕЛЬЗЯ, и это не косметика:
    на macOS полноэкранное окно уезжает в собственный Space, macOS перестаёт просить
    кадры, а `get_viewport().get_texture()` отдаёт первое полноэкранное изображение.
    Следствие хитрое: снимок выглядит правильным (размер канонический, экран
    отрисован) и перестает реагировать на всё, что происходит в дереве. Счёт
    `Engine.get_frames_drawn()` растёт, пикселы — нет. Любой кадр состояния
    (`CAPTURE_SETUP`) при таком пине молча снимается как кадр покоя (замер —
    test_capture.py, урок 2026-10-20: кадры подсреза 3 не отличались от пустого
    каталога, хотя карточки в дереве были видны).
    """
    return (
        "var w = get_window()\n"
        f"var target = Vector2i({size[0]}, {size[1]})\n"
        "if target == DisplayServer.screen_get_size():\n"
        "\tw.mode = Window.MODE_WINDOWED\n"
        "\tw.borderless = true\n"
        "\tw.size = target\n"
        "else:\n"
        "\tw.mode = Window.MODE_WINDOWED\n"
        "\tw.size = target\n"
        "return [w.size.x, w.size.y, w.mode, w.borderless]\n"
    )


def verify_frame(raw: bytes, size: tuple[int, int]) -> tuple[int, int]:
    """Размер снимка обязан равняться канону, иначе снимок недействителен."""
    actual = png_size(raw)
    if actual != tuple(size):
        raise CaptureError(
            f"кадр {actual[0]}×{actual[1]} ≠ канонический {size[0]}×{size[1]} — "
            "снимок недействителен: попиксельное сравнение «до/после» валидно "
            "только при равном размере. Причины: (а) дисплей хоста меньше канона "
            "— канон достигается окном во весь экран, нужен дисплей ровно "
            f"{size[0]}×{size[1]}; (б) прогоны под Xvfb: run_tests.sh поднимает "
            "1024×768, там канон недостижим — поднимите Xvfb "
            f"`-screen 0 {size[0]}x{size[1]}x24` или осознанно снимайте меньшим "
            f"размером через {SIZE_ENV}."
        )
    return actual


def reserve_dir(name: str) -> Path:
    """Каталог снимков вне репозитория: ~/.local/share/sigil-reserve/<имя>."""
    root = Path.home() / ".local" / "share" / "sigil-reserve" / name
    root.mkdir(parents=True, exist_ok=True)
    return root


def git_output(*args: str, cwd: Path | None = None) -> str:
    """Короткая ревизия git или заглушка — манифест не должен падать из-за среды."""
    try:
        out = subprocess.run(
            ("git", *args), cwd=str(cwd) if cwd else None,
            capture_output=True, text=True, timeout=10, check=True,
        )
        return out.stdout.strip()
    except Exception:  # noqa: BLE001 — манифест переживает отсутствие git
        return "?"


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")


def render_manifest(meta: dict[str, Any], rows: list[dict[str, Any]]) -> str:
    """MANIFEST.md установленного формата (см. docs/mvp/CAPTURE-HELPER.md)."""
    lines = [f"# Манифест снимков — {meta.get('title', 'без названия')}", ""]
    for key in (
        "HEAD", "База", "Дата/время", "Инструмент", "Фикстура",
        "Канонический размер", "Команда воспроизведения", "Сравнение валидно",
    ):
        if key in meta:
            lines.append(f"- {key}: `{meta[key]}`")
    lines += ["", "| Файл | Состояние | Разрешение | Байт | SHA-256 |", "| --- | --- | --- | --- | --- |"]
    for row in rows:
        lines.append(
            f"| `{row['file']}` | {row.get('state', '?')} | {row['size'][0]}×{row['size'][1]} "
            f"| {row['bytes']} | `{row['sha256']}` |"
        )
    lines.append("")
    for note in meta.get("notes", []):
        lines.append(f"- Оговорка: {note}")
    lines.append("")
    return "\n".join(lines)


def setup_code(env: dict[str, str] | None = None) -> str:
    """Код, доводящий экран до нужного состояния, из `CAPTURE_SETUP`.

    Значение — либо инлайн-GDScript, либо `@путь/к/файлу` (для многострочного кода:
    переменная окружения с переносами воспроизводится хуже файла). Пусто = состояние
    не менять, то есть поведение вызывающего не меняется вовсе.

    Зачем: часть кадров существует только в состоянии, которого нет в `_ready`
    (выбранная карточка каталога, открытая легаси-панель). Снимать «сцену как есть»
    и называть это кадром состояния — значит снять другой кадр.
    """
    raw = str((env if env is not None else os.environ).get(SETUP_ENV, "")).strip()
    if not raw:
        return ""
    # Голое имя фикстуры (`CAPTURE_SETUP=inventory_grid`) — тот же приём, каким
    # `CAPTURE_SCENE` ищет сцену, и та же ловушка, что описана в CAPTURE-HELPER:
    # без резолвинга строка уходит в game_eval как выражение и падает «Failed to
    # compile GDScript (error 43)», где искать надо не код, а вызов. Инлайн-код от
    # имени отличает то, что на диске лежит файл: `tools/capture/<имя>.gd` или
    # указанный путь. Совпадений нет — как и раньше, это инлайн-GDScript.
    if "\n" not in raw and not raw.startswith("@"):
        guess = Path(raw).expanduser() if raw.endswith(".gd") \
            else FIXTURE_DIR / f"{raw}.gd"
        if guess.is_file():
            return guess.read_text(encoding="utf-8").strip()
    if raw.startswith("@"):
        path = Path(raw[1:]).expanduser()
        if not path.is_file():
            raise CaptureError(f"{SETUP_ENV}={raw}: файла нет — {path}")
        return path.read_text(encoding="utf-8").strip()
    return raw


def capture_scene(mcp: Any, scene: str, out_dir: Path, name: str,
                  state: str, size: tuple[int, int] | None = None,
                  settle_frames: int = 30, setup_code: str = "") -> dict[str, Any]:
    """Снимает сцену каноническим кадром; пишет PNG, возвращает строку манифеста."""
    size = tuple(size or canonical_size())
    mcp.run_scene(scene)
    mcp.wait_ready()
    # Кадр обязан принадлежать заказанной сцене. Невалидный `CAPTURE_SCENE`
    # (голое имя `inventory_grid` вместо res://…/artifact_inventory_screen.tscn)
    # не падает: в current_scene остаётся ПРЕДЫДУЩАЯ сцена, снимок сходится с ней
    # байт в байт, а манифест утверждает фикстуру. Замер 2026-10-27: три «разных»
    # кадра (main_menu, inventory, inventory_grid) сошлись одним sha256 965218a7…,
    # и все три были меню.
    running = str(mcp.execute_code(
        "var s = get_tree().current_scene\n"
        "return str(s.scene_file_path) if s else '<нет текущей сцены>'"))
    if running != scene:
        raise CaptureError(
            f"{SCENE_ENV}={scene}: в current_scene «{running}» — заказанная сцена не "
            "загружена (нужен путь вида res://scenes/…/x.tscn, голое имя не резолвится)")
    mcp.wait_frames(20)
    mcp.execute_code(pin_window_code(size))
    setup_result: Any = None
    if setup_code:
        # состояние ставится до усаживания: один settle покрывает и пин, и состояние
        setup_result = mcp.execute_code(setup_code)
    mcp.wait_frames(settle_frames)
    # Прайминг: первый после пина окна снимок отдаёт УСТАРЕВШУЮ текстуру вьюпорта.
    # Замер (T-188, Linux/Xvfb): кадр состояния `campaign_sign_chronicle_open.gd`
    # сошёл байт в байт с кадром «до состояния» (sha256 92e8c588… у обоих), хотя
    # следом за съёмкой тот же процесс показывал открытую хронику. Симптом коварен:
    # размер канонический, сцена отрисована, состояние в дереве — вердикт по такому
    # кадру неверный, а зелёный. Ровно тот же класс брака, что описан в
    # `pin_window_code` для полноэкранного режима на macOS, — поэтому первый снимок
    # выбрасывается, а отчётным становится второй, снятый после него.
    mcp.screenshot()
    mcp.wait_frames(PRIME_SETTLE_FRAMES)
    raw = mcp.screenshot()
    actual = verify_frame(raw, size)
    path = Path(out_dir) / f"{name}.png"
    path.write_bytes(raw)
    return {
        "file": path.name, "state": state, "size": actual,
        "bytes": len(raw), "sha256": sha256_hex(raw), "path": path,
        # Отчёт кода состояния: кадр без задокументированного состояния — только
        # пиксели. Замер 2026-10-25: кадр «плита Знака» сошёлся байт в байт с
        # кадром без плиты, потому что состояние не применилось, а манифест
        # хранил лишь sha256 кода.
        "setup_result": setup_result,
    }


def manifest_meta(title: str, fixture: str, size: tuple[int, int],
                  command: str, notes: list[str] | None = None,
                  comparison_valid: str = "да (одинаковый канонический размер)") -> dict[str, Any]:
    """Шапка манифеста: HEAD, база, время, инструмент, фикстура, команда."""
    return {
        "title": title,
        "HEAD": git_output("rev-parse", "HEAD"),
        "База": git_output("rev-parse", "--short", "origin/main") + " (origin/main)",
        "Дата/время": utc_now(),
        "Инструмент": "game_screenshot через MCP / живой Godot (без --headless)",
        "Фикстура": fixture,
        "Канонический размер": f"{size[0]}×{size[1]}",
        "Команда воспроизведения": command,
        "Сравнение валидно": comparison_valid,
        "notes": list(notes or []),
    }

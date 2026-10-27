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


@pytest.fixture(autouse=True)
def _канон_кадра_не_наследуется_из_оболочки(request, monkeypatch):
    """Подставные кадры этого файла — 1920×1080, поэтому чужой `CAPTURE_SIZE` в
    окружении прогона красил их как «снимок недействителен» (замер 2026-10-26:
    5 красных кейсов при `CAPTURE_SIZE=1280x720` в той же команде). Съёмка по
    запросу `test_capture` — единственная, кому размер вызывающего нужен: только
    так снимают неканон (mvp-ui-flow 4.1: поле боя на 1280×720)."""
    if request.node.name == "test_capture":
        return
    monkeypatch.delenv(capture.SIZE_ENV, raising=False)


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


def test_pin_window_code_не_уходит_в_полный_экран():
    """Полноэкранный пин на macOS вешает present — снимок замирает и врёт о состоянии.

    Окно уезжает в собственный Space, macOS перестаёт просить кадры, а
    `get_texture()` отдаёт первый полноэкранный кадр: размер канонический, картинка
    правильная, рантайм-правки не видны. Канон поэтому дают рамкой без полей: у
    обычного окна высоту отъедает менюбар (1920×1027 вместо 1920×1080 — замер).
    """
    code = capture.pin_window_code((1920, 1080))
    assert "Vector2i(1920, 1080)" in code
    assert "DisplayServer.screen_get_size()" in code
    assert "MODE_FULLSCREEN" not in code
    assert "borderless = true" in code
    # меньший размер — тоже окно, но уже с полями (канон не требуется)
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


def test_setup_code_пусто_без_переменной():
    assert capture.setup_code({}) == ""
    assert capture.setup_code({capture.SETUP_ENV: "   "}) == ""


def test_setup_code_инлайн_и_срезает_края():
    assert capture.setup_code({capture.SETUP_ENV: "\n  pass\n"}) == "pass"


def test_setup_code_читает_файл_по_собаке(tmp_path):
    src = tmp_path / "setup.gd"
    src.write_text("print(1)\n", encoding="utf-8")
    assert capture.setup_code({capture.SETUP_ENV: f"@{src}"}) == "print(1)"


def test_setup_code_падает_на_несуществующем_файле(tmp_path):
    missing = tmp_path / "nope.gd"
    with pytest.raises(CaptureError) as e:
        capture.setup_code({capture.SETUP_ENV: f"@{missing}"})
    assert capture.SETUP_ENV in str(e.value) and "файла нет" in str(e.value)


def test_setup_code_ищет_голое_имя_в_tools_capture(tmp_path, monkeypatch):
    """`CAPTURE_SETUP=inventory_grid` — состояние, а не GDScript-выражение.

    Без резолвинга строка уходила в game_eval и падала «Failed to compile
    GDScript (error 43)» — симптом, указывающий на код фикстуры, которого там нет.
    """
    fixtures = tmp_path / "tools" / "capture"
    fixtures.mkdir(parents=True)
    (fixtures / "foo.gd").write_text("print(2)\n", encoding="utf-8")
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(capture, "FIXTURE_DIR", fixtures)
    assert capture.setup_code({capture.SETUP_ENV: "foo"}) == "print(2)"
    assert capture.setup_code({capture.SETUP_ENV: "tools/capture/foo.gd"}) == "print(2)"
    # Инлайн остаётся инлайном: файла `pass.gd` нет, код не подменяется.
    assert capture.setup_code({capture.SETUP_ENV: "pass"}) == "pass"
    # Несуществующий путь с расширением — не молчаливый инлайн-код.
    with pytest.raises(CaptureError):
        capture.setup_code({capture.SETUP_ENV: "@tools/capture/nope.gd"})


class _RecordingMcp:
    """Мок MCP-клиента: пишет порядок вызовов, отдаёт валидный PNG на скриншот."""

    def __init__(self) -> None:
        self.calls: list[str] = []
        self.scene = ""

    def run_scene(self, scene: str) -> None:
        # Предзаданный `scene` остаётся: так мок моделирует «заказали одно,
        # в current_scene другое» (см. test_capture_scene_не_пишет_кадр_чужой_сцены).
        self.scene = self.scene or scene
        self.calls.append("run_scene")

    def wait_ready(self) -> None:
        self.calls.append("wait_ready")

    def wait_frames(self, n: int) -> None:
        self.calls.append(f"wait_frames:{n}")

    def execute_code(self, code: str):
        self.calls.append(f"execute::{code.strip()}")
        # Гард сцены из capture_scene спрашивает путь current_scene.
        return self.scene if "scene_file_path" in code else None

    def screenshot(self) -> bytes:
        self.calls.append("screenshot")
        return _png(*capture.CANONICAL_SIZE)

    def index(self, needle: str) -> int:
        for i, call in enumerate(self.calls):
            if needle in call:
                return i
        raise AssertionError(f"вызов с {needle!r} не записан: {self.calls}")


def test_capture_scene_не_пишет_кадр_чужой_сцены(tmp_path):
    """Кадр принадлежит заказанной сцене, а не той, что осталась в дереве.

    Голое имя в `CAPTURE_SCENE` не роняет съёмку: run_scene не находит сцену,
    current_scene остаётся предыдущей, и снимок сходится с ней байт в байт
    (замер 2026-10-27: три «разных» кадра — один sha256 965218a7…, все меню).
    """
    mcp = _RecordingMcp()
    mcp.scene = "res://scenes/main_menu.tscn"
    with pytest.raises(CaptureError) as e:
        capture.capture_scene(mcp, "inventory_grid", tmp_path, "x", "тест")
    assert "current_scene" in str(e.value) and "main_menu" in str(e.value)
    assert "screenshot" not in mcp.calls, "кадр чужой сцены не должен писаться"


def test_capture_scene_ставит_состояние_после_пина_но_до_скриншота(tmp_path):
    mcp = _RecordingMcp()
    row = capture.capture_scene(
        mcp, "res://scenes/x.tscn", tmp_path, "x", "тест",
        setup_code="select_card()\n",
    )
    # порядок: пин окна → состояние → усаживание → скриншот
    assert mcp.index("borderless = true") < mcp.index("select_card()") < mcp.index("screenshot")
    assert mcp.index("select_card()") < mcp.index("screenshot")
    assert mcp.calls.index("wait_frames:30") > mcp.index("select_card()"), \
        "состояние должно успеть усесться до снимка"
    assert row["sha256"] == capture.sha256_hex(_png(*capture.CANONICAL_SIZE))


class _ReportingMcp(_RecordingMcp):
    """Мок, возвращающий словарь из кода состояния (так делает живой `execute_code`)."""

    def execute_code(self, code: str):
        running = super().execute_code(code)  # пишет вызов и отвечает гарду сцены
        return {"ok": True, "plaque_visible": True} if "select_card()" in code else running


def test_capture_scene_отдаёт_отчёт_кода_состояния(tmp_path):
    """Манифест обязан хранить не только sha256 кода, но и то, что он вернул."""
    mcp = _ReportingMcp()
    row = capture.capture_scene(
        mcp, "res://scenes/x.tscn", tmp_path, "x", "тест", setup_code="select_card()\n",
    )
    assert row["setup_result"] == {"ok": True, "plaque_visible": True}


def test_capture_scene_без_кода_состояния_не_выдумывает_отчёт(tmp_path):
    mcp = _ReportingMcp()
    row = capture.capture_scene(mcp, "res://scenes/x.tscn", tmp_path, "x", "тест")
    assert row["setup_result"] is None


class _TwoFrameMcp(_RecordingMcp):
    """Мок, отдающий разный рисунок на каждом снимке: видно, какой кадр пошёл в отчёт."""

    def __init__(self) -> None:
        super().__init__()
        self.shots: int = 0

    def screenshot(self) -> bytes:
        self.calls.append("screenshot")
        self.shots += 1
        return _png(*capture.CANONICAL_SIZE) + (b"" if self.shots == 1 else b"live")


def test_capture_scene_праймит_текстуру_до_отчётного_кадра(tmp_path):
    """T-188: первый после пина снимок — устаревшая текстура, он не может быть отчётным.

    Замер: кадр состояния совпал байтами с кадром «до состояния»; живой кадр
    получался только вторым снимком подряд.
    """
    mcp = _TwoFrameMcp()
    row = capture.capture_scene(
        mcp, "res://scenes/x.tscn", tmp_path, "x", "тест", setup_code="select_card()\n",
    )
    shots = [i for i, call in enumerate(mcp.calls) if call == "screenshot"]
    assert len(shots) == 2, f"ожидался прайминг + отчётный кадр: {mcp.calls}"
    assert mcp.calls[shots[0] + 1] == f"wait_frames:{capture.PRIME_SETTLE_FRAMES}"
    assert shots[0] > mcp.index("select_card()"), "прайминг — после состояния"
    # Отчётный кадр — второй: именно его байты уходят в sha256 манифеста.
    assert row["sha256"] == capture.sha256_hex(_png(*capture.CANONICAL_SIZE) + b"live")


def test_capture_scene_без_состояния_не_вызывает_лишнего(tmp_path):
    mcp = _RecordingMcp()
    capture.capture_scene(mcp, "res://scenes/x.tscn", tmp_path, "x", "тест")
    executes = [c for c in mcp.calls if c.startswith("execute::")]
    # Гард сцены + пин окна; кода состояния нет ни в одном вызове.
    assert len(executes) == 2 and "borderless = true" in executes[1], mcp.calls
    assert not any("select_card()" in c for c in executes), mcp.calls


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
    setup = capture.setup_code()
    command = (
        f"CAPTURE_SCENE={scene} CAPTURE_LABEL={label} CAPTURE_NAME={name} "
        f"CAPTURE_OUT=<каталог>{' CAPTURE_SETUP=… ' if setup else ''}"
        "pytest tests/mcp/test_capture.py -q --timeout=900"
    )
    notes = [n for n in [os.environ.get("CAPTURE_NOTE", "").strip()] if n]
    if setup:
        # кадр состояния без кода состояния невоспроизводим: кодируем его в манифест
        digest = capture.sha256_hex(setup.encode("utf-8"))[:8]
        notes.append(
            f"{capture.SETUP_ENV}: {len(setup.splitlines())} строк GDScript, "
            f"sha256:{digest} — кадр снят после этого кода, не сразу после загрузки сцены"
        )

    row = capture.capture_scene(mcp, scene, out_dir, name, label, size=size,
                                setup_code=setup)
    if setup and row.get("setup_result") is not None:
        # Отчёт кода состояния идёт в манифест: без него кадр — только пиксели,
        # а «состояние применилось» остаётся верой (урок 2026-10-25: кадр плиты
        # совпал байт в байт с кадром без плиты).
        notes.append(f"{capture.SETUP_ENV} вернул: {row['setup_result']}")
    meta = capture.manifest_meta(
        title=f"{label}: {name}", fixture=scene, size=size, command=command, notes=notes,
    )
    manifest = out_dir / "MANIFEST.md"
    block = capture.render_manifest(meta, [row])
    with manifest.open("a", encoding="utf-8") as fh:
        fh.write(block + "\n")
    print(f"CAPTURED {row['path']} {row['size']} {row['sha256']}", flush=True)

"""Тесты проверщика провенанса (T-261).

Проверщик — часть документальных гейтов (`scripts/doc_gates.sh`), но до 2026-10-29
у него не было теста: он молча краснел на 201 ассете, а «зелёный провенанс»
значился в задачах смен, которых он никогда не касался. Тест держит отношения, на
которых держится и вывод: нет строки → RED, классовая строка покрывает каталог,
поимённый каталог классовой строкой не покрывается, «красный» статус и строка без
файла краснеют, §«Снятые позиции» не проверяется, объявленный генератор обязан
существовать.
"""
import importlib.util
import os
import pathlib

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location(
    "cap_mod", ROOT / "scripts" / "check_asset_provenance.py")
cap_mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cap_mod)

HEADER = ("| Путь | Кто сделал / откуда | Из чего | Права | Статус |\n"
          "|---|---|---|---|---|\n")
ICONS = "| `game/assets/icons/` | кто | что | права | неизвестно |\n"
SPRITES = "| `game/assets/sprites/` | кто | что | права | жёлтый |\n"


@pytest.fixture
def tree(tmp_path, monkeypatch):
    """Синтетика: icons/{a,b}.png + sprites/c.png; вызов — тело §«Классы»."""
    assets = tmp_path / "game" / "assets"
    (assets / "icons").mkdir(parents=True)
    (assets / "icons" / "a.png").write_bytes(b"x")
    (assets / "icons" / "b.png").write_bytes(b"x")
    (assets / "sprites").mkdir()
    (assets / "sprites" / "c.png").write_bytes(b"x")
    reg = assets / "PROVENANCE.md"
    monkeypatch.setattr(cap_mod, "ROOT", tmp_path)
    monkeypatch.setattr(cap_mod, "ASSETS", assets)
    monkeypatch.setattr(cap_mod, "REGISTRY", reg)
    # индекс git вне репо недоступен → генераторы проверяются по диску tmp_path
    monkeypatch.setattr(cap_mod, "tracked_files", lambda: None)

    def write(body):
        reg.write_text("---\ntitle: t\n---\n\n## Классы\n\n" + HEADER + body + "\n",
                       encoding="utf-8")
        return cap_mod.main()
    return write


def test_no_row_is_red(tree, capsys):
    assert tree("") == 1
    assert "нет строки провенанса: game/assets/icons/a.png" in capsys.readouterr().out


def test_class_row_covers_directory(tree, capsys):
    assert tree(ICONS + SPRITES) == 0
    assert "3/3 ассетов покрыто" in capsys.readouterr().out


def test_named_directory_ignores_class_row(tree, capsys):
    """Каталог с файловой строкой — поимённый: новый файл обязан получить свою."""
    body = ICONS + "| `game/assets/icons/a.png` | кто | что | права | жёлтый |\n" \
        + SPRITES
    assert tree(body) == 1
    out = capsys.readouterr().out
    assert "нет строки провенанса: game/assets/icons/b.png" in out
    assert "a.png" not in out.split("ПРОВЕНАНС")[1]


def test_red_status_is_red(tree, capsys):
    body = "| `game/assets/icons/` | кто | что | права | красный |\n" + SPRITES
    assert tree(body) == 1
    assert "статус «красный»" in capsys.readouterr().out


def test_row_without_file_is_red(tree, capsys):
    body = ICONS + SPRITES + "| `game/assets/ghost/` | кто | что | права | жёлтый |\n"
    assert tree(body) == 1
    assert "строка реестра без каталога: game/assets/ghost/" in capsys.readouterr().out


def test_withdrawn_section_is_not_checked(tree):
    """§«Снятые позиции» — записи об удалённых файлах, проверять нечего."""
    body = ICONS + SPRITES
    tail = "- `game/assets/icons/gone.png` — удалён, след держит проза\n"
    reg = cap_mod.REGISTRY
    reg.write_text("---\ntitle: t\n---\n\n## Классы\n\n" + HEADER + body
                   + "\n## Снятые позиции\n\n" + tail, encoding="utf-8")
    assert cap_mod.main() == 0


def test_walk_counts_only_media(tmp_path, monkeypatch):
    """JSON/`.gd`/`.tres` — авторский код репо, в знаменатель не входят."""
    assets = tmp_path / "game" / "assets"
    (assets / "data").mkdir(parents=True)
    (assets / "data" / "x.json").write_text("{}")
    (assets / "data" / "y.tres").write_text("[1]")
    (assets / "data" / "z.png").write_bytes(b"x")
    monkeypatch.setattr(cap_mod, "ASSETS", assets)
    assert sorted(os.path.basename(p) for p in cap_mod.walk_assets()) == ["z.png"]


# --- объявленный генератор обязан существовать (D12) -------------------------------
# До 2026-11-07 провенанс ссылался на `scripts/ui_kit/build_round_button.py`, которого
# никогда не было (файл жил в `game/scripts/ui_kit/`), и на снятый
# `game/tools/recolor_button_textures.py`. Оба проходили молча.

ROWS = ICONS + SPRITES


def test_dead_generator_in_registry_is_red(tree, capsys):
    body = ROWS + ("| `game/assets/ui/x/` | генератор репо `game/tools/gone.py` "
                   "| что | права | чисто |\n")
    assert tree(body) == 1
    out = capsys.readouterr().out
    assert ("объявленный генератор не в индексе: game/tools/gone.py "
            "(объявлен в PROVENANCE.md)") in out


def test_live_generator_is_green(tree, capsys):
    body = ROWS + ("| `game/assets/ui/x/` | генератор репо `game/tools/gen.py` "
                   "| что | права | чисто |\n")
    (cap_mod.ASSETS / "ui" / "x").mkdir(parents=True)
    (cap_mod.ROOT / "game" / "tools").mkdir(parents=True)
    (cap_mod.ROOT / "game" / "tools" / "gen.py").write_text("#\n", encoding="utf-8")
    assert tree(body) == 0
    assert "генератор" not in capsys.readouterr().out


def test_dead_generator_in_manifest_is_red(tree, capsys):
    """Поле `generator` в MANIFEST — машинное, оно обязано вести на файл репо."""
    manifest = cap_mod.ASSETS / "ui" / "widgets"
    manifest.mkdir(parents=True)
    (manifest / "MANIFEST.json").write_text(
        '{"generator": "scripts/ui_kit/build_round_button.py"}', encoding="utf-8")
    assert tree(ROWS) == 1
    assert ("объявленный генератор не в индексе: "
            "scripts/ui_kit/build_round_button.py "
            "(объявлен в game/assets/ui/widgets/MANIFEST.json)") in capsys.readouterr().out


def test_names_and_external_tools_are_not_paths(tree, capsys):
    """Имя без слэша — это имя, а не путь; «krea2 (ComfyUI)» — внешний инструмент."""
    body = ROWS + ("| `game/assets/ui/x/` | comfyui krea2 (ComfyUI) (+ `gen_other.gd`) "
                   "| что | права | чисто |\n")
    (cap_mod.ASSETS / "ui" / "x").mkdir(parents=True)
    manifest = cap_mod.ASSETS / "ui" / "hero"
    manifest.mkdir(parents=True)
    (manifest / "MANIFEST.json").write_text(
        '{"files": [{"file": "a.png", '
        '"generator": "krea2 (ComfyUI) / qwen-image-text-to-image"}]}', encoding="utf-8")
    assert tree(body) == 0
    assert "генератор" not in capsys.readouterr().out


"""Тесты сверщика состава корня (repo-structure-cleanup, задача 7.3).

Сверщик судит индекс, а не диск, поэтому тесту не нужен git и не нужен временный
репозиторий: `check()` — чистая функция над списком путей и списком правил.
Тест держит ровно те границы, на которых сверщик был написан:

  - чистое дерево проходит;
  - посторонний каталог в корне падает — ради этого сверщика и заводили;
  - `game/assets/artifacts/` НЕ падает: слово `artifacts` перегружено, иконочный
    носитель живёт в Godot-проекте и к выводу прогонов отношения не имеет;
  - правило, спрятанное в `.git/info/exclude`, падает: его не видит никто, кроме
    машины, где его написали;
  - `.py` внутри `game/` падает вне `tools/` и `tests/`;
  - `.gd` в корне Godot-проекта падает, в `game/tools/` — нет.
"""
import importlib.util
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location(
    "crl_mod", ROOT / "scripts" / "check_repo_layout.py")
crl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(crl)

# Минимальное «чистое дерево»: по одному носителю из перечня + то, что падать не
# должно ни при каком раскладе.
CLEAN = [
    ".github/workflows/ci.yml",
    ".gitignore",
    ".pi/prompts/opsx-apply.md",
    "AGENTS.md",
    "README.md",
    "docs/00-INDEX.md",
    "game/assets/artifacts/sword.png",
    "game/assets/ui/widgets/MANIFEST.json",
    "game/project.godot",
    "game/scripts/main.gd",
    "game/tests/smoke/test_compile_all.gd",
    "game/tools/gen_resource_icons.py",
    "game/tools/ui_kit/build_ui_kit.py",
    "openspec/changes/repo-structure-cleanup/tasks.md",
    "reference/INDEX.md",
    "scripts/check_repo_layout.py",
]


def test_clean_tree_passes():
    assert crl.check(CLEAN, []) == {}


def test_foreign_directory_in_root_is_red():
    got = crl.check(CLEAN + ["notebooks/experiment.ipynb"], [])
    assert got == {"чужой носитель в корне": ["notebooks/experiment.ipynb"]}


def test_assets_artifacts_is_not_output_runs():
    """`game/assets/artifacts/` — носитель иконок, а не вывод прогонов.

    Под выводом прогонов понимается `artifacts/` **верхнего уровня**: правило
    сверяет первый сегмент пути, иначе живые ассеты краснели бы пачкой.
    """
    assert crl.check(["game/assets/artifacts/sword.png"], []) == {}
    got = crl.check(["artifacts/gate.log"], [])
    assert got["отслеживаемый файл под выводом прогонов"] == ["artifacts/gate.log"]


def test_rule_hidden_in_git_exclude_is_red():
    """`.reserve/` прятался в `.git/info/exclude` — для свежего клона он не спрятан."""
    got = crl.check(CLEAN, [".reserve/"])
    assert got == {"правило в .git/info/exclude": [".reserve/"]}


def test_python_inside_game_outside_tools_is_red():
    got = crl.check(CLEAN + ["game/scripts/build_ui.py"], [])
    assert got == {".py внутри game/ вне tools/ и tests/": ["game/scripts/build_ui.py"]}
    # два разрешённых дома — не красные
    assert crl.check(["game/tools/x.py", "game/tests/x.py"], []) == {}


def test_gd_in_godot_project_root_is_red():
    """Корень Godot-проекта — `game/<имя>` без слэша; `game/tools/` — не корень."""
    got = crl.check(CLEAN + ["game/dbg_stats.gd"], [])
    assert got == {".gd в корне Godot-проекта": ["game/dbg_stats.gd"]}
    assert crl.check(["game/tools/dbg_stats.gd"], []) == {}


def test_banned_boilerplate_returning_is_red():
    """Разрез снял бойлплейт; возврат одного из них — это RED, а не «файл нужен»."""
    got = crl.check(CLEAN + ["LICENSE", "doc/save-matrix.md"], [])
    assert got["удалённый носитель вернулся"] == ["LICENSE", "doc/save-matrix.md"]
    # снятый бойлплейт чужой корню тоже, и сверщик не выбирает одно из двух:
    # «вернулось то, что удалено» краснеть интереснее, чем «такого тут не было»


def test_pending_entries_are_not_red():
    """`battle-demo/`, `tmp/`, `.reserve/`, `data/` помечены «ждёт решения» и
    красным не являются. Кроме одного: отслеживаемый файл под `data/` падает всё
    равно — какое бы решение ни приняла задача, вывод прогонов дерево не несёт."""
    assert crl.check(CLEAN + ["battle-demo/main.gd", "tmp/.gitignore",
                              ".reserve/x"], []) == {}
    assert crl.check(["data/x.bin"], [])["отслеживаемый файл под выводом "
                                          "прогонов"] == ["data/x.bin"]


def test_every_allowed_entry_has_a_status():
    """Статус обязателен: пустая строка читается как «разрешено навсегда»."""
    assert all(v.strip() for v in crl.ALLOWED.values())
    assert sum(1 for v in crl.ALLOWED.values() if "ждёт решения" in v) == 4

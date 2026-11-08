#!/usr/bin/env python3
"""Сверка состава корня репозитория с перечнем «дома» (repo-structure-cleanup).

Зачем. Разрез 2026-11-09 вычистил корень из 12 мусорных носителей — `doc/`
(исчезнувший каталог-носитель матрицы), `tools/spellbook_sheets/`,
`prototypes/battle-hud/index.html`, пять юридических бойлплейтов, вывод прогонов,
лабораторию в корне. Всё это наросло за месяцы молча, потому что краснеть было
некому: каталог появляется первым коммитом, и с этого момента он «часть проекта».
Без сверщика состав корня снова расползётся к следующему аудиту — тот же класс
тишины, что с потерянной матрицей сейвов (T-301) и с осиротевшими `.uid`.

Отдельно: правило игнорирования, живущее в `.git/info/exclude`, не видит никто,
кроме машины, где его написали. `.reserve/` прятался именно там, и для свежего
клона он не спрятан. Поэтому exclude проверяется на посторонние правила.

Правила (каждое печатает строку, молчание = RED по D-265-семейству):
  1. каждый элемент индекса верхнего уровня — из перечня ниже;
  2. под выводом прогонов (`artifacts/`, `data/`, `concept_art/`) нет ни одного
     отслеживаемого файла — дерево не обязано нести то, что переснимается;
  3. нет несущих носителей, которые этот разрез удалил: `doc/`, `tools/`,
     `prototypes/`, `LICENSE`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
     `CONTRIBUTING.md`, `.editorconfig`, `CHANGELOG.md` в корне;
  4. в `game/` нет `.py` вне `game/tools/` и `game/tests/` — Python внутри
     Godot-проекта живёт только в двух местах, иначе он попадает в чужой неймспейс;
  5. в корне Godot-проекта (`game/`) нет `.gd` — файл без дома теряет и покрытие
     гейтом, и пару `.uid` по смыслу;
  6. `.git/info/exclude` не содержит ни одного правила (только комментарии).

Область — индекс (`git ls-files`), как в ci2_checkers: в CI checkout = чистое
дерево = индекс. Рабочие помойки (`tmp/` на диске, `.DS_Store`) не проверяются:
их судит `.gitignore`.

Выход: 0 — расхождений нет; 1 — есть. Запуск из корня репо:
    python3 scripts/check_repo_layout.py
"""
from __future__ import annotations

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Состав корня. Статус обязателен: «ждёт решения» — не «разрешено навсегда»,
# а «красным не является, пока открыт вопрос». Снимается вместе с решением.
ALLOWED: dict[str, str] = {
    ".github": "CI",
    ".gitignore": "общие правила игнорирования (единственный носитель правил)",
    ".pi": "проектные навыки агента",
    "AGENTS.md": "инструкции агентам",
    "README.md": "вход в проект",
    "docs": "Obsidian-хранилище документации",
    "game": "Godot-проект",
    "openspec": "спецификации и изменения",
    "scripts": "репозиторные гейты и сверщики (host-Python)",
    # — ждёт решения -------------------------------------------------------
    "battle-demo": "ждёт решения (Q-M поднят в docs/QUESTIONS.md)",
    "tmp": "ждёт решения (в индексе только .gitignore-заглушка)",
    ".reserve": "ждёт решения (вывод, в индексе файлов нет)",
    "data": "ждёт решения (сиротое хранилище OpenViking, 0 файлов в индексе)",
}

# Вывод прогонов: отслеживаемых файлов тут быть не может ни при каком решении.
OUTPUT_DIRS = ("artifacts", "data", "concept_art")

# Несущие носители, удалённые этим разрезом. Возврат одного из них = RED.
BANNED_ROOT = (
    "doc", "tools", "prototypes",
    "LICENSE", "SECURITY.md", "CODE_OF_CONDUCT.md", "CONTRIBUTING.md",
    ".editorconfig", "CHANGELOG.md",
)

# Python имеет право жить внутри Godot-проекта только здесь.
PY_ALLOWED_PREFIXES = ("game/tools/", "game/tests/")


def tracked_paths() -> list[str]:
    out = subprocess.run(["git", "ls-files"], cwd=ROOT,
                         capture_output=True, text=True, check=True)
    return out.stdout.splitlines()


def exclude_rules() -> list[str]:
    """Правила из .git/info/exclude (пустые строки и комментарии — не правила)."""
    path = ROOT / ".git" / "info" / "exclude"
    if not path.exists():
        return []
    return [ln.strip() for ln in path.read_text(encoding="utf-8").splitlines()
            if ln.strip() and not ln.strip().startswith("#")]


def check(paths: list[str], exclude: list[str]) -> dict[str, list[str]]:
    res: dict[str, list[str]] = {
        "чужой носитель в корне": [],
        "отслеживаемый файл под выводом прогонов": [],
        "удалённый носитель вернулся": [],
        ".py внутри game/ вне tools/ и tests/": [],
        ".gd в корне Godot-проекта": [],
        "правило в .git/info/exclude": [],
    }

    for p in paths:
        top = p.split("/", 1)[0]
        if top not in ALLOWED:
            res["чужой носитель в корне"].append(p)
        for out_dir in OUTPUT_DIRS:
            if top == out_dir:
                res["отслеживаемый файл под выводом прогонов"].append(p)
        if top in BANNED_ROOT:
            res["удалённый носитель вернулся"].append(p)
        if p.startswith("game/") and p.endswith(".py") \
                and not p.startswith(PY_ALLOWED_PREFIXES):
            res[".py внутри game/ вне tools/ и tests/"].append(p)
        # «Корень Godot-проекта» — это game/<имя> без слэша; не путать с корнем
        # репозитория, где .gd быть не может в принципе (см. правило 1).
        if p.startswith("game/") and p.count("/") == 1 and p.endswith(".gd"):
            res[".gd в корне Godot-проекта"].append(p)

    for rule in exclude:
        res["правило в .git/info/exclude"].append(rule)

    return {k: sorted(set(v)) for k, v in res.items() if v}


def main() -> int:
    problems = check(tracked_paths(), exclude_rules())
    if not problems:
        print(f"РАСПОЛОЖЕНИЕ: корень в перечне ({len(ALLOWED)} носителей), "
              "вывод прогонов пуст, exclude чист")
        return 0
    for kind, items in problems.items():
        print(f"RED: {kind} ({len(items)}):")
        for it in items[:20]:
            print(f"  {it}")
        if len(items) > 20:
            print(f"  … ещё {len(items) - 20}")
    return 1


if __name__ == "__main__":
    sys.exit(main())

"""Тесты сверщика `doc/SAVE_MATRIX.md` (`check_save_matrix.py`).

Зачем тесты самому сверщику (та же логика, что у `test_check_hero_layout_map.py`):
реестр покрытия — это список ссылок, а список без проверки ссылок — это
следующая потерянная матрица. Прошлая (`save-load-coverage-expansion`, 16 строк)
умерла именно так: файл удалили в `5f412a37`, ссылка спеки осталась живой, а
краснеть было некому (T-301). Каждое правило сверщика обязано уметь покраснеть —
иначе оно молчит зелёным и ничего не обязывает.

Запуск: `python3 -m pytest scripts/test_check_save_matrix.py -q`
(системный `python3` pytest не имеет — только venv MCP, см. AGENTS.md).
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_save_matrix as matrix  # noqa: E402

REAL_DOC = matrix.DOC.read_text(encoding="utf-8")
IDX = matrix.index_basenames()


def problems(doc_text: str, tmp_path: Path | None = None,
             idx: dict | None = None) -> dict[str, list[str]]:
    return matrix.check(doc_text, IDX if idx is None else idx,
                        tmp_path if tmp_path is not None else matrix.DOC_DIR)


def tmp_doc(tmp_path: Path, text: str) -> Path:
    (tmp_path / "SAVE_MATRIX.md").write_text(text, encoding="utf-8")
    return tmp_path


# — зелёное состояние ---------------------------------------------------------

def test_current_matrix_is_clean():
    """Сверка на настоящем реестре: расхождений нет (иначе RED в doc_gates)."""
    assert not any(problems(REAL_DOC).values())


def test_every_rule_has_a_green_line_on_the_real_file():
    """Ни одно правило не «вечно красное» и не «вечно зелёное по пустоте»."""
    res = problems(REAL_DOC)
    assert set(res) == {"cjk", "пути", "голые имена", "тесты",
                        "миграции", "секции схемы", "derived-ключи", "правило реестра"}


def test_test_references_are_actually_parsed():
    """Правило «тесты» видит ссылки вида `файл.gd::test_...`, а не ноль ссылок."""
    refs = matrix.TEST_REF_RE.findall(REAL_DOC)
    assert len(refs) > 10, f"сверщик не нашёл ссылок на тесты ({len(refs)})"
    names = {t for _, t in refs}
    assert "test_save_load_roundtrip" in names


# — покраснение по правилу ---------------------------------------------------

def test_missing_path_is_red():
    res = problems(REAL_DOC + "\n`game/scripts/nope/absent_system.gd`\n")
    assert res["пути"]


def test_bare_name_without_file_is_red():
    res = problems(REAL_DOC + "\n`test_case_that_never_existed.gd`\n")
    assert any("файла нет в дереве" in h for h in res["голые имена"])


def test_ambiguous_bare_name_is_red():
    idx = dict(IDX)
    idx["x.gd"] = [Path("/a/x.gd"), Path("/b/x.gd")]
    res = problems(REAL_DOC + "\n`x.gd`\n", idx=idx)
    assert any("неоднозначно" in h for h in res["голые имена"])


def test_cited_test_function_must_exist():
    res = problems(REAL_DOC + "\n`test_mvp_save.gd::test_funkciya_ne_suschestvuet`\n")
    assert any("такой функции" in h for h in res["тесты"])


def test_bare_case_name_in_a_row_must_exist_in_a_row_file():
    """`file.gd::test_a`, `test_b` — второй кейс тоже проверяется (он в той же
    строке, но без имени файла: именно так сгнила бы ссылка на переименованный
    кейс, и именно так в первом черновике матрицы появился
    `test_rotated_placement_survive_save_load` вместо `…survives…`)."""
    row = ("| `inventory` | `save_roundtrip_inventory.gd` | "
           "`test_rotated_placement_survive_save_load` | ✅ |\n")
    assert "test_rotated_placement_survives_save_load" in REAL_DOC
    assert problems(REAL_DOC + row)["тесты"]


def test_real_case_name_in_a_row_is_green():
    row = ("| `inventory` | `save_roundtrip_inventory.gd` | "
           "`test_rotated_placement_survives_save_load` | ✅ |\n")
    assert not problems(REAL_DOC + row)["тесты"]


def test_line_address_after_bare_name_is_not_a_miss(tmp_path):
    """`population_system.gd:245-246` — это адрес строки, а не новое имя файла."""
    res = problems(REAL_DOC + "\n`population_system.gd:245-246`\n")
    assert not res["голые имена"]


def test_migration_without_a_row_is_red():
    """Правило T-301: миграция без строки матрицы не проходит."""
    row = matrix.migrations()[-1]
    assert row in REAL_DOC
    res = problems(REAL_DOC.replace(row, "(строка потеряна)"))
    assert res["миграции"] == [row]


def test_schema_section_without_a_row_is_red():
    """Секция схемы, не названная в реестре, — RED (схема не уезжает вперёд)."""
    res = problems(REAL_DOC.replace("`city.", "`город."))
    assert "city" in res["секции схемы"]


def test_sub_key_mention_counts_as_section_mention():
    """`city.housing` засчитывается как упомянутая секция `city`."""
    assert "city" not in problems(REAL_DOC)["секции схемы"]


def test_derived_key_without_a_row_is_red():
    res = problems(REAL_DOC.replace("`ladder`", "`лествица`"))
    assert "ladder" in res["derived-ключи"]


def test_cjk_is_red(tmp_path):
    tmp_doc(tmp_path, "переносы населения 牙齿 у этой строки\n")
    res = problems("нет CJK в самом аргументе", tmp_path=tmp_path, idx={})
    assert res["cjk"] and "1:" in res["cjk"][0]


def test_clean_doc_dir_has_no_cjk(tmp_path):
    tmp_doc(tmp_path, "переносы населения равны нулю\n")
    assert not problems("", tmp_path=tmp_path, idx={})["cjk"]


def test_registry_rule_must_be_written_in_the_registry():
    """Реестр обязан содержать собственное правило, а не только таблицы."""
    stripped = "\n".join(
        line for line in REAL_DOC.splitlines()
        if matrix.RULE_SENTENCE not in line)
    assert problems(REAL_DOC)["правило реестра"] == []
    assert problems(stripped)["правило реестра"]

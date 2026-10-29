#!/usr/bin/env bash
# Отчётная форма документальных проверок (change gdd-phase-workflow, задача 2.5).
#
# Это НЕ продуктовый гейт: он не поднимает Godot и не заменяет game/run_tests.sh.
# Здесь — всё, что краснеет, когда документация расходится с репозиторием или с
# собственной конвенцией. Каждая проверка печатает свою строку, последняя строка —
# вердикт; молчать проверка не имеет права (D-265 о том же для MCP-секции).
#
# Запуск: bash scripts/doc_gates.sh
set -uo pipefail
cd "$(dirname "$0")/.."
FAIL=0
YELLOW=0
PY=${PYTHON:-python3}

run() { # run "<название>" <команда...>
	local name=$1; shift
	echo "=== $name ==="
	if "$@"; then
		echo "OK: $name"
	else
		echo "RED: $name"
		FAIL=1
	fi
	echo ""
}

run "wikilinks, имена файлов, словарь статусов" "$PY" scripts/check_docs_links.py
run "индекс документации не устарел" "$PY" scripts/gen_docs_index.py --check
run "доки ↔ код (автолоады, сцены, классы, save-ключи)" "$PY" scripts/audit_docs_vs_code.py
# Карта hero-экрана и таблица геометрии обязаны сверяться машиной, а не только
# ux-review: GdUnit-тест не годится (res:// не читает docs/), поэтому сверщик
# здесь (T-277).
run "карта hero-экрана ↔ таблица BLOCKS (адреса, узлы, потребители)" "$PY" scripts/check_hero_layout_map.py
run "контур фаз GDD (состояния, поля реестров, ratchet)" "$PY" scripts/gdd_gate.py

TESTS=(scripts/test_check_docs_links.py scripts/test_audit_docs_vs_code.py
	scripts/test_classify_mcp_junit.py scripts/test_gdd_gate.py scripts/test_gdd_grounding.py
	scripts/test_gen_map_art.py scripts/test_testmap.py
	scripts/test_check_hero_layout_map.py
	scripts/test_check_openspec_specs.py scripts/test_check_node_paths.py)
# Отсутствующий файл списка — КРАСНЫЙ, а не «молча не досчитались»: ровно так список
# и жил, пока в нём значился test_check_docs_links.py, которого никогда не было
# (T-223). Проверщик без теста и проверщик, которого нет, — один и тот же класс.
MISSING=()
EXIST=()
for t in "${TESTS[@]}"; do
	if [ -f "$t" ]; then EXIST+=("$t"); else MISSING+=("$t"); fi
done
# Интерпретатор с pytest: явный PYTEST_PY → PYTHON → venv MCP (путь фиксирован
# AGENTS.md, его же использует game/run_tests.sh). Молчать уровень не имеет права:
# если pytest нигде не найден — YELLOW с причиной, а не зелёный пропуск (D-265).
pick_pytest_py() {
	local c cand=("${PYTEST_PY:-}" "$PY" /home/user/.venv/godot-mcp-tests/bin/python)
	for c in "${cand[@]}"; do
		[ -n "$c" ] && "$c" -c "import pytest" >/dev/null 2>&1 && { echo "$c"; return 0; }
	done
	return 1
}

echo "=== тесты самих проверщиков ==="
if [ ${#MISSING[@]} -gt 0 ]; then
	echo "RED: в списке уровней есть несуществующие файлы: ${MISSING[*]}"
	FAIL=1
fi
if [ ${#EXIST[@]} -eq 0 ]; then
	echo "YELLOW: тестов проверщиков нет — проверщик без теста уже один раз протих"
	YELLOW=$((YELLOW + 1))
elif PPP=$(pick_pytest_py); then
	if "$PPP" -m pytest "${EXIST[@]}" -q; then
		echo "OK: тесты самих проверщиков (${#EXIST[@]} файлов, $($PPP -c 'import pytest;print(pytest.__version__)'))"
	else
		echo "RED: тесты самих проверщиков (${#EXIST[@]} файлов)"
		FAIL=1
	fi
else
	echo "YELLOW: pytest недоступен (ни PYTEST_PY/PYTHON, ни venv godot-mcp-tests) — ${#EXIST[@]} файлов уровня не исполнены"
	YELLOW=$((YELLOW + 1))
fi

# Карта тестов — КРАСНЫЙ уровень (С-5; слово владельца «встраивай», 2026-10-27).
# Рэтчет сверяется с scripts/testmap.baseline.json и краснеет, если дыр, дублей или
# оскопления стало больше базлайна: «новый тикет = новый файл» перестаёт быть бесплатным.
# Наследие (92 дыры, 140 файлов в группах) в базлайне и красным не считается — краснеет
# только ухудшение; легитимное улучшение фиксируется --write-baseline в том же диффе.
# Уровень намеренно здесь, а не в game/run_tests.sh: метрика чистый Python, а гейт игры
# поднимает Godot (минус 13 минут на прогон ради строки, не зависящей от движка).
# Сведённые спеки (openspec/specs/) обязаны быть спеками, а не дельтами: заголовок
# `## ADDED Requirements` — язык changes/<смена>/specs/, в носителе он ломает
# `openspec validate --strict`. Проверка нулевая, не рэтчет: приехавшая из архива
# дельта — факт, а не степень (12 таких файлов сведены 2026-10-27, T-274).
echo "=== сведённые спеки: структура (T-274) ==="
if python3 scripts/check_openspec_specs.py; then
	: ; else
	echo "  план сведения: python3 scripts/check_openspec_specs.py; дельта-заголовки допустимы только в openspec/changes/"
	FAIL=1
fi
echo ""

echo "=== карта тестов: рэтчет покрытия и оскопления (T-227) ==="
if python3 scripts/testmap.py --check; then
	: ; else
	echo "  подробности: python3 scripts/testmap.py --top 12; план сведения — docs/mvp/TEST-MAP.md"
	FAIL=1
fi
echo ""

echo "=========================================="
if [ "$FAIL" -eq 0 ]; then
	if [ "$YELLOW" -gt 0 ]; then
		echo "DOC GATES: GREEN (жёлтых уровней: $YELLOW)"
	else
		echo "DOC GATES: GREEN"
	fi
else
	echo "DOC GATES: RED"
fi
exit "$FAIL"

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
run "контур фаз GDD (состояния, поля реестров, ratchet)" "$PY" scripts/gdd_gate.py

TESTS=(scripts/test_check_docs_links.py scripts/test_audit_docs_vs_code.py
	scripts/test_classify_mcp_junit.py scripts/test_gdd_gate.py scripts/test_gdd_grounding.py
	scripts/test_gen_map_art.py scripts/test_testmap.py)
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

# Карта тестов — информационный уровень: она считает покрытие и оскопление набора,
# но пока не красится (дыры 93 носителя — наследие, а не сегодняшняя правка; красным
# её делает владелец, когда дыры разобраны — T-227).
echo "=== карта тестов (информационно, на вердикт не влияет) ==="
if "$PY" scripts/testmap.py --top 0; then
	: ; else
	echo "YELLOW: testmap не исполнился — покрытие не измерено"
	YELLOW=$((YELLOW + 1))
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

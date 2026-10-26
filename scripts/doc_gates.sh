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
	scripts/test_gdd_gate.py scripts/test_gdd_grounding.py)
EXIST=()
for t in "${TESTS[@]}"; do
	[ -f "$t" ] && EXIST+=("$t")
done
if [ ${#EXIST[@]} -gt 0 ]; then
	run "тесты самих проверщиков (${#EXIST[@]} файлов)" \
		"${PYTEST_PY:-$PY}" -m pytest "${EXIST[@]}" -q
else
	echo "=== тесты проверщиков ==="
	echo "YELLOW: тестов проверщиков нет — проверщик без теста уже один раз протих"
fi

echo "=========================================="
if [ "$FAIL" -eq 0 ]; then
	echo "DOC GATES: GREEN"
else
	echo "DOC GATES: RED"
fi
exit "$FAIL"

#!/usr/bin/env bash
# report.sh — блоки для отчёта исполнителя (D-138, 2026-10-04).
# Правило: ни одно число в отчёте не пишется по памяти — только из вывода
# команд, выполненных в момент написания. Отчёт вставляет блоки дословно.
set -u
cd "$(dirname "$0")/.."

echo "## GIT-ЛОГ (git log --oneline -15)"
git log --oneline -15
echo
echo "## ВЕТКИ (тип: local/remote, с upstream)"
git branch -vv
echo
echo "## СЧЁТЧИК ТЕСТОВ (grep -c 'func test_' по файлам)"
total=0
while IFS= read -r f; do
	n=$(grep -c 'func test_' "$f" || true)
	total=$((total + n))
	echo "$f: $n"
done < <(find game/tests -name '*.gd' | sort)
echo "TOTAL: $total"
echo
echo "## RUN_TESTS (exit)"
bash game/run_tests.sh > /tmp/report_run_tests.log 2>&1
echo "exit run_tests.sh = $?"
tail -3 /tmp/report_run_tests.log
echo
echo "## DOCS-LINKS (check_docs_links.py)"
python3 scripts/check_docs_links.py
echo "exit check_docs_links = $?"
echo
echo "## КОНФЛИКТ-МАРКЕРЫ (diff3/merge; суперсет CI-grep: docs/ + game/, без addons)"
hits=$(grep -rn '^<<<<<<< \|^>>>>>>> \|^||||||| ' docs/ game/ --include='*.md' --include='*.gd' --include='*.json' 2>/dev/null | grep -v 'game/addons/' || true)
if [ -z "$hits" ]; then echo "маркеров нет"; else echo "$hits"; fi
echo "exit маркеры = 0 (пусто = чисто)"

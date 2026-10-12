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
echo "## RUN_TESTS (exit; GdUnit4 + MCP)"
bash game/run_tests.sh > /tmp/report_run_tests.log 2>&1
echo "exit run_tests.sh = $?"
tail -3 /tmp/report_run_tests.log
echo
echo "## MCP-ЛЕДЖЕР (pytest summary: passed/failed/skipped, время, exit)"
mcp_line=$(grep -E '[0-9]+ (passed|failed)[^)]*in [0-9.]+s' /tmp/report_run_tests.log | tail -1)
echo "${mcp_line:-PYTEST: summary нет (SKIPPED — причина в логе run_tests.sh)}"
grep 'PYTEST LEDGER' /tmp/report_run_tests.log | tail -1 || true
echo "Леджер двухстрочный: GdUnit4 (TOTAL выше) + MCP (строка выше)"
echo "## CI-2 (GitHub Actions; api.github.com без токена — раунд 6 §3.3)"
SLUG=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]##; s#\.git$##')
CI2_HTTP=$(curl -s -o /tmp/ci2_api.json -w '%{http_code}' --max-time 20 "https://api.github.com/repos/$SLUG/actions/runs?per_page=3" 2>/dev/null || echo 000)
if [ "$CI2_HTTP" = "200" ]; then
	python3 - <<'PY'
import json
d = json.load(open("/tmp/ci2_api.json"))
if not d.get("workflow_runs"):
    print("CI-2: прогонов ещё нет")
for r in d["workflow_runs"]:
    print("CI-2: %s | %s | %s | %s | %s" % (r["name"], r["head_sha"][:8], r["status"], r["conclusion"], r["created_at"]))
PY
else
	echo "CI-2: api.github.com HTTP $CI2_HTTP — репозиторий приватен или сеть недоступна. ВЛАДЕЛЬЦУ: статус только через залогиненный gh/токен (вне реестра)"
fi
echo "exit CI-2-статус-блока = 0 (блок информационный, не гейтит)"
echo "## DOCS-LINKS (check_docs_links.py)"
python3 scripts/check_docs_links.py
echo "exit check_docs_links = $?"
echo
echo "## КОНФЛИКТ-МАРКЕРЫ (diff3/merge; суперсет CI-grep: docs/ + game/, без addons)"
hits=$(grep -rn '^<<<<<<< \|^>>>>>>> \|^||||||| ' docs/ game/ --include='*.md' --include='*.gd' --include='*.json' 2>/dev/null | grep -v 'game/addons/' || true)
if [ -z "$hits" ]; then echo "маркеров нет"; else echo "$hits"; fi
echo "exit маркеры = 0 (пусто = чисто)"

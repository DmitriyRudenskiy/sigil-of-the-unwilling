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
# CI-2-поллинг ОТКЛЮЧЁН директивой владельца (2026-10-13): агент не ждёт CI,
# не спит и не принимает решений о merge по статусам ранов. Включить обратно:
# ENABLE_CI_WAIT=true bash game/report.sh
ENABLE_CI_WAIT="${ENABLE_CI_WAIT:-false}"
if [ "$ENABLE_CI_WAIT" = "true" ]; then
echo "## CI-2 (GitHub Actions; api.github.com без токена — раунд 6 §3.3)"
SLUG=$(git remote get-url origin 2>/dev/null | sed -E 's#.*github\.com[:/]##; s#\.git$##')
CI2_HTTP=$(curl -s -o /tmp/ci2_api.json -w '%{http_code}' --max-time 20 "https://api.github.com/repos/$SLUG/actions/runs?per_page=6" 2>/dev/null || echo 000)
if [ "$CI2_HTTP" = "200" ]; then
	HEAD_SHA=$(git rev-parse HEAD)
	REQ_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	python3 - "$HEAD_SHA" "$REQ_TS" <<'PY'
import json, sys, urllib.request
head, ts = sys.argv[1], sys.argv[2]
d = json.load(open("/tmp/ci2_api.json"))
runs = d.get("workflow_runs", [])
print("CI-2: запрос %s, HEAD %s" % (ts, head[:8]))
mine = [r for r in runs if r["head_sha"] == head]
if not mine:
    print("CI-2: для HEAD ещё бежит/не зарегистрирован (легитимная строка, раунд 7 §3.1; ниже — последние прогоны)")
for r in runs[:6]:
    mark = " <== HEAD" if r["head_sha"] == head else ""
    line = "CI-2: %s | %s | %s | %s | %s%s" % (r["name"], r["head_sha"][:8], r["status"], r["conclusion"], r["created_at"], mark)
    # JOBS=0-маркер (раунд 11 §2, D-168): ран с 0 jobs = workflow не собрал
    # jobs (YAML-ошибка/parse-fail) — completed/failure БЕЗ логов; детект
    # только через jobs-endpoint. Симптом af245eb (ран 38177047770).
    try:
        with urllib.request.urlopen(r["jobs_url"] + "?per_page=1", timeout=20) as resp:
            jobs = json.load(resp).get("total_count", -1)
        if r["status"] == "completed" and jobs == 0:
            line += " | JOBS=0 (workflow не собрал jobs — проверьте YAML, чекер 5)"
    except Exception:
        pass
    print(line)
PY
else
	echo "CI-2: api.github.com HTTP $CI2_HTTP — репозиторий приватен или сеть недоступна. ВЛАДЕЛЬЦУ: статус только через залогиненный gh/токен (вне реестра)"
fi
echo "exit CI-2-статус-блока = 0 (блок информационный, не гейтит)"
else
echo "CI-2: пропущен (ENABLE_CI_WAIT=false — директива 2026-10-13: агент не опрашивает CI и не ждёт ранов)"
fi
echo "## DOCS-LINKS (check_docs_links.py)"
python3 scripts/check_docs_links.py
echo "exit check_docs_links = $?"
echo "## DOCS-INDEX (gen_docs_index.py --check)"
python3 scripts/gen_docs_index.py --check
echo "exit gen_docs_index = $?"
echo
echo "## КОНФЛИКТ-МАРКЕРЫ (diff3/merge; суперсет CI-grep: docs/ + game/, без addons)"
hits=$(grep -rn '^<<<<<<< \|^>>>>>>> \|^||||||| ' docs/ game/ --include='*.md' --include='*.gd' --include='*.json' 2>/dev/null | grep -v 'game/addons/' || true)
if [ -z "$hits" ]; then echo "маркеров нет"; else echo "$hits"; fi
echo "exit маркеры = 0 (пусто = чисто)"

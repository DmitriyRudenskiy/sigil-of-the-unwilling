#!/usr/bin/env bash
# report.sh — сборка отчётных блоков смены (D-147: 4 уровня + CI-2-доказательство).
# Блоки:
#   1. Git-состояние (ветка, HEAD, origin/main, непушеные коммиты, dirty)
#   2. Гейт (последний лог run_tests.sh, если передан: report.sh /путь/к/логу)
#   3. Тестовый леджер (D-132/D-133: diff тест-файлов против origin/main)
#   4. DOCS-LINKS (check_docs_links.py)
#   5. CI-2-раннер: статус ранов GitHub Actions для HEAD (публичный API,
#      токен не нужен — репо публичное, проверка 2026-10-12: "private": false).
#      Урок af245eb: ран с 0 jobs = YAML-ошибка workflow — блок 5 обязан
#      показывать jobs=0 явно, а не «нет данных».
set -u
cd "$(dirname "$0")/.."

REPO="$(git remote get-url origin 2>/dev/null | sed -E 's#^git@github.com:##; s#^https://github.com/##; s#\.git$##')"
HEAD_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

echo "=============================================================="
echo " БЛОК 1: GIT-СОСТОЯНИЕ"
echo "=============================================================="
echo "ветка:      $BRANCH"
echo "HEAD:       $HEAD_SHA"
git rev-parse --verify origin/main >/dev/null 2>&1 && {
	ORIGIN_MAIN="$(git rev-parse origin/main)"
	echo "origin/main: $ORIGIN_MAIN"
	echo "непушено:   $(git rev-list --count origin/main..HEAD 2>/dev/null || echo '?') коммита(ов)"
} || echo "origin/main: (нет локального refs — fetch?)"
DIRTY="$(git status --porcelain | wc -l | tr -d ' ')"
echo "dirty:      $DIRTY файл(ов)"

if [ "${1:-}" != "" ] && [ -f "${1:-}" ]; then
	echo ""
	echo "=============================================================="
	echo " БЛОК 2: ГЕЙТ (лог: $1)"
	echo "=============================================================="
	grep -E "GdUnit4: |MCP: |DOCS-LINKS: |GATE: |Overall Summary" "$1" | tail -12 || echo "(маркеров гейта в логе нет)"
fi

echo ""
echo "=============================================================="
echo " БЛОК 3: ТЕСТОВЫЙ ЛЕДЖЕР (diff против origin/main)"
echo "=============================================================="
if git rev-parse --verify origin/main >/dev/null 2>&1; then
	ADDED="$(git diff --name-only --diff-filter=A origin/main -- 'game/tests/' | wc -l | tr -d ' ')"
	DEL="$(git diff --name-only --diff-filter=D origin/main -- 'game/tests/' | wc -l | tr -d ' ')"
	MOD="$(git diff --name-only --diff-filter=M origin/main -- 'game/tests/' | wc -l | tr -d ' ')"
	echo "тест-файлы: +$ADDED / -$DEL / ~$MOD"
	git diff --name-status origin/main -- 'game/tests/' | head -20
else
	echo "(нет origin/main — fetch?)"
fi

echo ""
echo "=============================================================="
echo " БЛОК 4: DOCS-LINKS"
echo "=============================================================="
python3 scripts/check_docs_links.py 2>&1 | tail -3 || echo "RED: check_docs_links.py упал"

echo ""
echo "=============================================================="
echo " БЛОК 5: CI-2-РАННЕР (публичный API, head_sha=HEAD)"
echo "=============================================================="
if [ -z "$REPO" ] || [ "$HEAD_SHA" = "unknown" ]; then
	echo "NO DATA: нет origin/HEAD"
elif ! command -v curl >/dev/null 2>&1; then
	echo "NO DATA: нет curl"
else
	RUNS_JSON="$(curl -sf --max-time 20 "https://api.github.com/repos/$REPO/actions/runs?head_sha=$HEAD_SHA&per_page=5" 2>/dev/null)"
	if [ -z "$RUNS_JSON" ]; then
		echo "NO DATA: API недоступен (сеть/лимит)"
	else
		echo "$RUNS_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
runs = d.get('workflow_runs', [])
if not runs:
    print('NO RUN: для HEAD нет ранов (не запушен? CI не стартовал? workflow не матчит?)')
for r in runs:
    print(f\"run={r['id']}  {r.get('workflow_name') or r['name']}  status={r['status']}  conclusion={r['conclusion']}  created={r['created_at']}\")
    print(f\"  url: {r['html_url']}\")
"
		# jobs=0 явный маркер (урок af245eb: YAML-ошибка = 0 jobs, failure без логов)
		LATEST="$(echo "$RUNS_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
runs = d.get('workflow_runs', [])
print(runs[0]['id'] if runs else '')
")"
		if [ -n "$LATEST" ]; then
			JOBS="$(curl -sf --max-time 20 "https://api.github.com/repos/$REPO/actions/runs/$LATEST/jobs?per_page=20" 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
jobs = d.get('jobs', [])
print(len(jobs))
for j in jobs:
    print(f\"  job: {j['name']} -> {j['conclusion']}\")
    for s in j.get('steps', []):
        if s.get('conclusion') not in (None, 'success'):
            print(f\"    step: {s['name']} -> {s['conclusion']}\")
" 2>/dev/null)"
			JOB_COUNT="$(echo "$JOBS" | head -1)"
			if [ "$JOB_COUNT" = "0" ]; then
				echo "  ⚠ JOBS=0: ран упал ДО jobs — класс «YAML-ошибка workflow» (af245eb); валидировать .github/workflows/*.yml"
			elif [ -n "$JOBS" ]; then
				echo "$JOBS"
			fi
		fi
	fi
fi
echo ""
echo "=== report.sh: конец ==="

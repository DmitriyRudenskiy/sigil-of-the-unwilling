#!/usr/bin/env bash
# Запуск тестов: GdUnit4 (tests/, классы GdUnitTestSuite) + MCP-тесты (tugcantopaloglu/godot-mcp).
# GUT удалён из проекта (addons/gut отсутствует) — секции GUT нет.
# Exit code GdUnit4: 0 = pass, 101 = только orphan-предупреждения (гигиена тестов),
# 100 и прочие = реальные падения.
#
# MCP e2e (feat/mcp-e2e-activation, 2026-10-04): venv + Xvfb + GODOT_PATH +
# --timeout=900; MCP-секция не имеет права молчать (явные PYTEST: SKIPPED).
set -u
cd "$(dirname "$0")"
# CI-1-семья (владелец 2026-10-05, раунд 5 вердикт §1.1; тикет T-120):
# cleanup MCP-процессов (node-сервер + его godot-дети), запущенных этим прогоном.
# Причина: убийство pytest (timeout/SIGKILL) оставляет node-сервер и godot
# сиротами; godot удерживает порт 9090 (MCP_INTERACTION_PORT) → в следующем
# прогоне wait_port_free() молчаливо блокирует ~120 c/тест (диагностика
# 2026-10-05: свит 30/39 за 890 c вместо 169 c). Машина шарится: убиваем
# только PIDs, отсутствовавшие на старте (снимок).
MCP_NODE_SNAPSHOT="$(mktemp)"
pgrep -f "build/index\.js" > "$MCP_NODE_SNAPSHOT" 2>/dev/null || true
MCP_GODOT_SNAPSHOT="$(mktemp)"
pgrep -f -- "--path $PWD" > "$MCP_GODOT_SNAPSHOT" 2>/dev/null || true
cleanup_mcp() {
	local p
	for p in $(pgrep -f "build/index\.js" 2>/dev/null); do
		grep -qx "$p" "$MCP_NODE_SNAPSHOT" || kill "$p" 2>/dev/null || true
	done
	for p in $(pgrep -f -- "--path $PWD" 2>/dev/null); do
		grep -qx "$p" "$MCP_GODOT_SNAPSHOT" || kill "$p" 2>/dev/null || true
	done
	rm -f "$MCP_NODE_SNAPSHOT" "$MCP_GODOT_SNAPSHOT"
	[ -n "${XVFB_PID:-}" ] && kill "$XVFB_PID" 2>/dev/null || true
	# Вендорный MCP-сервер инжектит mcp_interaction_server.gd + autoload в
	# project.godot и при выгрузке оставляет пустые строки — чистое дерево.
	rm -f mcp_interaction_server.gd mcp_interaction_server.gd.uid
	git checkout -- project.godot 2>/dev/null || true
}
trap cleanup_mcp EXIT
trap 'exit 130' INT
trap 'exit 131' TERM
# Порядок разрешения Godot (2026-10-04, флаг 8): $GODOT_BIN → $GODOT (legacy) →
# command -v godot → дефолты ОС (путь бинаря задокументирован в AGENTS.md)
GODOT="${GODOT_BIN:-${GODOT:-}}"
if [ -z "$GODOT" ]; then
	GODOT="$(command -v godot || true)"
fi
if [ -z "$GODOT" ]; then
	case "$(uname -s)" in
		Darwin) GODOT="/Applications/Godot.app/Contents/MacOS/Godot" ;;
		*) GODOT="$HOME/.local/bin/godot" ;;
	esac

fi
echo "GODOT: $GODOT"

# SKIP_GDUNIT=1 — MCP-only прогон (CI-2 эшелонирование, раунд 7 §1.3: GdUnit —
# отдельный шаг, MCP-шаг не прогоняет GdUnit повторно).
if [ "${SKIP_GDUNIT:-0}" != "1" ]; then
echo "=== gdUnit4: unit + integration + functional ==="
# Pre-import to refresh the global class cache (class_name).
"$GODOT" --headless --path . --import >/dev/null 2>&1
# CI-4 (раунд 11 §4, D-168): лог в файл — файл-level orphan-гейт (allowlist)
# парсит per-suite «Statistics: … N orphans» после «Run Test Suite: <path>».
GDUNIT_LOG="$(mktemp)"
set -o pipefail
"$GODOT" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests 2>&1 | tee "$GDUNIT_LOG"
RC=${PIPESTATUS[0]}
set +o pipefail
# Политика orphan (CI-2, T-114): 0 = pass; 101 = только orphan-предупреждения
# (гигиена, не падение); любой другой код = red. Политика закодирована в гейте.
if [ "$RC" -ne 0 ] && [ "$RC" -ne 101 ]; then
	exit "$RC"

fi
# CI-4 (раунд 11 §4, D-168): файл-level карантин — инвариант «сирот вне
# allowlist = 0». Allowlist: game/tests/orphan_allowlist.txt, формат
# «<res-путь> <лимит> — причина»; выемка строки — только вместе с фиксом.
ORPHAN_ALLOWLIST="$PWD/tests/orphan_allowlist.txt"
ORPHAN_RED=0
if [ -f "$ORPHAN_ALLOWLIST" ]; then
	# per-file фактические сироты (ANSI-коды сняты; suite → Statistics-пара)
	ORPHANS_ACTUAL="$(sed 's/\x1b\[[0-9;]*m//g' "$GDUNIT_LOG" | awk '
		/^Run Test Suite: / { suite = $4 }
		/^ *Statistics: / { for (i = 1; i <= NF; i++) if ($i == "orphans") { print suite, $(i-1); break } }
	')"
	while read -r f n; do
		[ -z "$f" ] && continue
		[ "$n" -eq 0 ] && continue  # 0 сирот — инвариант выполнен, allowlist не нужен
		if ! grep -q "^${f} " "$ORPHAN_ALLOWLIST"; then
			echo "ORPHAN-RED: $f — $n сирот(ы), файла нет в allowlist ($ORPHAN_ALLOWLIST)"; ORPHAN_RED=1
		else
			LIMIT="$(grep "^${f} " "$ORPHAN_ALLOWLIST" | head -1 | awk '{print $2}')"
			if [ "$n" -gt "$LIMIT" ]; then
				echo "ORPHAN-RED: $f — $n сирот(ы) > лимит $LIMIT (allowlist)"; ORPHAN_RED=1
			fi
		fi
	done <<< "$ORPHANS_ACTUAL"
	if [ "$ORPHAN_RED" -eq 0 ]; then
		TOTAL_ORPHANS="$(sed 's/\x1b\[[0-9;]*m//g' "$GDUNIT_LOG" | grep -E "^ *Overall Summary:" | tail -1 | sed -E 's/.* ([0-9]+) orphans.*/\1/')"
		ALLOW_N="$(grep -c '^res://' "$ORPHAN_ALLOWLIST" 2>/dev/null)"
		echo "ORPHAN-GATE: OK (сирот всего: ${TOTAL_ORPHANS:-0}; allowlist: ${ALLOW_N:-0} файл(а))"
	fi
else
	echo "ORPHAN-GATE: SKIPPED (нет $ORPHAN_ALLOWLIST — создайте хотя бы заголовок)"
fi
rm -f "$GDUNIT_LOG"
if [ "$ORPHAN_RED" -ne 0 ]; then
	exit 1
fi

fi
echo ""
echo "=== lint: gdlint (T-141, report-only) ==="
# D-210: gdlint ищет .gdlintrc по рабочему каталогу. Скрипт выше делает cd в game/,
# поэтому секция ниже работает именно с проектным конфигом; запуск из корня репо —
# ДРУГОЙ конфиг (дефолт), в котором часть правил выключена проектом. Дельта-гейт
# (падение на росте против базы) — вторая половина T-141, не подключена: конфиг линтера
# сам помечен «report-only, до утверждения владельцем».
LINT_PY="${LINT_PY:-python3}"
if "$LINT_PY" -c 'import gdtoolkit.linter' 2>/dev/null && [ -f .gdlintrc ]; then
	# Знаменатель печатается раздельно (D-210: мера печатает охват). Корзин — ТРИ, а не две:
	# внутри tools/ лежит tools/mcp (77 из 78 находок tools/) — закоммиченная и пропатченная
	# в репо копия серверной части godot-mcp (отличается от копии в addons/, preload'ит
	# res://scripts/core/game_logger.gd). Две корзины по каталогам («свои 432» / «вендор 836»)
	# дали бы 432 своих, из которых 77 — чужие. Ось «кто это пишет» ≠ ось «в каком каталоге
	# лежит» — та же ошибка, что каталог-vs-рантайм в предикате мержа (D-210 п. 6).
	LINT_OWN="$("$LINT_PY" -m gdtoolkit.linter scripts tests tools/*.gd 2>&1 | tail -1)"
	LINT_FORK="$("$LINT_PY" -m gdtoolkit.linter tools/mcp 2>&1 | tail -1)"
	LINT_VENDOR="$("$LINT_PY" -m gdtoolkit.linter addons 2>&1 | tail -1)"
	echo "LINT: свои (scripts + tests + tools/*.gd): ${LINT_OWN:-нет вывода}"
	echo "LINT: вендор-наследие (tools/mcp — патченная копия godot-mcp, вне дельты): ${LINT_FORK:-нет вывода}"
	echo "LINT: вендор (addons, вне дельты): ${LINT_VENDOR:-нет вывода}"
	echo "LINT: конфиг = $(pwd)/.gdlintrc (CWD=game); сигнал = ДЕЛЬТА против базы по СВОИМ 355, не «чисто» (T-141); гейт не подключён"
else
	echo "LINT: SKIPPED (нет gdtoolkit у $LINT_PY или нет .gdlintrc в $(pwd))"
fi
echo ""
echo "=== vacuous asserts: сканер T-123 (гейт) ==="
# Класс «вечно-зелёных» тестов: `assert_*(x)` без check-метода в GdUnit4 НЕ проверяет
# ничего — тест зелёный всегда. Сканер жил только в CI-2 (checker 6), а вердикт проекта —
# локальный прогон (директива владельца 2026-10-13), поэтому гард мог быть пустым и
# зелёным: 2026-10-20 так нашлись 7 мёртвых проверок в уже смерженном
# test_tail_screens_theme_carrier.gd (срез T-147). Выход сканера — падение гейта.
# Сканер требует корень репо как рабочую директорию (git ls-files game/tests).
if command -v python3 >/dev/null 2>&1; then
	if VACUOUS="$(cd .. && python3 scripts/ci2_vacuous_asserts.py 2>&1)"; then
		echo "VACUOUS-ASSERT-GATE: OK (полупустых assert-* нет)"
	else
		echo "VACUOUS-ASSERT-GATE: RED — assert без check-метода не проверяет НИЧЕГО (T-123):"
		echo "$VACUOUS"
		echo "  Правка: добавить терминал (.is_true() / .is_equal(...)); ложные срабатывания —"
		echo "  в scripts/ci2_vacuous_allowlist.txt (пусто = строго)"
		exit 1
	fi
else
	echo "VACUOUS-ASSERT-GATE: SKIPPED (python3 не найден — уровень молчит, зафиксировать в отчёте)"
fi
echo ""
echo "=== MCP tests (tugcantopaloglu/godot-mcp) ==="
MCP_SERVER="${GODOT_MCP_SERVER:-$PWD/addons/godot-mcp/build/index.js}"
if [ ! -f "$MCP_SERVER" ]; then
	echo "PYTEST: SKIPPED (no MCP server: $MCP_SERVER; build: cd addons/godot-mcp && npm ci && npm run build)"
	exit 0
fi
# MCP e2e-тесты запускают живой Godot (не headless) — нужен X-дисплей.
# Машина шарится: чужие Xvfb (в т.ч. с auth) могут работать — чужие процессы не
# убиваем, только свободный дисплей: скан :97 → :91–:98 (:99 исключён — auth).
# При заданном DISPLAY используется он.
XVFB_PID=""
if [ -z "${DISPLAY:-}" ] && command -v Xvfb >/dev/null 2>&1; then
	for d in 97 91 92 93 94 95 96 98; do
		Xvfb :$d -screen 0 1024x768x24 >/dev/null 2>&1 &
		XVFB_PID=$!
		sleep 1
		if kill -0 "$XVFB_PID" 2>/dev/null; then
			export DISPLAY=:$d
			break
		fi
		XVFB_PID=""
	done
	if [ -z "$XVFB_PID" ]; then
		echo "PYTEST: SKIPPED (свободного Xvfb-дисплея :91–:98 нет — машина шарится? укажите DISPLAY)"
		exit 0
	fi
fi
# venv MCP-тестов: путь зафиксирован в AGENTS.md (Linux). На машинах без этого
# venv (macOS, 2026-10-04) — системный python3 с mcp+anyio (проверено: 38/1).
PYTEST_PY="${MCP_PYTEST_PY:-/home/user/.venv/godot-mcp-tests/bin/python}"
if [ ! -x "$PYTEST_PY" ]; then
	if command -v python3 >/dev/null 2>&1 && python3 -c 'import mcp, anyio' 2>/dev/null; then
		PYTEST_PY="$(command -v python3)"
	else
		echo "PYTEST: SKIPPED (no venv: $PYTEST_PY и нет python3 с mcp+anyio; create: python3 -m venv /home/user/.venv/godot-mcp-tests && $PYTEST_PY -m pip install pytest pytest-timeout mcp anyio)"
		[ -n "$XVFB_PID" ] && kill "$XVFB_PID" 2>/dev/null || true
		exit 0
	fi
fi
export GODOT_MCP_SERVER="$MCP_SERVER"
export GODOT_PROJECT_PATH="${GODOT_PROJECT_PATH:-$PWD}"
# conftest.py читает GODOT_PATH (не GODOT_BIN) — баг старого скрипта исправлен.
# --timeout=900: READY_TIMEOUT в godot_mcp.py = 900 c; старое --timeout=300 резало
# e2e раньше собственного дедлайна.
# Полный свит tests/mcp/ (38 тестов), не выборка из 6 файлов.
# --durations=25: per-test timing в хвосте прогона — диагноз «гонка соседних сессий
# на порту» (ступень на setup каждого теста vs равномерное замедление, CI-1(9), раунд 7).
# ВНИМАНИЕ (урок 2026-10-05): комментарий МЕЖДУ строками VAR=value \ рвёт env-префикс
# (bash: присваивания без команды не экспортируются в команду) — GODOT_PATH/GODOT_BIN
# не доходили до pytest; lifecycle-тесты skip'ались «Godot не найден», node-сервер
# маскировал баг auto-detection. Комментарии — только ВЫШЕ блока присваиваний.
# ci-speedup: параллельные MCP-воркеры (pytest-xdist, dist=load — дефолт).
# MCP_WORKERS: дефолт 1 (локальный прогон — поведение не меняется); CI: 3
# (4-ядерный раннер, 1 ядро — запас под флейки, D-166-класс). Порт воркера —
# conftest _worker_port(): gwN → 9090+N (env MCP_PORT; Godot-сторона tools/mcp/
# читает то же). Без xdist — явная строка + фолбэк на 1 воркер (уровень не
# молчит, гейт не ослабевает).
MCP_WORKERS="${MCP_WORKERS:-1}"
PYTEST_WORKER_ARGS=()
PERF_SERIAL=0
if [ "$MCP_WORKERS" -gt 1 ]; then
	if "$PYTEST_PY" -c 'import xdist' 2>/dev/null; then
		PYTEST_WORKER_ARGS=(-n "$MCP_WORKERS")
		# ci-speedup (2026-10-14): perf-тесты — отдельная serial-стадия. Лимиты
		# D-177 калиброваны на свободном раннере (пол пула × 1.3); под contention
		# CPU-замер невалиден (ран 38502715080: 913 мс > лимит 800 мс). Perf =
		# serial на свободном CPU (методология, не оптимизация).
		PERF_SERIAL=1
		echo "MCP: параллельные воркеры = $MCP_WORKERS (xdist; порты 9090..$((9089 + MCP_WORKERS))); perf — serial-стадия"
	else
		echo "MCP: запрошено MCP_WORKERS=$MCP_WORKERS, но pytest-xdist отсутствует в $PYTEST_PY — прогон с 1 воркером (pip install pytest-xdist)"
		MCP_WORKERS=1
	fi
fi
MCP_LOG="$(mktemp)"
PERF_IGNORE=()
[ "$PERF_SERIAL" -eq 1 ] && PERF_IGNORE=(--ignore=tests/mcp/test_hexutils_perf.py)
GODOT_PATH="$GODOT" \
GODOT_BIN="$GODOT" \
"$PYTEST_PY" -m pytest tests/mcp/ -v --timeout=900 --tb=short --durations=25 \
	${PERF_IGNORE[@]+"${PERF_IGNORE[@]}"} ${PYTEST_WORKER_ARGS[@]+"${PYTEST_WORKER_ARGS[@]}"} 2>&1 | tee "$MCP_LOG"
MCP_RC=${PIPESTATUS[0]}
if [ "$PERF_SERIAL" -eq 1 ]; then
	echo "MCP: perf-стадия — serial (test_hexutils_perf.py; D-177: свободный CPU)"
	GODOT_PATH="$GODOT" \
	GODOT_BIN="$GODOT" \
	"$PYTEST_PY" -m pytest tests/mcp/test_hexutils_perf.py -v --timeout=900 --tb=short \
		2>&1 | tee -a "$MCP_LOG"
	RC2=${PIPESTATUS[0]}
	[ "$RC2" -ne 0 ] && MCP_RC=1
fi
# Леджер-равенство (fixed-green-семья CI-4, раунд 6 §2): свит обязан отработать
# всё собранное; прерванный прогон (таймаут сессии, -x в dev-режиме) — красный.
# ci-speedup (2026-10-14): сумма по стадиям (parallel + perf-serial); под xdist
# нет «collected N items» — хедер «N workers [M items]» (master распределяет).
LEDGER=$("$PYTEST_PY" - "$MCP_LOG" <<'PYEOF_LEDGER'
import re
import sys

text = open(sys.argv[1], errors="replace").read()


def sumre(pat: str) -> int:
    return sum(int(m) for m in re.findall(pat, text))


# Оба формата (взаимоисключаемы в рамках стадии; по стадиям — сумма):
# serial: «collected N items»; xdist: «N workers [M items]».
collected = sumre(r"collected (\d+) items") + sum(
    int(m[1]) for m in re.findall(r"(\d+) workers \[(\d+) items\]", text))
lines = [l for l in text.splitlines() if re.match(r"=+ .* in [0-9.]+s.* =+$", l)]


def sumin(pat: str) -> int:
    return sum(int(re.search(pat, l).group(1)) for l in lines if re.search(pat, l))


print(sumin(r"(\d+) passed"), sumin(r"(\d+) skipped"), sumin(r"(\d+) failed"),
      sumin(r"(\d+) error"), collected)
PYEOF_LEDGER
)
read -r P S F E COLLECTED <<< "$LEDGER"
P=${P:-0}; S=${S:-0}; F=${F:-0}; E=${E:-0}; COLLECTED=${COLLECTED:-0}
SUM=$((P + S + F + E))
echo "PYTEST LEDGER: passed=$P skipped=$S failed=$F errors=$E collected=$COLLECTED"
if [ "$MCP_RC" -eq 0 ] && [ "$SUM" -ne "$COLLECTED" ]; then
	echo "PYTEST: RED (неполный прогон: сумма $SUM != collected $COLLECTED — свит встал/прервался)"
	MCP_RC=1
fi
# Python-гейт генератора арта (T-150): `scripts/test_gen_map_art.py` не входит ни в одну
# секцию выше (MCP-секция знает только tests/mcp/), а без него затемнённый побратим листа
# и кратность MAP_FOG_DIM проверялись бы только руками. Секция не молчит: нет pytest/PIL —
# явная строка SKIPPED (конвенция MCP-секции).
echo "=== python: генератор арта карты (scripts/test_gen_map_art.py) ==="
GEN_PY="${GEN_PY:-python3}"
if "$GEN_PY" -c 'import pytest, PIL' 2>/dev/null; then
	"$GEN_PY" -m pytest ../scripts/test_gen_map_art.py -q --tb=short 2>&1 | tail -5
	[ "${PIPESTATUS[0]}" -ne 0 ] && MCP_RC=1
else
	echo "GENART: SKIPPED (нет pytest или PIL в $GEN_PY — pip install pytest pillow)"
fi

# Очистка (Xvfb, инжект-артефакты, node/godot MCP-процессы) — в trap cleanup_mcp (EXIT).
exit "$MCP_RC"

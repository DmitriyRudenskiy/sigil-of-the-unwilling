#!/usr/bin/env bash
# Запуск тестов: GdUnit4 (tests/, классы GdUnitTestSuite) + MCP-тесты (tugcantopaloglu/godot-mcp).
# GUT удалён из проекта (addons/gut отсутствует) — секции GUT нет.
# Exit code GdUnit4: 0 = pass, 101 = только orphan-предупреждения (гигиена тестов),
# 100 и прочие = реальные падения.
#
# Принцип гейта (T-344, чеклист ниже — что входит в вердикт):
#   1. Факт о продакшне измеряется в продакшн-канале: числа отчёта — только из
#      текущего дерева (метрики чужого checkout аннулируются, не переносятся).
#   2. Гейт не имеет права молча менять дерево: project.godot фиксируется
#      снапшотом и восстанавливается в trap (EXIT/INT/TERM; SIGKILL не покрыт —
#      задокументирован у блока снапшота).
#   3. Уровень, который не мерился, не выглядит зелёным: SKIPPED ⇒ максимум
#      YELLOW; молчание уровня = дефект отчётности (T-281).
#   4. Вердикт = одна строка на каждом выходе; основание push — только полный
#      слой (D-224) при failed = 0 и readiness, классифицированном жёлтым (D-265).
#
# Чеклист уровней полного прогона (full):
#   [ ] AUTOLOAD-PRECHECK — секция [autoload] = канон 15 записей (T-344)
#   [ ] GdUnit4 unit/integration/functional (headless) + TIER COVERAGE + ORPHAN-GATE
#   [ ] VACUOUS-ASSERT-GATE (T-123) + NODE-PATH-GATE (T-296)
#   [ ] MCP e2e — живой Godot, X-дисплей, junit + классификатор D-265
#   [ ] python-уровни: GENART (T-150) + READINESS-CLASSIFIER selftest
#   [ ] LINT (gdlint, report-only — в вердикт не входит)
#
# MCP e2e (feat/mcp-e2e-activation, 2026-10-04): venv + Xvfb + GODOT_PATH +
# --timeout=900; MCP-секция не имеет права молчать (явные PYTEST: SKIPPED).
#
# D-265 (владелец, 2026-10-26): error fixture-readiness («игра не готова за 180 с») —
# ЖЁЛТЫЙ, а не красный. Классификация — по junit-отчёту (`scripts/classify_mcp_junit.py`),
# жёлтый печатается с именами жертв; всё остальное (assert, другой error, неполный прогон,
# неразобранный журнал) остаётся красным.
set -u
cd "$(dirname "$0")"
# CI-1-семья (владелец 2026-10-05, раунд 5 вердикт §1.1; тикет T-120):
# cleanup MCP-процессов (node-сервер + его godot-дети), запущенных этим прогоном.
# Причина: убийство pytest (timeout/SIGKILL) оставляет node-сервер и godot
# сиротами; godot удерживает порт 9090 (MCP_INTERACTION_PORT) → в следующем
# прогоне wait_port_free() молчаливо блокирует ~120 c/тест (диагностика
# 2026-10-05: свит 30/39 за 890 c вместо 169 c). Машина шарится: убиваем
# только PIDs, отсутствовавшие на старте (снимок).
# T-344: гейт не имеет права молча менять дерево. Раньше cleanup делал
# `git checkout -- project.godot` — чистое дерево ценой СНОСА незакоммиченных
# правок автолоадов (инцидент 2026-11-06). Теперь состояние фиксируется
# снапшотом до прогона и восстанавливается им: вендорный инжект снимается,
# рабочее состояние — нет. Покрытие: EXIT/INT/TERM (exit-трапы цепляются);
# SIGKILL трапов не вызывает — не покрыт сознательно, документируется здесь.
PROJECT_SNAPSHOT="$(mktemp)"
cp project.godot "$PROJECT_SNAPSHOT"
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
        # project.godot и при выгрузке оставляет пустые строки. Восстановление —
        # из снапшота начала прогона (T-344): инжект снят, незакоммиченные правки
        # project.godot переживают гейт (git checkout их сносил).
        rm -f mcp_interaction_server.gd mcp_interaction_server.gd.uid
        cp "$PROJECT_SNAPSHOT" project.godot 2>/dev/null || true
        rm -f "$PROJECT_SNAPSHOT"
}
trap cleanup_mcp EXIT
trap 'exit 130' INT
trap 'exit 131' TERM
# Настройки машины (2026-11-03): пути бинарей, venv и адрес X-хоста принадлежат
# машине, а не проекту, — в репозитории их не было и нет. Файл живёт вне дерева;
# переменная из окружения перекрывает его значение (в файле все присваивания вида
# `: "${VAR:=…}"`). Свой путь — SOTU_MACHINE_ENV; отсутствие файла штатно: тогда
# работают только переменные окружения и PATH.
SOTU_MACHINE_ENV="${SOTU_MACHINE_ENV:-$HOME/.pi/agent/env/sotu-machine.env}"
if [ -r "$SOTU_MACHINE_ENV" ]; then
        # shellcheck disable=SC1090
        . "$SOTU_MACHINE_ENV"
        echo "MACHINE CONFIG: $SOTU_MACHINE_ENV"
else
        echo "MACHINE CONFIG: нет ($SOTU_MACHINE_ENV) — только окружение и PATH"
fi

# Порядок разрешения Godot (2026-10-04, флаг 8; с 2026-11-03 — без угадывания пути
# по ОС): $GODOT_BIN (окружение либо настройка машины) → $GODOT (legacy) →
# command -v godot → явная ошибка с именем настройки.
GODOT="${GODOT_BIN:-${GODOT:-}}"
if [ -z "$GODOT" ]; then
        GODOT="$(command -v godot || true)"
fi
if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
        echo "GODOT не найден (пробовали GODOT_BIN/GODOT и PATH). Путь — в настройку машины: $SOTU_MACHINE_ENV (GODOT_BIN=/путь/к/godot)" >&2
        exit 3
fi
echo "GODOT: $GODOT"

# Предпроверка автолоадов (T-344): секция [autoload] — закрытый набор из 15
# записей; испорченная секция делает GdUnit молча красным. Ловится ДО прогона.
if command -v python3 >/dev/null 2>&1; then
        if ! python3 ../scripts/check_autoloads.py project.godot; then
                exit 1
        fi
else
        echo "AUTOLOAD-PRECHECK: SKIPPED (python3 не найден — секция [autoload] не сверена)"
fi

# Слои прогона (срез test-suite-restructure, 2026-11-02): `smoke` — критичный путь
# headless (бюджет 30 с), `fast` — все GdUnit-проверки без живого Godot (бюджет
# 3 мин), `full` — сегодняшний гейт целиком (GdUnit + MCP e2e + python-уровни).
# Слой задаётся МЕСТОМ В ДЕРЕВЕ (tests/smoke, tests/slow) и штатной фильтрацией
# GdUnit `-a`/`-i`: списка-манифеста «файлы слоя» нет и не заведётся — он расходится
# с деревом в первый же день и не краснеет, когда файл переименовали.
# Дефолт `full`: ни один существующий вызов (report.sh, CI) поведения не меняет.
# Зелёный smoke/fast основанием для push не является (D-224: вердикт = полный прогон).
TIER="full"
for arg in "$@"; do
        case "$arg" in
                --tier=*) TIER="${arg#--tier=}" ;;
                -h | --help)
                        cat <<'USAGE'
usage: run_tests.sh [--tier=smoke|fast|full] [--help]
  smoke — критичный путь (game/tests/smoke), headless; MCP_SMOKE=1 добавляет 2 MCP-теста живым Godot, бюджет 30 с
        команда: -a res://tests/smoke | не мерит: живой Godot (UI, сцены, клики), python-уровни, lint
  fast  — все GdUnit-проверки кроме game/tests/slow, headless, бюджет 3 мин
        команда: -a res://tests -i res://tests/slow | не мерит: живой Godot, python-уровни, lint
  full  — полный гейт: GdUnit + MCP e2e + python-уровни (по умолчанию)
        команда: -a res://tests + pytest tests/mcp/ | не мерит: звук, playtest, ручной ux-review
Env как раньше: SKIP_GDUNIT=1, MCP_WORKERS=N, GODOT_BIN, MCP_PYTEST_PY, GEN_PY.
Настройки машины — SOTU_MACHINE_ENV (файл вне репозитория, по умолчанию
  ~/.pi/agent/env/sotu-machine.env): GODOT_BIN, MCP_PYTEST_PY, адрес X-хоста
  MCP_SSH_HOST (+MCP_REMOTE_DIR_BASE). В репозитории
  путей и адресов машины нет: X — настроенный ресурс, а не «та самая машина»,
  при заданном MCP_SSH_HOST MCP-секция исполняется на X-хосте из проверяемого
  рабочего дерева.
MCP_SMOKE=1 — вместе со слоем smoke поднять живой Godot и прогнать MCP-тесты с
  маркером smoke (меню → мир). По умолчанию слой smoke остаётся headless.
USAGE
                        exit 0
                        ;;
                *)
                        echo "run_tests.sh: неизвестный аргумент «${arg}» (--help)" >&2
                        exit 2
                        ;;
        esac
done
case "$TIER" in
        smoke | fast | full) : ;;
        *)
                echo "run_tests.sh: --tier=$TIER — нет такого слоя (smoke|fast|full)" >&2
                exit 2
                ;;
        esac
if [ "${SKIP_GDUNIT:-0}" = "1" ] && [ "$TIER" != "full" ]; then
        echo "run_tests.sh: слой $TIER без GdUnit не имеет смысла — прогон ничего не измерил бы" >&2
        exit 2
fi
echo "TIER: $TIER"

# Что слой ИСКЛЮЧАЕТ — подстроки путей без `res://` (одна и та же подстрока режет и
# `source_file` раннера, и дерево `tests/` в читателе полноты):
#   слой   — tests/slow работает только в full (fast = всё остальное);
#   карантин — нестабильные сюиты, реестр game/tests/quarantine.txt.
GD_SKIP=()
GD_ROOT="game/tests"
GD_INCLUDE="res://tests"
if [ "$TIER" = "smoke" ]; then
        # Каталог слоя он и есть корень замера полноты: сверять нужно со своим поддеревом.
        GD_ROOT="game/tests/smoke"
        GD_INCLUDE="res://tests/smoke"
elif [ "$TIER" = "fast" ]; then
        GD_SKIP+=(tests/slow)
fi

# Карантин нестабильных GdUnit-сюит — тем же форматом, что tests/mcp/quarantine.txt
# («<подстрока пути><tab><ГГГГ-ММ-ДД><tab><причина>»). Просроченная строка и запись,
# не режущая ни один файл (опечатка: `-i` тогда не исключил бы НИЧЕГО, а карантин
# выглядел бы работающим), красят прогон до запуска.
if command -v python3 >/dev/null 2>&1; then
        if QUAR_ROWS="$(cd .. && python3 scripts/check_test_tiers.py quarantine --root game/tests 2>&1)"; then
                if [ -n "$QUAR_ROWS" ]; then
                        while IFS=$'\t' read -r q_needle q_until q_reason; do
                                [ -z "$q_needle" ] && continue
                                GD_SKIP+=("$q_needle")
                                echo "QUARANTINE: $q_needle — вне прогонов до $q_until: $q_reason"
                        done <<< "$QUAR_ROWS"
                else
                        echo "QUARANTINE: 0 (game/tests/quarantine.txt пуст)"
                fi
        else
                echo "QUARANTINE: RED — $QUAR_ROWS"
                exit 1
        fi
else
        echo "QUARANTINE: SKIPPED (python3 не найден — реестр не прочитан, изолированные сюиты остались в прогоне)"
fi
GD_EXCLUDE=()
for gd_skip in ${GD_SKIP[@]+"${GD_SKIP[@]}"}; do
        GD_EXCLUDE+=(-i "$gd_skip")
done

# SKIP_GDUNIT=1 — MCP-only прогон (CI-2 эшелонирование, раунд 7 §1.3: GdUnit —
# отдельный шаг, MCP-шаг не прогоняет GdUnit повторно).
# Pre-import: кэш глобальных классов (class_name) и `.godot/imported` для ассетов.
# С 2026-11-03 — вне ветки GdUnit: MCP-прогон на свежем дереве (делегация на
# X-контур, SKIP_GDUNIT=1) тоже поднимает живой Godot, а без импорта сцена
# теряет ext_resource («referenced non-existent resource at: res://…/skip.png»)
# и уровень краснеет на дереве, с которым ничего не делали. Раньше это маскировал
# локальный .godot, переживающий прогоны.
"$GODOT" --headless --path . --import >/dev/null 2>&1
if [ "${SKIP_GDUNIT:-0}" != "1" ]; then
        echo "=== gdUnit4: слой $TIER ($GD_INCLUDE, исключений: ${#GD_EXCLUDE[@]}) ==="
# CI-4 (раунд 11 §4, D-168): лог в файл — файл-level orphan-гейт (allowlist)
# парсит per-suite «Statistics: … N orphans» после «Run Test Suite: <path>».
GDUNIT_LOG="$(mktemp)"
set -o pipefail
"$GODOT" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a "$GD_INCLUDE" ${GD_EXCLUDE[@]+"${GD_EXCLUDE[@]}"} 2>&1 | tee "$GDUNIT_LOG"
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
# Полнота сбора: слой не имеет права быть тихой выборкой. Сравниваем то, что раннер
# реально собрал (строки «Run Test Suite:» в логе), с деревом tests/ за вычетом
# исключений слоя; smoke к тому же обязан быть непустым (пустой слой, зелёный
# тишиной, — тот же дефект, что уровень без причины, T-281).
if command -v python3 >/dev/null 2>&1; then
        COV_ARGS=(coverage --log "$GDUNIT_LOG" --root "$GD_ROOT" --scope "$TIER")
        for gd_skip in ${GD_SKIP[@]+"${GD_SKIP[@]}"}; do
                COV_ARGS+=(--exclude "$gd_skip")
        done
        [ "$TIER" = "smoke" ] && COV_ARGS+=(--require-nonempty)
        if ! COV="$(cd .. && python3 scripts/check_test_tiers.py "${COV_ARGS[@]}" 2>&1)"; then
                echo "TIER COVERAGE: RED — $COV"
                rm -f "$GDUNIT_LOG"
                exit 1
        fi
        echo "TIER COVERAGE: OK ($COV; слой $TIER)"
else
        echo "TIER COVERAGE: SKIPPED (python3 не найден — полноту сбора слоя никто не сверил)"
fi
rm -f "$GDUNIT_LOG"
if [ "$ORPHAN_RED" -ne 0 ]; then
        exit 1
fi

fi
# Владелец, 2026-11-09: уровень, который не мерился, не имеет права выглядеть
# зелёным. Замер дня: symlink вместо node_modules → зеркало на X-контур
# (`find … -type f` по symlink не идёт) уезжало без зависимостей →
# `PYTEST: SKIPPED` при `exit 0` = «зелёный full без e2e» (GATE_EXIT был 0).
# Отсюда одна строка вердикта на всех выходах и правило: SKIPPED ⇒ максимум
# YELLOW, никогда GREEN. Жёлтый exit-кода не краснит — это среда, а не падение
# (тот же статус, что у readiness D-265).
MCP_YELLOW=0
SOTU_SKIPPED=""
skipped_level() { # skipped_level "<уровень>" "<причина>"
        SOTU_SKIPPED="${SOTU_SKIPPED:+$SOTU_SKIPPED; }$1: $2"
}
gate_verdict() { # gate_verdict <red|ok> "<причина падения>"
        local line rc=0 why=${2:-}
        if [ "$1" = "red" ]; then
                line="RED — $why"; rc=1
        elif [ -n "$SOTU_SKIPPED" ]; then
                line="YELLOW — уровень не мерился ($SOTU_SKIPPED); зелёного без e2e не бывает"
        elif [ "$MCP_YELLOW" -eq 1 ]; then
                line="YELLOW — регрессий нет, readiness-красный снят по подписи (D-265)"
        else
                line="GREEN — измеренные уровни зелёные, пропусков уровней нет"
        fi
        echo "GATE VERDICT: $line"
        return "$rc"
}

echo ""
echo "=== lint: gdlint (T-141, report-only) ==="
# D-210: gdlint ищет .gdlintrc по рабочему каталогу. Скрипт выше делает cd в game/,
# поэтому секция ниже работает именно с проектным конфигом; запуск из корня репо —
# ДРУГОЙ конфиг (дефолт), в котором часть правил выключена проектом. Дельта-гейт
# (падение на росте против базы) — вторая половина T-141, не подключена: конфиг линтера
# сам помечен «report-only, до утверждения владельцем».
LINT_PY="${LINT_PY:-python3}"
if [ "$TIER" != "full" ]; then
        # Report-only уровень стоит 16 с (замер 2026-11-02) — в бюджет smoke не влезает,
        # а сигнала для падения не даёт ни в одном слое.
        echo "LINT: SKIPPED (report-only, не входит в слой $TIER; полный прогон: game/run_tests.sh)"
elif [ -n "${SOTU_ON_X_HOST:-}" ]; then
        # LINT остаётся локальным уровнем (gdtoolkit на X-хост не ставится — решение
        # владельца 2026-11-09), но называться обязан тем, чем является: не потерянным
        # уровнем, а уровнем, который здесь не меряется по устройству. Report-only,
        # в вердикт не входит (он и локально в слой не входит).
        echo "LINT: НЕ МЕРЯЕТСЯ на X-контуре (report-only; вердикт снимается локально)"
elif "$LINT_PY" -c 'import gdtoolkit.linter' 2>/dev/null && [ -f .gdlintrc ]; then
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
echo "=== пути узлов из скриптов ↔ сцены: сканер T-296 (гейт) ==="
# Класс «переехал блок — скрипт остался»: экраны собираются генераторами, путь
# узла — строковый литерал, а `get_node_or_null(...) is Label` делает промах
# неотличимым от успеха. GdUnit этого не видит (тест экрана проверяет своё),
# документальные гейты — тоже. Так потерялись левая колонка (D-280), строки
# надетого (T-254), рамки куклы (T-294), полоса маны и навыков (T-295).
if command -v python3 >/dev/null 2>&1; then
        if PATHS="$(cd .. && python3 scripts/check_node_paths.py 2>&1)"; then
                echo "$PATHS"
                echo "NODE-PATH-GATE: OK"
        else
                echo "NODE-PATH-GATE: RED — литерал пути не живёт в сцене (T-296):"
                echo "$PATHS"
                exit 1
        fi
else
        echo "NODE-PATH-GATE: SKIPPED (python3 не найден — уровень молчит, зафиксировать в отчёте)"
fi
# MCP-слой smoke (T-329, срез test-suite-restructure 5.3): живой Godot в слое
# smoke поднимается только по явному запросу — readiness одной пауки съедает
# бюджет 30 с, поэтому по умолчанию слой остаётся headless, а «сколько собрано»
# печатается отдельной строкой (collect-only Godot не поднимает).
MCP_SET=""
MCP_RUN=0
if [ "$TIER" = "full" ]; then
        MCP_RUN=1
elif [ "$TIER" = "smoke" ] && [ "${MCP_SMOKE:-0}" = "1" ]; then
        MCP_RUN=1
        MCP_SET="smoke"
fi
if [ "$MCP_RUN" != "1" ]; then
        echo ""
        # «Не мерили» обязано быть видно (T-281): читатель строки «всё зелёное» обязан
        # видеть, какие уровни вообще не запускались и где их взять.
        echo "NOT MEASURED: MCP e2e (живой Godot, ~305 с) — не входит в слой $TIER; game/run_tests.sh без флага"
        if [ "$TIER" = "smoke" ]; then
                MCP_COLLECT_PY="${MCP_PYTEST_PY:-python3}"  # venv — из настроек машины
                [ -x "$MCP_COLLECT_PY" ] || MCP_COLLECT_PY="$(command -v python3 || true)"
                if [ -n "$MCP_COLLECT_PY" ] && "$MCP_COLLECT_PY" -c 'import mcp, anyio' >/dev/null 2>&1; then
                        MCP_SMOKE_N="$("$MCP_COLLECT_PY" -m pytest tests/mcp/ -m smoke --collect-only -q 2>/dev/null | grep -oE '[0-9]+/[0-9]+ tests collected' | head -1)"
                        echo "MCP SMOKE: собрано ${MCP_SMOKE_N:-?} — в слой не входят; запуск: MCP_SMOKE=1 ./run_tests.sh --tier=smoke"
                else
                        echo "MCP SMOKE: SKIPPED (интерпретатор с mcp+anyio не найден — сколько тестов помечено, не проверено)"
                fi
        fi
        echo "NOT MEASURED: python-уровни (генератор арта T-150, классификатор D-265) — не входят в слой $TIER"
        echo "NOT MEASURED: gdlint (report-only) — не входит в слой $TIER"
        echo "TIER $TIER: зелёный прогон НЕ является основанием для push — публикация требует зелёного full (D-224)."
        echo "GATE VERDICT: PARTIAL — слой $TIER, MCP и python-уровни не мерились; читать как «не проверялось»"
        exit 0
fi
echo ""
echo "=== MCP tests (tugcantopaloglu/godot-mcp)${MCP_SET:+ — только слой $MCP_SET} ==="
MCP_SERVER="${GODOT_MCP_SERVER:-$PWD/addons/godot-mcp/build/index.js}"
# MCP e2e-тесты запускают живой Godot (не headless) — нужен X-дисплей.
# X — не свойство «той самой машины», а настроенный ресурс (2026-11-03). Порядок:
# 1) MCP_SSH_HOST (настройка машины) — секция исполляется там, где X есть (блок
#    ниже); 2) заданный DISPLAY — используется как есть; 3) локальный Xvfb на
#    свободном номере (машина шарится: чужие дисплеи, в т.ч. с auth, не убиваем;
#    :99 исключён). Ни одного — явный SKIPPED с именем ручки.
if [ -n "${MCP_SSH_HOST:-}" ] && [ -z "${SOTU_ON_X_HOST:-}" ]; then
        SOTU_SHA="$(git -C .. rev-parse --short HEAD 2>/dev/null || echo worktree)"
        SOTU_REMOTE="${MCP_REMOTE_DIR_BASE:-/tmp/sotu-mcp}/$SOTU_SHA"
        echo "MCP: X-контур $MCP_SSH_HOST:$SOTU_REMOTE (MCP_SSH_HOST из настроек машины; GdUnit уже снят локально)"
        # Переносится ПРОВЕРЯЕМОЕ РАБОЧЕЕ ДЕРЕВО, а не HEAD: tar берёт файлы по
        # git ls-files (незакоммиченные правки участвуют) + собранный JS-бандл
        # godot-mcp (`build/`, gitignored: он результат source/ той же версии).
        # `node_modules` аддона едет обязательно: build/index.js — не самодостаточный
        # бандл, он импортирует `@modelcontextprotocol/sdk`; без зависимостей сервер
        # не стартует, и все тесты, поднимающие Godot, падают одним и тем же
        # «MCPError(-32000, 'Connection closed')» (замер 2026-11-03: 61 такая же
        # ошибка на 60 прохождений — молча, без единой строки о зависимостях).
        # 106 МБ по LAN — секунда. Путь в ls-files — от корня репо, поэтому оба шага
        # в подоболочке из `..`.
        # --no-mac-metadata/--no-xattrs: без них bsdtar (macOS) кладёт рядом с каждым
        # файлом AppleDouble-дубль `._*` (замер: 4707 файлов → 5717) и pax-заголовок
        # provenance, на который GNU tar ругается строкой на каждый файл.
        SOTU_TAR=()
        [ "$(uname -s)" = "Darwin" ] && SOTU_TAR=(--no-mac-metadata --no-xattrs)
        if ! ( cd .. && { git ls-files -z game scripts; \
                        git ls-files -z -- image-clone/etalons/manifest.json; \
                        # -L обязателен (владелец, 2026-11-09): без него find НЕ идёт ни в
                        # symlink-каталог, ни по symlink-файлам. Дерево, где node_modules —
                        # ссылка (scratch-дерево, досылка чужой сборки), уезжало на X-контур
                        # без зависимостей, и e2e молча не мерился.
                        find -L game/addons/godot-mcp/build game/addons/godot-mcp/node_modules -type f -print0 2>/dev/null; } | \
                tar "${SOTU_TAR[@]+"${SOTU_TAR[@]}"}" --null -T - -cf - | gzip -1 ) | \
                ssh -q "$MCP_SSH_HOST" "rm -rf '$SOTU_REMOTE' && mkdir -p '$SOTU_REMOTE' && tar -xzf - -C '$SOTU_REMOTE' --warning=no-unknown-keyword"; then
                echo "PYTEST: SKIPPED (дерево не выложено на $MCP_SSH_HOST — MCP-уровень не мерился; сними MCP_SSH_HOST для локального X)"
                skipped_level "MCP e2e" "дерево не выложено на $MCP_SSH_HOST"
                gate_verdict ok
                exit 0
        fi
        # Удалённый прогон — тот же скрипт целиком, только без GdUnit (он измерен здесь)
        # и с запретом рекурсивной делегации. Хвостовые python-секции исполняются там же:
        # вердикты не теряются, а удваивается только их ~10 с. Env-расширения передаются
        # явно; остальное — настройка машины на самом хосте. GdUnit не переснимается
        # только на full (на smoke SKIP_GDUNIT был бы «прогон ничего не мерил»).
        SOTU_FWD="SOTU_ON_X_HOST=1"
        [ "$TIER" = "full" ] && SOTU_FWD="$SOTU_FWD SKIP_GDUNIT=1"
        [ "${MCP_SMOKE:-0}" = "1" ] && SOTU_FWD="$SOTU_FWD MCP_SMOKE=1"
        [ -n "${MCP_WORKERS:-}" ] && SOTU_FWD="$SOTU_FWD MCP_WORKERS=$MCP_WORKERS"
        # Ключи прогона — те же, что переданы здесь; пустого аргумента быть не должно:
        # `printf '%q '` без аргументов выдаёт `''`, а удалённый скрипт честно
        # отказывается от неизвестного аргумента «» (замер 2026-11-03).
        SOTU_ARGS=""
        [ "$#" -gt 0 ] && SOTU_ARGS="$(printf '%q ' "$@")"
        ssh -q "$MCP_SSH_HOST" "cd '$SOTU_REMOTE/game' && $SOTU_FWD bash run_tests.sh $SOTU_ARGS"
        MCP_RC=$?
        echo "MCP: вердикт снят на $MCP_SSH_HOST (rc=$MCP_RC); рабочий каталог прогона удалён"
        ssh -q "$MCP_SSH_HOST" "rm -rf '$SOTU_REMOTE'" || true
        # Вердикт печатает удалённый прогон (тот же скрипт, тот же хвост); здесь — только
        # передача красного в exit-код, без перекрашивания жёлтого в зелёный.
        if [ "$MCP_RC" -ne 0 ]; then
                gate_verdict red "X-контур $MCP_SSH_HOST вернул rc=$MCP_RC"
        else
                echo "GATE VERDICT: итог — в вердикте удалённого прогона ($MCP_SSH_HOST, rc=$MCP_RC)"
        fi
        exit "$MCP_RC"
fi
if [ ! -f "$MCP_SERVER" ]; then
        echo "PYTEST: SKIPPED (no MCP server: $MCP_SERVER; build: cd addons/godot-mcp && npm ci && npm run build)"
        skipped_level "MCP e2e" "нет MCP-сервера ($MCP_SERVER)"
        gate_verdict ok
        exit 0
fi
# Зависимости аддона — не «деталь сборки», а условие того, что сервер вообще
# запустится: build/index.js импортирует @modelcontextprotocol/sdk. Без проверки
# уровень молча краснел 61 одинаковой «Connection closed» (2026-11-03).
# node_modules — сосед build/, не его вложение.
if [ ! -d "$(dirname "$(dirname "$MCP_SERVER")")/node_modules" ]; then
        echo "PYTEST: SKIPPED (нет node_modules у $MCP_SERVER — npm ci в game/addons/godot-mcp/; без них сервер не стартует)"
        echo "MCP VERDICT: SKIPPED (зависимости godot-mcp не установлены — уровень не мерился)"
        skipped_level "MCP e2e" "нет node_modules у $MCP_SERVER"
        gate_verdict ok
        exit 0
fi
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
                echo "PYTEST: SKIPPED (X-дисплея нет: DISPLAY не задан, свободного Xvfb :91–:98 не нашли, MCP_SSH_HOST не задан — настройка машины $SOTU_MACHINE_ENV)"
                skipped_level "MCP e2e" "X-дисплея нет (DISPLAY, Xvfb :91–:98, MCP_SSH_HOST пусты)"
                gate_verdict ok
                exit 0
        fi
fi
# venv MCP-тестов: путь — настройка машины (MCP_PYTEST_PY), в репозитории его нет.
# Если venv не задан/не исполняемый — системный python3 с mcp+anyio (проверяемая
# конфигурация, владелец 2026-10-04: MCP-секция исполняется, а не пропускается).
PYTEST_PY="${MCP_PYTEST_PY:-}"
if [ ! -x "$PYTEST_PY" ]; then
        if command -v python3 >/dev/null 2>&1 && python3 -c 'import mcp, anyio' 2>/dev/null; then
                PYTEST_PY="$(command -v python3)"
        else
                echo "PYTEST: SKIPPED (MCP_PYTEST_PY не задан/не исполняемый: «$PYTEST_PY», и нет python3 с mcp+anyio; настройка машины $SOTU_MACHINE_ENV: python3 -m venv <путь> && <путь>/bin/pip install pytest pytest-timeout mcp anyio)"
                skipped_level "MCP e2e" "интерпретатора MCP-тестов нет (MCP_PYTEST_PY, python3 с mcp+anyio)"
                gate_verdict ok
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
# D-265: машинно-читаемый журнал той же секции (по нему readiness отличается от регрессии).
JUNIT_MCP="$(mktemp)"
# Фильтр по маркеру: слой smoke с MCP_SMOKE=1 берёт только помеченное (T-329);
# полный прогон — весь набор (пустой массив = никакого `-m`).
MCP_MARK=()
[ -n "$MCP_SET" ] && MCP_MARK=(-m "$MCP_SET")
JUNIT_PERF="$(mktemp)"
PERF_IGNORE=()
[ "$PERF_SERIAL" -eq 1 ] && PERF_IGNORE=(--ignore=tests/mcp/test_hexutils_perf.py)
# GODOT_PATH/GODOT_BIN — export'ом, а не префиксом команды (T-281). Префикс
# `VAR=value \` рвётся от любой строки между ним и командой — в том числе от
# комментария (урок 2026-10-05 ниже), и pytest тогда молча берёт путь по умолчанию
# (/Applications/…), а пять life-cycle тестов «закрашиваются» пропуском. Export
# нечего рвать: проверка «env дошёл» осталась отдельным уровнем ниже.
export GODOT_PATH="$GODOT"
export GODOT_BIN="$GODOT"
# -rs (T-281): причины пропуска в коротком резюме — см. блок PYTEST SKIPPED ниже.
"$PYTEST_PY" -m pytest tests/mcp/ -v -rs --timeout=900 --tb=short --durations=25 \
        --junitxml="$JUNIT_MCP" \
        ${MCP_MARK[@]+"${MCP_MARK[@]}"} ${PERF_IGNORE[@]+"${PERF_IGNORE[@]}"} ${PYTEST_WORKER_ARGS[@]+"${PYTEST_WORKER_ARGS[@]}"} 2>&1 | tee "$MCP_LOG"
MCP_RC=${PIPESTATUS[0]}
if [ "$PERF_SERIAL" -eq 1 ] && [ -z "$MCP_SET" ]; then
        echo "MCP: perf-стадия — serial (test_hexutils_perf.py; D-177: свободный CPU)"
        "$PYTEST_PY" -m pytest tests/mcp/test_hexutils_perf.py -v -rs --timeout=900 --tb=short \
                --junitxml="$JUNIT_PERF" \
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
# `-m <маркер>` (слой smoke с MCP_SMOKE=1, T-329): pytest дописывает
# «/ 112 deselected / 2 selected», и при фильтре «собрано» != «в свите» — без
# поправки равненство «сумма == collected» краснеет на здоровом прогоне.
# При маркере берётся явное «K selected»: такой прогон одностадийный (perf-стадия
# при фильтре не запускается), а складывать «collected» с «workers [M items]» под
# xdist значило бы считать вдвое.
sel = sumre(r"/ (\d+) selected")
if sel:
    collected = sel
else:
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

# T-281: «не мерили» обязано быть видно. Пропуск не красный, но молчание о причине
# стоит тому же, что и красный от среды: тест молча перестаёт что-либо доказывать,
# а читатель строки skipped=3 не узнаёт, какой уровень выпал и почему. Причина —
# из -rs; пустой список при ненулевом skipped = дефект отчётности, о нём ниже.
if [ "$S" -gt 0 ]; then
        SKIPS="$(sed 's/\x1b\[[0-9;]*m//g' "$MCP_LOG" | grep -aE '^SKIPPED( |\[)' | sed 's/^[[:space:]]*//' | sort -u)"
        if [ -n "$SKIPS" ]; then
                echo "PYTEST SKIPPED ($S — уровень ничего не измерил, причина обязательна):"
                printf '%s\n' "$SKIPS" | sed 's/^/  /'
        else
                echo "PYTEST SKIPPED: skipped=$S, причин в логе нет — прогон собран без -rs (дефект отчётности)"
        fi
fi
LEDGER_OK=1
[ "$SUM" -ne "$COLLECTED" ] && LEDGER_OK=0
if [ "$MCP_RC" -eq 0 ] && [ "$LEDGER_OK" -eq 0 ]; then
        echo "PYTEST: RED (неполный прогон: сумма $SUM != collected $COLLECTED — свит встал/прервался)"
        MCP_RC=1
fi
# D-265 (владелец, 2026-10-26): readiness-error — жёлтый. Красный снимается ТОЛЬКО если
# junit-журнал целиком состоит из readiness-ошибок (подпись «игра не готова за», единственный
# источник — wait_ready в tests/mcp/godot_mcp.py). Неполный прогон, неразобранный журнал и
# любой другой error красный не снимают; жёлтый печатается поимённо.
# «Godot не найден» при живом бинаре = pytest не получил GODOT_PATH: уровень,
# который ничего не мерил, не имеет права ни краснеть кодом, ни тем более зелёнеть
# (T-281 — тот же день, когда комментарий между env-префиксом и командой убрал
# из прогона пять тестов, а readiness-ошибку заодно).
MCP_ENV_BROKEN=0
if [ -x "$GODOT" ] && sed 's/\x1b\[[0-9;]*m//g' "$MCP_LOG" | grep -qaE 'Godot не найден|нет бинаря Godot'; then
        MCP_ENV_BROKEN=1
        echo "MCP: RED — тесты объявили отсутствие Godot при наличии $GODOT: путь прогона до pytest не дошёл, тесты сняли пропуском вместо замера"
        MCP_RC=1
fi
CLS="../scripts/classify_mcp_junit.py"
JUNIT_ARGS=("$JUNIT_MCP")
[ "$PERF_SERIAL" -eq 1 ] && JUNIT_ARGS+=("$JUNIT_PERF")
if [ "$MCP_ENV_BROKEN" -eq 1 ]; then
        echo "MCP VERDICT: RED (путь до pytest не дошёл — readiness-жёлтым это не снимается)"
elif [ ! -f "$CLS" ]; then
        echo "MCP READINESS: SKIPPED (нет $CLS — readiness-error остаётся красным)"
elif [ "$LEDGER_OK" -eq 0 ]; then
        echo "MCP READINESS: SKIPPED (прогон неполный — красный не снимается)"
else
        "$PYTEST_PY" "$CLS" "${JUNIT_ARGS[@]}"
        case $? in
                0) : ;;
                3)
                        MCP_YELLOW=1
                        if [ "$MCP_RC" -ne 0 ]; then
                                echo "MCP READINESS: YELLOW — красный снят как readiness, не регрессия (D-265)"
                                MCP_RC=0
                        fi
                        ;;
                1) MCP_RC=1 ;;
                *) echo "MCP READINESS: журнал не разобран — readiness-error остаётся красным" ;;
        esac
fi
# Python-гейт генератора арта (T-150): `scripts/test_gen_map_art.py` не входит ни в одну
# секцию выше (MCP-секция знает только tests/mcp/), а без него затемнённый побратим листа
# и кратность MAP_FOG_DIM проверялись бы только руками. Секция не молчит: нет pytest/PIL —
# явная строка SKIPPED (конвенция MCP-секции).
echo "=== python: генератор арта карты (scripts/test_gen_map_art.py) + концепт-арта (scripts/concept_art/test_generate.py) ==="
# T-289 (D-166-семья): уровень желтел, хотя интерпретатор с pytest+PIL был установлен
# (замер 2026-10-29: pytest 9.1.1, PIL 13.0.0, 11 тестов уровня за 2.3 с) — проверка
# `import pytest, PIL` отвечала честно про не тот интерпретатор, дефолт был `python3`.
# Перебираем кандидатов и ПЕЧАТАЕМ выбранного — жёлтый обязан называть причину. С 2026-11-03
# среди кандидатов нет пути чужой машины: venv с PIL задаёт настройка машины (GEN_PY,
# а где её нет — MCP_PYTEST_PY, его venv тоже носит Pillow).
GEN_CANDIDATES=("${GEN_PY:-}" "${MCP_PYTEST_PY:-}" "python3")
GEN_PY=""
for gen_cand in "${GEN_CANDIDATES[@]}"; do
        [ -n "$gen_cand" ] || continue
        if "$gen_cand" -c 'import pytest, PIL' 2>/dev/null; then
                GEN_PY="$gen_cand"
                break
        fi
done
if [ -n "$GEN_PY" ]; then
        echo "GENART: интерпретатор $GEN_PY"
        # T-291 (D-307): самопроверка генератора концепт-арта исполнима без пикселей эталонов
        # (`load_spec(check_files=False)` сверяет манифест), поэтому ей есть что проверять и на
        # чистой машине — до 2026-11-08 она только скипалась и в гейт не попадала вовсе.
        # -p no:warnings: Pillow-предупреждения вытесняли строку со счётчиком из `tail -5`,
        # и секция показывала warnings вместо вердикта (замер прогона 2026-11-08).
        "$GEN_PY" -m pytest ../scripts/test_gen_map_art.py ../scripts/concept_art/test_generate.py -q --tb=short -p no:warnings 2>&1 | tail -3
        [ "${PIPESTATUS[0]}" -ne 0 ] && MCP_RC=1
else
        echo "GENART: SKIPPED (ни один кандидат не импортирует pytest+PIL: ${GEN_CANDIDATES[*]} — GEN_PY в настройку машины $SOTU_MACHINE_ENV)"
        skipped_level "GENART" "нет интерпретатора с pytest+PIL"
fi

# Сами-тест классификатора (D-265): тот решает, что считать жёлтым, и обязан краснеть сам,
# а не молчать. PYTHONPATH не нужен — файл лежит рядом и импортируется по пути.
echo "=== python: классификатор MCP-журнала (scripts/test_classify_mcp_junit.py) ==="
if "$PYTEST_PY" -c 'import pytest' 2>/dev/null; then
        "$PYTEST_PY" -m pytest ../scripts/test_classify_mcp_junit.py -q --tb=short -p no:cacheprovider 2>&1 | tail -3
        # Вердикт печатается явно: «секция молча прошла» и «секция не запустилась» не должны
        # различаться тишиной (тот же аргумент, что у жёлтого статуса D-265).
        if [ "${PIPESTATUS[0]}" -eq 0 ]; then
                echo "READINESS-CLASSIFIER: selftest GREEN"
        else
                echo "READINESS-CLASSIFIER: selftest RED — классификатор сломан, его «жёлтому» гейт не верит"
                MCP_RC=1
        fi
else
        echo "READINESS-CLASSIFIER: SKIPPED (нет pytest в $PYTEST_PY)"
        skipped_level "READINESS-CLASSIFIER" "нет pytest в $PYTEST_PY"
fi

# Очистка (Xvfb, инжект-артефакты, node/godot MCP-процессы) — в trap cleanup_mcp (EXIT).
echo "MCP VERDICT: exit=$MCP_RC (0 = зелёный или readiness-жёлтый D-265; 100/1/2 — красный)"
gate_verdict "$([ "$MCP_RC" -eq 0 ] && echo ok || echo red)" "MCP/pytest вернул rc=$MCP_RC"
exit "$MCP_RC"

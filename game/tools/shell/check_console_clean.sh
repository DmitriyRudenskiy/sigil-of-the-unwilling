#!/usr/bin/env bash
# check_console_clean.sh — гейт чистоты консоли (change: console-hygiene).
#
# Прогоняет сценарии N... (по умолчанию 1..5) через play_scenario.sh с
# отдельным логом на сценарий и сканирует логи по таксономии godot-run-and-fix:
#
#   • маркеры error-класса — FAIL (allowlist для ошибок НЕ существует —
#     ошибку надо чинить в корне, не гасить);
#   • маркеры warning-класса — FAIL, если строка не совпадает с allowlist
#     (docs/CONSOLE_ALLOWLIST.md, первый столбец таблицы, ERE; файл опционален —
#     нет файла = строгий режим);
#   • строки app-логгера (содержат `[color=`) исключаются ДО скана:
#     GameLogger.error/warn — намеренные логи приложения, не регрессия кода
#     (иначе каждая push_error() на обработанном состоянии валила бы гейт);
#   • exit-код сценария != 0 — FAIL.
#
# Использование:
#   check_console_clean.sh            # сценарии 1..5
#   check_console_clean.sh 3 5        # только сценарии 3 и 5
#
# Служебный режим (для sanity-проверок гейта, без прогона сценариев):
#   check_console_clean.sh --scan <logfile...>
#
# Exit: 0 — все сценарии exit 0 и консоль чиста; 1 — находки/провал сценария.
# macOS-safe: нет `timeout` — play_scenario.sh сам обёрнут в kill-обёртку.
# Совместим с bash 3.2 (macOS).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
ALLOWLIST="$REPO_DIR/docs/CONSOLE_ALLOWLIST.md"
LOG_DIR="${LOG_DIR:-/tmp/godot_console}"

# ==================================================== 1. Таксономия маркеров
# ОШИБКИ — любая строка валит гейт (суперсет godot-run-and-fix + CI-маркеры).
ERROR_RE='SCRIPT ERROR|Parse error|Invalid call|Nonexistent function|Nonexistent class|Nonexistent base|Too many arguments|Cannot infer|Invalid get/set|Failed to load script|Can'"'"'t load script|Could not find type|does not inherit from|^E 0:|^ERROR:'
# ПРЕДУПРЕЖДЕНИЯ — валит, только если НЕ в allowlist.
WARN_RE='^WARNING|^NOTICE|LEAK|leaked|deprecated|^W 0:'
# ЛОЖНЫЕ СРАБАТЫВАНИЯ — лог САМОГО приложения (GameLogger: каждая строка несёт
# цвет-тег [color=gray][Tag][/color]). Это намеренные логи, не регрессия кода:
#   ERROR: [color=gray][Save ][/color] SaveManager: parse error ...
#   WARNING: [color=gray][SocketServer  ][/color] Buffer overflow ...
# Строки движка (SCRIPT ERROR/parse/leak) цвет-тегов не содержат.
EXCLUDE_RE='\[color='

# ==================================================== 2. Allowlist
# Таблица `| pattern | ... |` — берём первый столбец, чистим от бэкттиков/пробелов,
# склеиваем через `|` (ERE-альтернатива; без ведущего/трейлинг-разделителя,
# иначе пустая альтернатива совпадает со всем).
ALLOW_JOINED=""
load_allowlist() {
    [ -f "$ALLOWLIST" ] || return 0
    local line pat p
    local -a arr=()
    while IFS= read -r line; do
        case "$line" in
            "|"*) ;;
            *) continue ;;
        esac
        pat="${line#|}"; pat="${pat%%|*}"
        # trim + strip backticks (в файле паттерны оформлены как `code`)
        pat="$(printf '%s' "$pat" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/`//g')"
        case "$pat" in
            ""|---*|Pattern) continue ;;
        esac
        arr+=("$pat")
    done < "$ALLOWLIST"
    for p in "${arr[@]:-}"; do
        [ -n "$p" ] || continue
        ALLOW_JOINED="${ALLOW_JOINED:+$ALLOW_JOINED|}$p"
    done
}

# ==================================================== 3. Скан одного лога
# Печатает в stdout: сначала error-строки (уникальные), затем un-allowed
# warning-строки (уникальные). Возврат: 0 = чисто, 1 = есть находки.
# Аргумент: <путь к логу>
scan_log() {
    local f="$1"
    local err_lines warn_lines
    [ -f "$f" ] || { echo "  ❌ лог не найден: $f"; return 1; }
    # app-логгер исключаем ДО классификации
    err_lines="$(grep -E "$ERROR_RE" "$f" | grep -vE "$EXCLUDE_RE" | sort -u || true)"
    warn_lines="$(grep -E "$WARN_RE" "$f" | grep -vE "$EXCLUDE_RE" || true)"
    if [ -n "$ALLOW_JOINED" ]; then
        warn_lines="$(printf '%s\n' "$warn_lines" | grep -vE "$ALLOW_JOINED" || true)"
    fi
    [ -z "$warn_lines" ] && warn_lines=""
    if [ -n "$err_lines" ]; then
        echo "  ❌ error-класс ($(printf '%s\n' "$err_lines" | wc -l | tr -d ' ') уникальных строк):"
        printf '%s\n' "$err_lines" | head -n 10 | sed 's/^/     /'
        return 1
    fi
    if [ -n "$warn_lines" ]; then
        echo "  ❌ un-allowed warning ($(printf '%s\n' "$warn_lines" | wc -l | tr -d ' ') уникальных строк):"
        printf '%s\n' "$warn_lines" | head -n 10 | sed 's/^/     /'
        return 1
    fi
    return 0
}

# ==================================================== 4. Режимы
TOTAL_FAIL=0
SCENARIO_SUMMARY=""

# --- 4a. --scan <logfile...>: только скан заданных логов (sanity-проверки) ---
if [ "${1:-}" = "--scan" ]; then
    shift
    [ "$#" -gt 0 ] || { echo "Использование: $0 --scan <logfile...>" >&2; exit 2; }
    load_allowlist
    for f in "$@"; do
        echo "--- скан: $f"
        if scan_log "$f"; then
            echo "  ✅ CLEAN"
        else
            TOTAL_FAIL=1
        fi
    done
    echo ""
    if [ "$TOTAL_FAIL" -eq 0 ]; then
        echo "🧹 SCAN: чисто"
    else
        echo "🧹 SCAN: DIRTY" >&2
    fi
    exit "$TOTAL_FAIL"
fi

# --- 4b. Прогон сценариев: [N ...], по умолчанию 1..5 ---
SCENARIOS=()
for a in "$@"; do
    case "$a" in
        ""|*[!0-9]*) echo "Ожидаются номера сценариев (или --scan): $*" >&2; exit 2 ;;
    esac
    SCENARIOS+=("$a")
done
[ "${#SCENARIOS[@]}" -gt 0 ] || SCENARIOS=(1 2 3 4 5)

mkdir -p "$LOG_DIR"
load_allowlist

echo "🧹 Console clean: сценарии ${SCENARIOS[*]} (логи: $LOG_DIR)"
if [ -n "$ALLOW_JOINED" ]; then
    echo "   allowlist: $(wc -l < "$ALLOWLIST" 2>/dev/null | tr -d ' ') строк файла, активных паттернов: $(printf '%s' "$ALLOW_JOINED" | awk -F'|' '{print NF}')"
else
    echo "   allowlist: нет (строгий режим)"
fi

for N in "${SCENARIOS[@]}"; do
    LOG="$LOG_DIR/console_$N.log"
    echo ""
    echo "--- сценарий $N ($LOG)"
    # play_scenario.sh сам убивает Godot (kill-обёртка), exit — его же
    if bash "$SCRIPT_DIR/play_scenario.sh" "$N" --log "$LOG" >"$LOG_DIR/driver_$N.log" 2>&1; then
        EXIT_N=0
    else
        EXIT_N=$?
    fi
    tail -n 3 "$LOG_DIR/driver_$N.log" | sed 's/^/   /'
    SCAN_OK=1
    scan_log "$LOG" || SCAN_OK=0
    if [ "$EXIT_N" -ne 0 ]; then
        echo "  ❌ сценарий $N: exit=$EXIT_N"
        SCENARIO_SUMMARY="${SCENARIO_SUMMARY}  • сценарий $N: FAIL (exit=$EXIT_N)\n"
        TOTAL_FAIL=1
    elif [ "$SCAN_OK" -eq 0 ]; then
        echo "  ❌ сценарий $N: консоль DIRTY"
        SCENARIO_SUMMARY="${SCENARIO_SUMMARY}  • сценарий $N: FAIL (консоль dirty)\n"
        TOTAL_FAIL=1
    else
        echo "  ✅ сценарий $N: exit=0, консоль чиста"
        SCENARIO_SUMMARY="${SCENARIO_SUMMARY}  • сценарий $N: CLEAN\n"
    fi
done

echo ""
echo "=== Итог ==="
printf "%b" "$SCENARIO_SUMMARY"
if [ "$TOTAL_FAIL" -eq 0 ]; then
    echo "🧹 CONSOLE CLEAN: все сценарии exit 0, error-маркеров нет, un-allowed warning нет."
    exit 0
else
    echo "🧹 CONSOLE DIRTY: см. находки выше." >&2
    exit 1
fi

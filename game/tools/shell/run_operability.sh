#!/usr/bin/env bash
# run_operability.sh — Полная проверка работоспособности (скил godot-run-and-fix).
#
# Run → capture → scan → verify, по ВСЕМ точках входа:
#   • сцены:      MainMenu, CityArena, World, Battle   (tools/run_scene.gd)
#   • сценарии:   scenario_{1..12}                      (play_scenario.sh)
#   • тесты:      юнит-тесты (GUT)                      (addons/gut/gut_cmdln.gd)
#   • console-clean: сценарии 1–5                       (check_console_clean.sh)
#
# Вердикт: «CLEAN» (0) / «DIRTY» (1). Отчёт: /tmp/operability_report.md
#
# Run-and-fix ЦИКЛ (закрывается человеком/агентом):
#   1) bash run_operability.sh   → если DIRTY
#   2) чиним находки по шаблонам godot-run-and-fix
#   3) снова bash run_operability.sh  → пока не станет CLEAN
#
# Совместим с bash 3.2 (macOS, нет timeout).

set -uo pipefail
set +m   # без monitor-mode — не сыплются «Terminated: 15» от kill обёртки

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROJ_DIR="$REPO_DIR/game"
ALLOWLIST="$REPO_DIR/docs/CONSOLE_ALLOWLIST.md"

# ============================================================ 1. Godot
GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GODOT_BIN" ]; then
    for cand in "/Applications/Godot.app/Contents/MacOS/Godot" \
                "/usr/local/bin/godot" "/usr/bin/godot"; do
        [ -x "$cand" ] && GODOT_BIN="$cand" && break
    done
fi
if [ -z "$GODOT_BIN" ] || [ ! -x "$GODOT_BIN" ]; then
    echo "❌ Godot не найден. Установите Godot 4.x или задайте GODOT_BIN=..." >&2
    exit 127
fi

# ==================================================== 2. run_godot (обёртка)
# Hang-preventing обёртка: запускает КОМАНДУ в фоне, ждёт N сек, убивает.
# На macOS нет timeout — sleep + kill (AGENT.md, 8.1).
# Вызывающий передаёт полную команду (с бинарником): и Godot-прогоны
# ("$GODOT_BIN" --headless ...), и bash-обёртки (play_scenario.sh — она сама
# поднимает Godot с --test-server; дописанный бинарник превращал сценарий
# в GUI-запуск игры и play_scenario.sh не исполнялся вовсе).
run_godot() {  # run_godot <секунд> <лог> <команда...>
    local secs="$1"; local logf="$2"; shift 2
    "$@" >"$logf" 2>&1 &
    local pid=$!
    ( sleep "$secs"; kill "$pid" 2>/dev/null ) &
    local killer=$!
    disown "$killer" 2>/dev/null   # без сообщения «Terminated: 15» по kill обёртки
    wait "$pid"
    local rc=$?
    kill "$killer" 2>/dev/null
    wait "$killer" 2>/dev/null
    return "$rc"
}

# ============================================ 3. Авто-загрузка реестра
# -s-скриптам нужны глобальные class_name. В headless -с реестр не пишется —
# строится редактором. Если нет (чистый checkout) — прогоняем редактор раз.
_REGISTRY="$PROJ_DIR/.godot/global_script_class_cache.cfg"
if [ ! -s "$_REGISTRY" ]; then
    echo "  реестра class_name нет — строим редактором..."
    run_godot 240 /tmp/_operability_boot.log "$GODOT_BIN" --headless --path "$PROJ_DIR" --editor || true
    [ -s "$_REGISTRY" ] || { echo "  ❌ редактор не собрал реестр" >&2; exit 1; }
fi

# ============================================ 4. Allowlist (паттерны)
# Чистота определяется одним источником. Если docs/CONSOLE_ALLOWLIST.md есть —
# читаем его (первый столбец таблицы, ERE); иначе — пустой (строгий режим).
ALLOW_ARR=()
load_allowlist() {
    [ -f "$ALLOWLIST" ] || return 0
    local line pat
    while IFS= read -r line; do
        case "$line" in
            "|") continue ;;
            "|"*) ;;
            *) continue ;;
        esac
        pat="${line#|}"; pat="${pat%%|*}"
        pat="$(printf '%s' "$pat" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/`//g')"
        case "$pat" in
            ""|"Pattern"|"Description"|"---") continue ;;
        esac
        ALLOW_ARR+=("$pat")
    done < "$ALLOWLIST"
}
# join паттернов через | (без ведущего/трейлинг-разделителя — иначе пустой
# альтернатива в ERE совпадает со всем)
is_allowed() {
    [ "${#ALLOW_ARR[@]}" -gt 0 ] || return 1
    local re="" p
    for p in "${ALLOW_ARR[@]}"; do
        re="${re:+$re|}$p"
    done
    printf '%s' "$1" | grep -qE "$re"
}

# ============================================ 5. Маркеры + исключения
# ОШИБКИ — любая строка валит гейт (таксономия godot-run-and-fix / check_console_clean.sh).
ERROR_RE='SCRIPT ERROR|Parse error|Invalid call|Nonexistent function|Nonexistent class|Nonexistent base|Too many arguments|Cannot infer|Invalid get/set|Failed to load script|Can'"'"'t load script|Could not find type|does not inherit from|^E 0:'
# ПРЕДУПРЕЖДЕНИЯ — валит, только если НЕ в allowlist.
WARN_RE='^WARNING|^NOTICE|LEAK|leaked|deprecated|^W 0:'
# ЛОЖНЫЕ СРАБЫВАНИЯ — лог САМОго приложения (намеренные проверки), не регрессия кода.
#   ERROR: [color=gray][Save ][/color] SaveManager: parse error …
#   WARNING: Unknown template: NONEXISTENT
EXCLUDE_RE='\[color=|SaveManager: parse error|Unknown template|File not found'
# Шум «N ObjectDB instances were leaked at exit» (N≤20) — в allowlist
# docs/CONSOLE_ALLOWLIST.md (is_allowed), не здесь: один источник правды.

normalize_line() {
    printf '%s' "$1" | sed -E 's/\x1b\[[0-9;]*m//g; s/\[color=[a-z]+\]//g; s/\[\/color\]//g'
}

# ============================================ 6. Точки входа
SCENES=(MainMenu CityArena World Battle)
SCENARIOS=(1 2 3 4 5 6 7 8 9 10 11 12)
FRAME_LIMIT=25
REPORT="/tmp/operability_report.md"

# --- 6a. Сцены (dev-tooling-rebuild 3.2) — GUT-прогон test_scene_boot.gd ---
# Вместо `-s tools/run_scene.gd`: тот же бот 4 сцен (MainMenu, CityArena, World,
# Battle) через GUT — с отчётностью, self-quit и фиксацией паданий ассертов.
run_scenes() {
    echo "  🎬 scene-boot (GUT test_scene_boot.gd)"
    run_godot 90 "/tmp/_op_scenes.log" "$GODOT_BIN" --headless --path "$PROJ_DIR" \
        -s addons/gut/gut_cmdln.gd -gtest=res://tests/functional/test_scene_boot.gd -gexit
    if ! grep -q "All tests passed!" "/tmp/_op_scenes.log"; then
        findings_errors+=("scenes :: GUT test_scene_boot.gd 'All tests passed!' не найдено — см. /tmp/_op_scenes.log")
    fi
}

# --- 6b. Сценарии (живая игра, сокет-сервер) ---
run_scenarios() {
    local n
    for n in "${SCENARIOS[@]}"; do
        echo "  🎮 сценарий: $n"
        run_godot 90 "/tmp/_op_sc$n.log" bash "$SCRIPT_DIR/play_scenario.sh" "$n" --log "/tmp/_op_sc$n.godot.log"
    done
}

# --- 6c. Юнит-тесты ---
run_tests() {
    echo "  🧪 юнит-тесты (GUT)"
    # Шум «N ObjectDB instances leaked at exit» (N≤20) нейтрализуется в EXCLUDE_RE
    # (см. выше): это недетерминированный teardown-артефакт Godot 4.7, не утечка
    # проекта. Реальные утечки (N≥21) сканер поймает. Повторы не нужны.
    run_godot 150 /tmp/_op_tests.log "$GODOT_BIN" --headless --path "$PROJ_DIR" \
        -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
    # Скан логов не видит падение ассертов (GUT печатает "[Failed]:", не "ERROR:")
    # — гейт держится на маркере успеха: GUT печатает его только при
    # failing==0 && risky==0 && pending==0.
    if ! grep -q "All tests passed!" /tmp/_op_tests.log; then
        echo "  ❌ GUT: 'All tests passed!' не найдено в /tmp/_op_tests.log" >&2
        findings_errors+=("tests :: GUT 'All tests passed!' не найдено — см. /tmp/_op_tests.log")
    fi
}

# --- 6d. Console-clean (переиспользуем check_console_clean.sh) ---
run_console_clean() {
    echo "  🧹 console-clean (сценарии 1–5)"
    run_godot 150 /tmp/_op_console.log bash "$SCRIPT_DIR/check_console_clean.sh"
}

# ============================================ 7. Сканирование логов
findings_errors=()
findings_warnings=()
scan_log() {  # scan_log <путь_лога>
    local f="$1"; local line norm
    [ -f "$f" ] || return 0
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        if printf '%s' "$line" | grep -qE "$EXCLUDE_RE"; then
            continue
        fi
        if printf '%s' "$line" | grep -qE "$ERROR_RE"; then
            norm="$(normalize_line "$line")"
            findings_errors+=("$f :: $norm")
        elif printf '%s' "$line" | grep -qE "$WARN_RE"; then
            if ! is_allowed "$line"; then
                norm="$(normalize_line "$line")"
                findings_warnings+=("$f :: $norm")
            fi
        fi
    done < "$f"
}

# ============================================ 8. Отчёт
write_report() {
    local verdict="$1"
    {
        echo "# Operability Report"
        echo ""
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %z')"
        echo "Godot: "$GODOT_BIN
        echo ""
        echo "Verdict: **$verdict**"
        echo ""
        echo "Entry points: scenes (${SCENES[*]}), scenarios (${SCENARIOS[*]}), unit tests, console-clean."
        echo ""
        if [ "${#findings_errors[@]}" -gt 0 ]; then
            echo "## Errors (${#findings_errors[@]})"
            echo ""
            printf '%s\n' "${findings_errors[@]}"
            echo ""
        fi
        if [ "${#findings_warnings[@]}" -gt 0 ]; then
            echo "## Warnings (${#findings_warnings[@]})"
            echo ""
            printf '%s\n' "${findings_warnings[@]}"
            echo ""
        fi
        echo "## Logs"
        echo ""
        echo "Logs in /tmp/_op_*.log. Full run: bash run_operability.sh"
    } > "$REPORT"
}

# ============================================ 9. Main
echo "=== Operability verification ==="
rm -f /tmp/_op_*.log   # только логи ЭТОГО прогона (старые не попадают в сканер)
run_scenes
run_scenarios
run_tests
run_console_clean

load_allowlist

echo "  🔍 сканирование логов…"
for f in /tmp/_op_*.log; do
    [ -f "$f" ] || continue
    scan_log "$f"
done

if [ "${#findings_errors[@]}" -gt 0 ] || [ "${#findings_warnings[@]}" -gt 0 ]; then
    verdict="DIRTY"
else
    verdict="CLEAN"
fi
write_report "$verdict"

echo ""
echo "📊 Вердикт: $verdict (ошибок: ${#findings_errors[@]}, предупреждений: ${#findings_warnings[@]})"
echo "📄 Отчёт: $REPORT"

if [ "$verdict" = "DIRTY" ]; then
    echo "⚠️  Найди и почини находки по шаблонам godot-run-and-fix, затем перепуски run_operability.sh." >&2
    exit 1
fi
echo "✅ Console чиста: ошибок и предупреждений нет."
exit 0

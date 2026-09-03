#!/usr/bin/env bash
# run_all_scenarios.sh — прогон всех сокет-сценариев (cycle: auto-game-scenarios).
#
#   ./tools/shell/run_all_scenarios.sh            # все сценарии (1–12 + shard 13)
#   ./tools/shell/run_all_scenarios.sh <n...>     # только указанные номера
#
# Для сценариев 1–12: свежий Godot-сервер на 9095 на каждый сценарий
# (play_scenario.sh) → код сценария 0 = passed. Для сценария 13 (shard) —
# запуск напрямую (он поднимает свой сервер сам).
#
# Отчёт: PASS/FAIL по каждому сценарию, финальный exit ≠0 при любом FAIL.
# Совместим с bash 3.2 (macOS, нет timeout).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SC_DIR="$REPO_DIR/game/tools/scenarios"

# Сценарии 1–12 коннектятся к серверу play_scenario.sh; 13 — сам поднимает свой.
CONNECTING=(1 2 3 4 5 6 7 8 9 10 11 12)
SELFHOSTED=(13)

run_one() {  # run_one <number>
    local n="$1"
    echo "─────────────────────────────"
    if printf '%s\n' "${CONNECTING[@]}" | grep -qx "$n"; then
        bash "$SCRIPT_DIR/play_scenario.sh" "$n" --log "/tmp/_sc$n.godot.log" 2>&1
        return $?
    elif printf '%s\n' "${SELFHOSTED[@]}" | grep -qx "$n"; then
        mkdir -p "$REPO_DIR/tmp"
        ( cd "$REPO_DIR" && python3 "game/tools/scenarios/scenario_${n}_shard.py" ) 2>&1
        return $?
    else
        echo "  ⚠️  сценарий $n не в списке"
        return 2
    fi
}

# Аргументы — номера; пусто → все.
if [ "$#" -gt 0 ]; then
    TARGETS=("$@")
else
    TARGETS=("${CONNECTING[@]}" "${SELFHOSTED[@]}")
fi

PASS=0
FAIL=0
declare -a FAILED_SCEN=()

for n in "${TARGETS[@]}"; do
    if run_one "$n"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        FAILED_SCEN+=("$n")
    fi
done

echo "─────────────────────────────"
echo "📊 Сценарии: PASS=$PASS FAIL=$FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "  ❌ Не прошли: ${FAILED_SCEN[*]}"
    exit 1
fi
echo "  ✅ Все сценарии прошли."
exit 0

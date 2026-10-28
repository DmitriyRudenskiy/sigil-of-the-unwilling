#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без этого
# shim'а каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит»,
# ничего не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	# есть gtimeout — работаем им; нет — исполняем команду без ограничения времени
	# (сдвиг аргумента: $1 — длительность, а не команда).
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная батарея гейта «Собиратель: узлы ≠ единицы» (задача 4.2 цикла
# scenario-matrix-behavior-reliability, T-210). Каждый мутант обязан покраснить
# test_collector_nodes_vs_units.gd; зелёный мутант = дыра меры.
#
# Мутации бьют по всем трём слоям: счётчик узлов (M1, M2), мера цели (M3 — единицы
# заменены узлами), сброс между профилями одного процесса (M4), политика выбора цели
# (M5 — дубли «в поле зрения», M6 — обычный ресурс объявлен редким), отчёт роли
# (M7 — ключа rare_nodes нет, строка матрицы снова слепая).
#
# Запуск: bash game/tools/mut_collector_nodes.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/probe/test_collector_nodes_vs_units.gd
PILOT=game/scripts/probe/ScenarioPilot.gd
ROLE=game/scripts/probe/CollectorRole.gd
FAILED=0

run() {
	local name="$1"
	local out
	# Классификатор читает ВСЮ тройку «N test cases | E errors | F failures»: прогон, в
	# котором не нашлось ни одного теста (конфликт с чужим Godot-процессом на шаренной
	# машине — урок 2026-10-26, когда мутант отдал «0 errors | 0 failures» и был засчитан
	# зелёным), обязан считаться нечитаемым, а не зелёным.
	wait_for_godot
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "[0-9]+ test cases \| [0-9]+ errors \| [0-9]+ failures" | tail -1)
	echo "$name: $out"
	case "$out" in
	"" | "0 test cases |"*)
		echo "  !! НЕЧИТАЕМЫЙ ПРОГОН (0 тестов или пустой вывод) — мутант не засчитан"
		FAILED=1
		;;
	*"0 errors | 0 failures"*)
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — гейт не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$2"
}

# На шаренной машине нельзя запускать второй Godot, пока жив первый (протокол зависших
# процессов): ждём освобождения, чужое не убиваем.
wait_for_godot() {
	local waited=0
	while pgrep -x godot >/dev/null 2>&1; do
		sleep 5
		waited=$((waited + 5))
		if [ "$waited" -ge 300 ]; then
			echo "  !! godot не освобождает машину 5 минут — прогон прерван"
			exit 1
		fi
	done
}

mutate() { # файл, python-выражение
	python3 - "$1" "$2" <<'PY'
import sys, pathlib
path, body = sys.argv[1], sys.argv[2]
p = pathlib.Path(path); s0 = p.read_text(encoding="utf-8"); s = s0
exec(body)
assert s != s0, "МУТАЦИЯ НЕ ПРИМЕНИЛАСЬ: %s" % path
p.write_text(s, encoding="utf-8")
PY
}

# M1 — узлы редкой добычи не считаются.
mutate "$PILOT" 's = s.replace("\t\t_rare_count += amount\n\t\t_rare_nodes += 1", "\t\t_rare_count += amount", 1)'
run M1 "$PILOT"

# M2 — узлы добычи вообще не считаются.
mutate "$PILOT" 's = s.replace("\textracted_nodes += 1\n", "", 1)'
run M2 "$PILOT"

# M3 — мера цели переехала в узлы (то, что запрещает задача 4.2): 50 единиц золота
# перестают быть 50 единицами.
mutate "$PILOT" 's = s.replace("\t\t_rare_count += amount", "\t\t_rare_count += 1", 1)'
run M3 "$PILOT"

# M4 — сброс счётчиков между профилями одного процесса не полный.
mutate "$PILOT" 's = s.replace("\t_rare_nodes = 0\n\textracted_total = 0", "\textracted_total = 0", 1)'
run M4 "$PILOT"

# M5 — «в поле зрения» считает повторный выбор той же клетки.
mutate "$ROLE" 's = s.replace("\tif not _seen_targets.has(best):", "\tif true:", 1)'
run M5 "$ROLE"

# M6 — фильтр редкости снят: обычный ресурс становится целью Собирателя.
mutate "$ROLE" 's = s.replace("\t\tif rt < 0 or not (target.get(\"rare_ids\", []) as Array).has(rt):", "\t\tif rt < 0:", 1)'
run M6 "$ROLE"

# M7 — отчёт роли потерял число узлов: строка матрицы снова не отличает «10 единиц»
# от «10 ресурсов».
mutate "$ROLE" 's = s.replace("\t\t\"rare_nodes\": pilot.rare_nodes(),\n", "", 1)'
run M7 "$ROLE"

echo "ИТОГ: $([ "$FAILED" -eq 0 ] && echo "все мутанты красные (гейт держит)" || echo "ЕСТЬ ЗЕЛЁНЫЕ — гейт дырявый")"
git status --porcelain | grep -v "^??" || echo "дерево чистое"

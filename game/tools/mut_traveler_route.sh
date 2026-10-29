#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без этого
# shim'а каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит»,
# ничего не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	# есть gtimeout — работаем им; нет — исполняем команду без ограничения времени
	# (сдвиг аргумента: $1 — длительность, а не команда).
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная батарея гейта «маршрут Путешественника» (задача 5.3 цикла
# scenario-matrix-behavior-reliability). Каждый мутант обязан покраснить
# test_traveler_route.gd; зелёный мутант = дыра гейта.
#
# Слои меры: счётчик типов террейна (T1 — повторный биом растит счётчик, T6 — метрика
# обнулена), прибытие (T2 — цель без клетки, T3 — arrived всегда истина), отказ на
# пустой карте (T4), откат на дальнюю клетку при пустом кольце (T5), и зуб пина
# «биомы не входят в цель» (T7 — порог встроен в цель, пин обязан покраснеть).
#
# Запуск: bash game/tools/mut_traveler_route.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/probe/test_traveler_route.gd
ROLE=game/scripts/probe/traveler_role.gd
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

# T1 — повторный биом увеличивает счётчик (запрещено задачей 5.1).
mutate "$ROLE" 's = s.replace("\tif tid >= 0 and not _biomes.has(tid):", "\tif tid >= 0:", 1)'
run T1 "$ROLE"

# T2 — прибытие перестало быть клеткой цели.
mutate "$ROLE" 's = s.replace("\treturn _target != Vector2i(-1, -1) and pilot._hero_cell() == _target", "\treturn _target != Vector2i(-1, -1)", 1)'
run T2 "$ROLE"

# T3 — метрика arrived оторвана от goal_met.
mutate "$ROLE" 's = s.replace("\t\t\"arrived\": arrived,", "\t\t\"arrived\": not gone,", 1)'
run T3 "$ROLE"

# T4 — недостижимый маршрут молча жрёт ходы вместо поражения забега.
mutate "$ROLE" 's = s.replace("\t\t\tpilot._fail(\"traveler: нет проходимой цели\")\n", "", 1)'
run T4 "$ROLE"

# T5 — пустое кольцо не откатывается на дальнюю проходимую клетку.
mutate "$ROLE" 's = s.replace("\t\t\tif d > best_d:\n\t\t\t\tbest_d = d\n\t\t\t\tbest = c\n\t_target = best", "\t_target = best", 1)'
run T5 "$ROLE"

# T6 — отчёт потерял число биомов.
mutate "$ROLE" 's = s.replace("\t\t\"biomes\": int(_biomes.size()),", "\t\t\"biomes\": 0,", 1)'
run T6 "$ROLE"

# T7 — зуб пина: порог биомов встроен в цель. Если кейс
# test_goal_ignores_the_biome_threshold живой, он краснеет.
mutate "$ROLE" 's = s.replace("\treturn _target != Vector2i(-1, -1) and pilot._hero_cell() == _target", "\treturn _target != Vector2i(-1, -1) and pilot._hero_cell() == _target and _biomes.size() >= int(target.get(\"biome_goal\", 3))", 1)'
run T7 "$ROLE"

echo "ИТОГ: $([ "$FAILED" -eq 0 ] && echo "все мутанты красные (гейт держит)" || echo "ЕСТЬ ЗЕЛЁНЫЕ — гейт дырявый")"
git status --porcelain | grep -v "^??" || echo "дерево чистое"

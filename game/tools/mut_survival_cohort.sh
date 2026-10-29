#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без этого
# shim'а каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит»,
# ничего не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	# есть gtimeout — работаем им; нет — исполняем команду без ограничения времени
	# (сдвиг аргумента: $1 — длительность, а не команда).
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная батарея когорты выживания (задачи 7.1/7.3 цикла
# scenario-matrix-behavior-reliability). Каждый мутант обязан покраснить
# test_survival_cohort.gd или test_survival_counters.gd; зелёный мутант = дыра гейта.
#
# Слои меры: выживание читается из состояния игры (S1), восстановление — из роста HP,
# а не из «не упал» (S2), счётчик торговли не подменяется сбором (S3), цель когорты
# не сворачивает прогон раньше срока (S4), взаимодействие считаются только успешные
# действия (S5, S6), пороги когорты не превращаются в «ok» (S7) и не теряют требование
# взаимодействия (S8), причина гибели — первая, а не последняя (S9), набор seed
# остаётся множеством (S10), параллельный прогон того же процесса отвергается (S11),
# оверлей-маркер обязано снимать с root вместе с героем (S12, T-214).
#
# Запуск: bash game/tools/mut_survival_cohort.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TESTS=(-a res://tests/unit/probe/test_survival_cohort.gd -a res://tests/unit/probe/test_survival_counters.gd)
ROLE=game/scripts/probe/survival_role.gd
PROBE=game/scripts/probe/balance_probe.gd
PILOT=game/scripts/probe/scenario_pilot.gd
TARGETS=game/scripts/data/scenario_targets.gd
REPORT=game/tools/survival_report.gd
HEROVIS=game/scripts/entities/hero_visual_controller.gd
MARKER_TEST=res://tests/unit/entities/test_dest_marker_ownership.gd
FAILED=0

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

run() {
	local name="$1"
	local out
	# Третьим аргументом можно подменить тест: S12 проверяет не когорту, а владение
	# оверлеем (тест маркера), и краснеть должен именно он.
	local -a suite_list=("${TESTS[@]}")
	if [ -n "${3:-}" ]; then
		suite_list=(-a "$3")
	fi
	# Классификатор читает ВСЮ тройку «N test cases | E errors | F failures»: прогон, в
	# котором не нашлось ни одного теста (конфликт с чужим Godot-процессом на шаренной
	# машине), обязан считаться нечитаемым, а не зелёным.
	wait_for_godot
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c "${suite_list[@]}" 2>&1 | grep -oE "[0-9]+ test cases \| [0-9]+ errors \| [0-9]+ failures" | tail -1)
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

# S1 — «выжил» оторван от состояния игры.
mutate "$ROLE" 's = s.replace("\t\t\"survived\": survived(pilot),", "\t\t\"survived\": true,", 1)'
run S1 "$ROLE"

# S2 — восстановление считается по «не стало хуже», а не по фактическому росту HP.
mutate "$ROLE" 's = s.replace("if int(snaps[i].get(\"combat_hp\", 0)) > prev:", "if int(snaps[i].get(\"combat_hp\", 0)) >= prev:", 1)'
run S2 "$ROLE"

# S3 — счётчик торговли подменён сбором (спека требует завершённую торговлю).
mutate "$ROLE" 's = s.replace("\t\t\"trades\": 0,", "\t\t\"trades\": int(pilot.extracted_nodes),", 1)'
run S3 "$ROLE"

# S4 — цель когорты достигается мгновенно: прогон сворачивается на первом ходе.
mutate "$ROLE" 's = s.replace("return false\n", "return true\n", 1)'
run S4 "$ROLE"

# S5 — стройка засчитывается до проверки результата.
mutate "$PROBE" 's = s.replace("\t\tif check.ok:\n\t\t\tif first_building_turn < 0:", "\t\tif true:\n\t\t\tif first_building_turn < 0:", 1)'
run S5 "$PROBE"

# S6 — рекрутство засчитывается до проверки результата.
mutate "$PROBE" 's = s.replace("\tif check.ok:\n\t\tif first_recruit_turn < 0:", "\tif true:\n\t\tif first_recruit_turn < 0:", 1)'
run S6 "$PROBE"

# S7 — порог «выжить 8 из 10» выключен.
mutate "$REPORT" 's = s.replace("\t\tsurvived >= goal_survived\n", "\t\ttrue\n", 1)'
run S7 "$REPORT"

# S8 — требование «минимум одно взаимодействие в прогоне» потеряно.
mutate "$REPORT" 's = s.replace("\t\tand no_interaction_seeds.is_empty())", "\t\t)")'
run S8 "$REPORT"

# S9 — причина гибели перезаписывается следующей смертью.
mutate "$PILOT" 's = s.replace("\tif hero_death_turn < 0:", "\tif true:", 1)'
run S9 "$PILOT"

# S10 — набор seed перестал быть множеством (дубликат вместо второй карты).
mutate "$TARGETS" 's = s.replace("4211, 907,", "4211, 4211,", 1)'
run S10 "$TARGETS"

# S11 — инвариант «один мир за раз» выключен: параллельные прогоны снова молчат.
mutate "$REPORT" 's = s.replace("if _run_in_flight:", "if false:", 1)'
run S11 "$REPORT"

# S12 — владение оверлеем снято: герой умер, а его маркер цели остался висеть под root
# (T-214 — именно так когорта выживания каждый прогон отдавала осиротевший DestMarker).
mutate "$HEROVIS" 's = s.replace("\tteardown_path_visual()\n", "\tpass\n", 1)'
run S12 "$HEROVIS" "$MARKER_TEST"

echo "ИТОГ: $([ "$FAILED" -eq 0 ] && echo "все мутанты красные (гейт держит)" || echo "ЕСТЬ ЗЕЛЁНЫЕ — гейт дырявый")"
git status --porcelain | grep -v "^??" || echo "дерево чистое"

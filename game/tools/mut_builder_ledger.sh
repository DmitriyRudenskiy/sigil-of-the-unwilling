#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без этого
# shim'а каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит»,
# ничего не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	# есть gtimeout — работаем им; нет — исполняем команду без ограничения времени
	# (сдвиг аргумента: $1 — длительность, а не команда).
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная батарея гейта «фактические City/ledger исходы Городостроителя»
# (задача 6.3 цикла scenario-matrix-behavior-reliability). Каждый мутант обязан
# покраснить test_builder_city_ledger_outcomes.gd.
#
# Слои меры: цель читается из реестра (B1 — здания выкинуты из цели, B2 — население
# в него вписано, чего задача 6.3 у носителя не находит), тотальность при «города нет»
# (B3), отчёт расходится с реестром (B4 — здания печатаются уровнем, B5 — цель
# уровня хардкодом вместо эха конфига), пин хрупкости дефолтов (B6 — дефолт 30 «чинится» до 8 молча).
#
# Два правила самой батареи (урок 2026-10-26, когда она же и врала):
#   1. Паттерны мутаций не пишутся с backslash-эскейпами: аргумент передаётся bash'ом в
#      одинарных кавычках, `\\\\n` доходит до python как ДВА обратных слеша, строка не
#      находится, мутация не применяется — а батарея рапортует «зелёный мутант» на честном
#      исходнике. Перенос строки с продолжением собирается из chr().
#   2. Неприменившаяся мутация обрывает батарею, а не продолжается следующим прогоном.
#
# Запуск: bash game/tools/mut_builder_ledger.sh   (из корня репо)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/probe/test_builder_city_ledger_outcomes.gd
ROLE=game/scripts/probe/BuilderRole.gd
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
	# Классификатор читает ВСЮ тройку «N test cases | E errors | F failures»: прогон, в
	# котором не нашлось ни одного теста (конфликт с чужим Godot-процессом на шаренной
	# машине), обязан считаться нечитаемым, а не зелёным.
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

mutate_or_die() { # файл, python-выражение
	if ! mutate "$1" "$2"; then
		echo "  !! МУТАЦИЯ НЕ ПРИМЕНЕНА — батарея бессмысленна, прогон остановлен"
		git checkout -- "$1" 2>/dev/null
		exit 2
	fi
}

# B1 — здания исключены из цели: «город 2 уровня» = цель при нуле построек.
mutate_or_die "$ROLE" 'nl = chr(92) + chr(10) + chr(9) + chr(9)
s = s.replace("city_level_goal\", 2)) " + nl + "and int(city.buildings.size()) >= int(target.get(\"buildings_goal\", 4))", "city_level_goal\", 2))", 1)'
run B1 "$ROLE"

# B2 — население вписано в цель (задача 6.3 перечисляет его, носитель — нет; пин обязан
# покраснеть, если кто-то решит вопрос молча в одну из сторон).
mutate_or_die "$ROLE" 'nl = chr(92) + chr(10) + chr(9) + chr(9)
s = s.replace(">= int(target.get(\"buildings_goal\", 4))", ">= int(target.get(\"buildings_goal\", 4)) " + nl + "and city.pop_total() >= 8", 1)'
run B2 "$ROLE"

# B3 — «города нет» больше не тотальный случай: падение вместо false.
mutate_or_die "$ROLE" 's = s.replace("\tif city == null:\n\t\treturn false\n", "", 1)'
run B3 "$ROLE"

# B4 — отчёт печатает здания уровнем города.
mutate_or_die "$ROLE" 's = s.replace("\t\t\"buildings\": int(city.buildings.size()) if city != null else 0,", "\t\t\"buildings\": int(city.level) if city != null else 0,", 1)'
run B4 "$ROLE"

# B5 — цель уровня вместо эха конфига превращается в число внутри отчёта.
mutate_or_die "$ROLE" 's = s.replace("\t\t\"city_level_goal\": int(target.get(\"city_level_goal\", 2)),", "\t\t\"city_level_goal\": 5,", 1)'
run B5 "$ROLE"

# B6 — дефолт носителя «починен» молча: 30 → 8 в коде роли.
mutate_or_die "$ROLE" 's = s.replace("\t\t\"population_goal\": int(target.get(\"population_goal\", 30)),", "\t\t\"population_goal\": int(target.get(\"population_goal\", 8)),", 1)'
run B6 "$ROLE"

echo "ИТОГ: $([ "$FAILED" -eq 0 ] && echo "все мутанты красные (гейт держит)" || echo "ЕСТЬ ЗЕЛЁНЫЕ — гейт дырявый")"
# Дерево после батареи: проверяется ровно то, что батарея и трогала.
if git diff --quiet -- "$ROLE"; then
	echo "носитель восстановлен: $ROLE"
else
	echo "  !! $ROLE осталась изменённой — рабочее дерево грязное после батареи"
fi

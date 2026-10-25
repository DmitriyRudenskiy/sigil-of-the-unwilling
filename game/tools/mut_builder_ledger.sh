#!/usr/bin/env bash
# Мутационная батарея гейта «фактические City/ledger исходы Городостроителя»
# (задача 6.3 цикла scenario-matrix-behavior-reliability). Каждый мутант обязан
# покраснить test_builder_city_ledger_outcomes.gd.
#
# Слои меры: цель читается из реестра (B1 — здания выкинуты из цели, B2 — население
# в него вписано, чего задача 6.3 у носителя не находит), тотальность при «города нет»
# (B3), отчёт расходится с реестром (B4 — здания печатаются уровнем, B5 — цель
# уровня хардкодом вместо эха конфига), пин хрупкости дефолтов (B6 — дефолт 30 «чинится» до 8 молча).
#
# Запуск: bash game/tools/mut_builder_ledger.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/probe/test_builder_city_ledger_outcomes.gd
ROLE=game/scripts/probe/BuilderRole.gd
FAILED=0

run() {
	local name="$1"
	local out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "[0-9]+ errors \| [0-9]+ failures" | tail -1)
	echo "$name: $out"
	case "$out" in
	"" | *"0 errors | 0 failures"*)
		echo "  !! ЗЕЛЁНЫЙ (или нечитаемый) МУТАНТ — гейт не ловит"
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

# B1 — здания исключены из цели: «город 2 уровня» = цель при нуле построек.
mutate "$ROLE" 's = s.replace("return int(city.level) >= int(target.get(\"city_level_goal\", 2)) \\\\\n\t\tand int(city.buildings.size()) >= int(target.get(\"buildings_goal\", 4))", "return int(city.level) >= int(target.get(\"city_level_goal\", 2))", 1)'
run B1 "$ROLE"

# B2 — население вписано в цель (задача 6.3 перечисляет его, носитель — нет; пин обязан
# покраснеть, если кто-то решит вопрос молча в одну из сторон).
mutate "$ROLE" 's = s.replace("and int(city.buildings.size()) >= int(target.get(\"buildings_goal\", 4))", "and int(city.buildings.size()) >= int(target.get(\"buildings_goal\", 4)) \\\\\n\t\tand city.pop_total() >= 8", 1)'
run B2 "$ROLE"

# B3 — «города нет» больше не тотальный случай: падение вместо false.
mutate "$ROLE" 's = s.replace("\tif city == null:\n\t\treturn false\n", "", 1)'
run B3 "$ROLE"

# B4 — отчёт печатает здания уровнем города.
mutate "$ROLE" 's = s.replace("\t\t\"buildings\": int(city.buildings.size()) if city != null else 0,", "\t\t\"buildings\": int(city.level) if city != null else 0,", 1)'
run B4 "$ROLE"

# B5 — цель уровня вместо эха конфига превращается в число внутри отчёта.
mutate "$ROLE" 's = s.replace("\t\t\"city_level_goal\": int(target.get(\"city_level_goal\", 2)),", "\t\t\"city_level_goal\": 5,", 1)'
run B5 "$ROLE"

# B6 — дефолт носителя «починен» молча: 30 → 8 в коде роли.
mutate "$ROLE" 's = s.replace("\t\t\"population_goal\": int(target.get(\"population_goal\", 30)),", "\t\t\"population_goal\": int(target.get(\"population_goal\", 8)),", 1)'
run B6 "$ROLE"

echo "ИТОГ: $([ "$FAILED" -eq 0 ] && echo "все мутанты красные (гейт держит)" || echo "ЕСТЬ ЗЕЛЁНЫЕ — гейт дырявый")"
git status --porcelain | grep -v "^??" || echo "дерево чистое"

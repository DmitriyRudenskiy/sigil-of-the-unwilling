#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без этого
# shim'а каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит»,
# ничего не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	# есть gtimeout — работаем им; нет — исполняем команду без ограничения времени
	# (сдвиг аргумента: $1 — длительность, а не команда).
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная батарея к `tests/campaign/test_save_section_populated.gd` (T-301).
#
# Тест нужен потому, что whole-state байтовый контракт слеп к под-ключу, пустому
# с обеих сторон. Мутанты это и проверяют — каждый «теряет» под-ключ так, что
# обе стороны остаются согласованными и пустыми:
#   M1 — сборка не пишет `map.threats` (загрузка `from_dict({})` молча даёт пустые
#        угрозы, байтовый контракт зелёный: пустота == пустота);
#   M2 — сборка пишет пустой `city.sm` (то же для дефицитных состояний поселения);
#   M3 — `PopulationSystem.to_dict` обнуляет `birth_carry` (на K-канон-линии
#        перенос и так 0.0 — whole-state контракт потери не заметит).
#
#   M4 — сборка пишет пустой `resources` (тот же класс, что M2, но проверяет
#        цикл по трём ключам: ассерт без `.is_true()` здесь и проходил).
#
# Красными обязаны стать: M1, M2, M4 — кейс 1; M3 — кейс 2.
# Запуск: bash game/tools/mut_save_sections.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/campaign/test_mvp_save.gd
COMP=game/scripts/campaign/campaign_composition.gd
POP=game/scripts/campaign/population_system.gd
FAILED=0

run() {
	local name="$1"
	local out
	out=$(cd game && timeout 900 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: ${out:-<нет сводки: прогон упал до сводки — тоже красный>}"
	case "$out" in
	"0 errors | 0 failures")
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — тест не сторожит строку матрицы"
		FAILED=1
		;;
	esac
	git checkout -- "$COMP" "$POP"
}

mut() { # mut <файл> <было> <станет>
	python3 - "$@" <<'PY'
import pathlib, sys
path, old, new = sys.argv[1:4]
p = pathlib.Path(path)
s0 = p.read_text(encoding="utf-8")
assert s0.count(old) == 1, "якорь не уникален в %s: %r" % (path, old)
s = s0.replace(old, new)
assert s != s0
p.write_text(s, encoding="utf-8")
PY
}

git checkout -- "$COMP" "$POP"

echo "== M1: сборка не пишет map.threats"
mut "$COMP" '		"map": {"threats": threats.to_dict(), "region": region_map.to_dict()},' \
	'		"map": {"region": region_map.to_dict()},'
run M1

echo "== M2: сборка пишет пустой city.sm"
mut "$COMP" '			"sm": settlement.sm.duplicate(true),' '			"sm": {},'
run M2

echo "== M4: сборка пишет пустой resources"
mut "$COMP" '		"resources": settlement.stocks.duplicate(),' '		"resources": {},'
run M4

echo "== M3: to_dict обнуляет birth_carry"
mut "$POP" '		"birth_carry": _birth_carry,' '		"birth_carry": 0.0,'
run M3

[ "$FAILED" = 0 ] && echo "ИТОГ: все мутанты красные — столбец «покрыто» имеет зубы"
exit "$FAILED"

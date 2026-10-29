#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без этого
# shim'а каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит»,
# ничего не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	# есть gtimeout — работаем им; нет — исполняем команду без ограничения времени
	# (сдвиг аргумента: $1 — длительность, а не команда).
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная батарея шва двух регистров кампейн-запасов (T-309 / Q-M120).
#
# Каждый мутант — «половина моста», которую соблазнится сделать следующий агент,
# не сведя носители до конца:
#   M1 — реестр города стартует не значением вектора (своя стартовая раздача);
#   M2 — после тика продукции вектор перетирается реестром города (мост в одну
#        сторону: потребление и рейды исчезают из канонического вектора);
#   M3 — сейвовая секция `resources` пишется из реестра города (буквальный AC-2
#        T-309: секция перестаёт быть вектором поселения).
#
# Красными обязаны стать: M1 — кейс 1, M2 — кейс 2, M3 — кейсы 3 и 4.
# Запуск: bash game/tools/mut_stocks_registers.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/campaign/test_stocks_registers_seam.gd
CITY=game/scripts/campaign/campaign_city.gd
COMP=game/scripts/campaign/campaign_composition.gd
FAILED=0

run() {
	local name="$1"
	local out
	out=$(cd game && timeout 900 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: ${out:-<нет сводки: прогон упал до сводки — тоже красный>}"
	case "$out" in
	"0 errors | 0 failures")
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — шов не сторожит"
		FAILED=1
		;;
	esac
	git checkout -- "$CITY" "$COMP"
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

git checkout -- "$CITY" "$COMP"

echo "== M1: реестр города стартует не значением вектора поселения"
mut "$CITY" 'float(stocks[resource_id]))' 'float(stocks[resource_id]) + 100.0)'
run M1

echo "== M2: после тика продукции вектор перетирается реестром города"
mut "$COMP" '		var report: Dictionary = settlement.process_production(WorldSeasons.production_mult())' '		var report: Dictionary = settlement.process_production(WorldSeasons.production_mult())
		for _r in settlement.stocks.keys():
			settlement.stocks[_r] = city.resource_ctx.amount(StringName(_r))'
run M2

echo "== M3: секция resources пишется из реестра города"
mut "$COMP" '"resources": settlement.stocks.duplicate(),' '"resources": city.resource_ctx.serialize() if city != null else settlement.stocks.duplicate(),'
run M3

[ "$FAILED" = 0 ] && echo "ИТОГ: все мутанты красные — шов сторожит сведение носителей"
exit "$FAILED"

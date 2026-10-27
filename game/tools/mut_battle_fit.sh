#!/usr/bin/env bash
# Мутационная батарея гейта «поле боя при 720p — масштаб ×0.8» (mvp-ui-flow 4.1, C-10).
# Каждый мутант обязан покраснить tests/unit/systems/test_battle_field_fit_720p.gd;
# зелёный мутант = дыра гейта.
#
# M1 — множитель забыт (возврат 1.0): ровно тот дефект, из-за которого задача 4.1
#      оставалась открытой (плотная вписка на всех разрешениях).
# M2 — граница `<=` → `<`: спецификация говорит «at 720p», то есть пород включителен.
# M3 — пород 720 → 1080: множитель утекает на Full HD и молча сдвигает все прежние
#      кадры-доказательства боя.
# M4 — множитель берётся из layout-высоты вместо высоты окна. Это НЕ гипотетика:
#      первая реализация среза сделала именно так и прошла бы «на глаз», потому что
#      при stretch mode canvas_items `get_visible_rect()` остаётся 1920×1080 и на 720p.
#      Мутант ловится кейсом `test_camera_at_720p_is_scaled_fit`.
# M5 — число 0.8 → 0.9 (правильная идея, неверная константа).
# M6 — вызов множителя выброшен из формулы целиком (страховка от «функция есть,
#      но её никто не зовёт»).
#
# Запуск: bash game/tools/mut_battle_fit.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/systems/test_battle_field_fit_720p.gd
VIEW=game/scripts/systems/battle_view.gd
NUMBERS=game/scripts/constants/game_numbers_battle.gd
FAILED=0

run() {
	local name="$1"
	local out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: ${out:-<нет сводки: прогон упал до сводки — тоже красный>}"
	case "$out" in
	"0 errors | 0 failures")
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — гейт не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$VIEW" "$NUMBERS"
}

mut() { # mut <файл> <было> <станет>
	python3 - "$@" <<'PY'
import pathlib, sys
path, old, new = sys.argv[1:4]
p = pathlib.Path(path)
s = p.read_text(encoding="utf-8")
if old not in s:
	sys.exit("МУТАНТ НЕ ПРИМЕНЁН (строка не найдена): " + old[:60])
p.write_text(s.replace(old, new, 1), encoding="utf-8")
PY
}

CALL='* field_fit_scale(float(win_sz.y))'

mut "$VIEW" "		return GameNumbers.BATTLE_LOWRES_FIT_SCALE" "		return 1.0"
run M1

mut "$VIEW" "	if viewport_height <= GameNumbers.BATTLE_LOWRES_MAX_HEIGHT:" "	if viewport_height < GameNumbers.BATTLE_LOWRES_MAX_HEIGHT:"
run M2

mut "$VIEW" "	if viewport_height <= GameNumbers.BATTLE_LOWRES_MAX_HEIGHT:" "	if viewport_height <= 1080.0:"
run M3

mut "$VIEW" "$CALL" "	* field_fit_scale(vp_sz.y)"
run M4

mut "$NUMBERS" "const BATTLE_LOWRES_FIT_SCALE   := 0.8" "const BATTLE_LOWRES_FIT_SCALE   := 0.9"
run M5

mut "$VIEW" "		minf(vp_sz.x / field_sz.x, vp_sz.y / field_sz.y)
		* field_fit_scale(float(win_sz.y))" "		minf(vp_sz.x / field_sz.x, vp_sz.y / field_sz.y)"
run M6

echo "=== сводка: $([ "$FAILED" -eq 0 ] && echo 'все мутанты красные (гейт держит)' || echo 'ЕСТЬ ЗЕЛЁНЫЙ — дыра гейта')"
git status --porcelain -- "$VIEW" "$NUMBERS"
exit "$FAILED"

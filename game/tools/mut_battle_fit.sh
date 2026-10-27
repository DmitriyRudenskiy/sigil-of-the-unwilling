#!/usr/bin/env bash
# Мутационная батарея гейта «поле боя вписывается в полосу между бендами HUD» (T-220).
# Каждый мутант обязан покраснить tests/unit/systems/test_battle_field_fit.gd;
# зелёный мутант = дыра гейта.
#
# Прежняя батарея (M1…M6) стояла вокруг множителя ×0.8 по порогу разрешения — механизм
# снят D-279: порог не лечил Full HD (доля кадра 1.000, панель HUD поверх нижних рядов),
# а две независимые компрессии на 720p дали бы 0.57. Поэтому мутанты теперь про связку
# «панель → запас → формула», а не про константу.
#
# M1' — запас не применён (`avail_y = vp_sz.y`): ровно исходный дефект T-220.
# M2' — сеттер выбрасывает значение: хост внедряет запас, а камера живёт без него
#       («код есть, его никто не использует» — тот класс дефекта, что молчал в 4.1).
# M3' — сдвиг центра выброшен: поле вписывается в полосу, но остаётся отцентровано по
#       всему кадру и нижней половиной лежит на HUD.
# M4' — запас берётся из константы, а не из прямоугольника панели: правка панели в
#       сцене перестала бы править запас (кейс `test_reserve_follows_a_panel_edit`).
# M5' — запас применён по ширине вместо высоты: горизонтальное сжатие вместо вертикального.
# M6' — `top` и `bottom` перепутаны в сдвиге: поле уезжает вниз, прямо под панель.
#
# Запуск: bash game/tools/mut_battle_fit.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/systems/test_battle_field_fit.gd
VIEW=game/scripts/systems/battle_view.gd
UI=game/scripts/ui/battle_ui.gd
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
	git checkout -- "$VIEW" "$UI"
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

mut "$VIEW" "	var avail_y: float = vp_sz.y - _hud_reserve.x - _hud_reserve.y" "	var avail_y: float = vp_sz.y"
run "M1' (запас не применён)"

mut "$VIEW" "	_hud_reserve = Vector2(maxf(top, 0.0), maxf(bottom, 0.0))" "	_hud_reserve = Vector2.ZERO"
run "M2' (сеттер выбрасывает значение)"

mut "$VIEW" "	_camera.position = center - Vector2(0.0, (_hud_reserve.x - _hud_reserve.y) / (2.0 * z))" "	_camera.position = center"
run "M3' (сдвиг центра выброшен)"

mut "$UI" "	return Vector2(top, bottom)" "	return Vector2(155.0, 160.0)"
run "M4' (запас из константы, не из панели)"

mut "$VIEW" "	var z: float = minf(vp_sz.x / field_sz.x, avail_y / field_sz.y)" "	var z: float = minf((vp_sz.x - _hud_reserve.x - _hud_reserve.y) / field_sz.x, vp_sz.y / field_sz.y)"
run "M5' (запас по ширине вместо высоты)"

mut "$VIEW" "	_camera.position = center - Vector2(0.0, (_hud_reserve.x - _hud_reserve.y) / (2.0 * z))" "	_camera.position = center - Vector2(0.0, (_hud_reserve.y - _hud_reserve.x) / (2.0 * z))"
run "M6' (top и bottom перепутаны)"

echo "=== сводка: $([ "$FAILED" -eq 0 ] && echo 'все мутанты красные (гейт держит)' || echo 'ЕСТЬ ЗЕЛЁНЫЙ — дыра гейта')"
git status --porcelain -- "$VIEW" "$UI"
exit "$FAILED"

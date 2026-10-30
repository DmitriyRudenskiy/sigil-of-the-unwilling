#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без shim'а
# каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит», ничего
# не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная батарея T-315 (отключённый медальон командного ряда обязан быть
# ТЕМНЕЕ соседей, а не светлее их).
#
# Краснеет `test_battle_ui_hud_zones.gd > test_zone_d_disabled_medallion_paints_dim`:
# он выводит закраску пластины из её доступности на всех восьми медальонах и по всем
# публичным путям (`set_controls_enabled`, `set_attack_enabled`, `set_rescue_enabled`)
# плюс к начальному состоянию ряда.
#
# Почему гард поведенческий, а не статический скан `.disabled =`: в этом же файле есть
# легальные заглушения — кнопки диалога выхода (`_on_exit_dialog`, «Сдаться» до T-282),
# и скан красил бы их. Инвариант держит не синтаксис, а смысл: «заглушил медальон —
# перекрась ряд», и проверить это можно только вызовом публичного API.
#
# Мутанты:
#   M1 — `_set_medallion_enabled` пишет `disabled`, но не перекрашивает (ровно та
#        дыра, из-за которой «Отступить» на кадре была в 4.38 раза светлее ряда);
#   M2 — `set_rescue_enabled` возвращается к прямой записи `disabled` мимо точки;
#   M3 — то же для `set_attack_enabled`;
#   M4 — начальный запрет «Атаки» снят (проверка, что тест держит и первый кадр ряда,
#        а не только переходы);
#   M5 — гашение обесценено в самой `_medallion_state`: отключённая ветвь рисует белым
#        (мутация значения, а не вызова: «затемнение решили убрать» обязано краснить).
#
# Запуск: bash game/tools/mut_battle_medallion_dim.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TESTS=(-a res://tests/unit/ui/test_battle_ui_hud_zones.gd)
UI=game/scripts/ui/battle_ui.gd
FAILED=0

run() {
	local name="$1"
	local out
	out=$(cd game && timeout 900 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c "${TESTS[@]}" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: $out"
	case "$out" in
	"" | *"0 errors | 0 failures"*)
		echo "  !! ЗЕЛЁНЫЙ (или нечитаемый) МУТАНТ — гейт не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$UI"
}

mutate() { # файл, python-выражение; неприменившийся мутант — падение батареи
	python3 - "$1" "$2" <<'PY'
import sys, pathlib
path, body = sys.argv[1], sys.argv[2]
p = pathlib.Path(path); s0 = p.read_text(encoding="utf-8"); s = s0
exec(body)
assert s != s0, "МУТАНТ НЕ ПРИМЕНИЛСЯ: %s" % path
p.write_text(s, encoding="utf-8")
PY
}

# M1 — точка смены доступности теряет перекраску.
mutate "$UI" '
old = "\tbtn.disabled = not enabled\n\t_medallion_state(btn)"
assert s.count(old) == 1, "тело _set_medallion_enabled не найдено: %d" % s.count(old)
s = s.replace(old, "\tbtn.disabled = not enabled", 1)
'
run M1

# M2 — «нечего спасать» снова пишет `disabled` напрямую: исторический путь дефекта.
mutate "$UI" '
old = "func set_rescue_enabled(enabled: bool) -> void:\n\t_set_medallion_enabled(_retreat_btn, enabled)"
assert s.count(old) == 1, "set_rescue_enabled не найден: %d" % s.count(old)
s = s.replace(old, "func set_rescue_enabled(enabled: bool) -> void:\n\tif _retreat_btn != null:\n\t\t_retreat_btn.disabled = not enabled", 1)
'
run M2

# M3 — «Атака» возвращается к прямой записи.
mutate "$UI" '
old = "func set_attack_enabled(enabled: bool) -> void:\n\t_set_medallion_enabled(_attack_button, enabled)"
assert s.count(old) == 1, "set_attack_enabled не найден: %d" % s.count(old)
s = s.replace(old, "func set_attack_enabled(enabled: bool) -> void:\n\tif _attack_button != null:\n\t\t_attack_button.disabled = not enabled", 1)
'
run M3

# M4 — начальный запрет «Атаки» снят: первый кадр ряда тест обязан держать так же,
# как и переходы (иначе «собрали ряд светлым» проходит зелёным). Якорь — строка
# комментария над вызовом: такой же вызов есть и в `set_controls_enabled`.
mutate "$UI" '
old = "(T-315).\n\t_set_medallion_enabled(_attack_button, false)"
assert s.count(old) == 1, "начальный запрет атаки не найден уникально: %d" % s.count(old)
s = s.replace(old, "(T-315).\n\t# мутант: начальный запрет снят", 1)
'
run M4

# M5 — обесценено само гашение в `_medallion_state`.
mutate "$UI" '
old = "\tif btn.disabled:\n\t\tbtn.self_modulate = _MEDALLION_DIM"
assert s.count(old) == 1, "отключённая ветка _medallion_state не найдена: %d" % s.count(old)
s = s.replace(old, "\tif btn.disabled:\n\t\tbtn.self_modulate = Color(1, 1, 1, 1)", 1)
'
run M5

echo "ИТОГ: $([ "$FAILED" -eq 0 ] && echo "все мутанты красные (гейт держит)" || echo "ЕСТЬ ЗЕЛЁНЫЕ — гейт дырявый")"
git status --porcelain | grep -v "^??" || echo "дерево чистое"

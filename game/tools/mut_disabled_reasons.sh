#!/usr/bin/env bash
# Мутационная батарея гейта «выключенный контрол называет причину» (mvp-ui-flow 3.3,
# D-252). Каждый мутант обязан покраснить test_disabled_controls_explain.gd; зелёный
# мутант = дыра гейта. Мутации бьют по всем веткам проверки: причина исчезает (M1–M3),
# исчезает на пути перезаполнения (M4), исчезает в единой точке записи (M5), появляется
# молча выключенный контрол (M6 — проверка инвентаря), появляется подпись у доступного
# пункта (M7 — обратная сторона меры).
#
# Запуск: bash game/tools/mut_disabled_reasons.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/functional/ui/test_disabled_controls_explain.gd
MENU=game/scripts/ui/main_menu.gd
CREATION=game/scripts/ui/character_creation_ui.gd
SAVE=game/scripts/ui/save_load_screen.gd
FAILED=0

run() {
	local name="$1"
	local out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
	echo "$name: $out"
	case "$out" in
	"0 errors | 0 failures")
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

# Отступы: main_menu.gd и character_creation_ui.gd — 4 пробела, save_load_screen.gd —
# табы. Мутация, которая «не применилась», была бы ложным зелёным; mutate() это ловит.
# M1 — «Титры» выключены, причина снята.
mutate "$MENU" 's = s.replace("    _credits_btn.tooltip_text = GameText.menu_credits_unavailable()", "    # MUT", 1)'
run M1 "$MENU"

# M2 — «Продолжить» без сохранения остаётся без причины.
mutate "$MENU" 's = s.replace("    _continue_btn.tooltip_text = GameText.menu_continue_unavailable() if missing else \"\"", "    _continue_btn.tooltip_text = \"\"  # MUT", 1)'
run M2 "$MENU"

# M3 — «Выход» (инертен по AC6) снова молчит.
mutate "$MENU" 's = s.replace("    _exit_btn.tooltip_text = GameText.menu_exit_unavailable()", "    # MUT", 1)'
run M3 "$MENU"

# M4 — причина теряется на пути перезаполнения списка подрас.
mutate "$CREATION" 's = s.replace("        _subrace_option.tooltip_text = GameText.creation_subrace_unavailable()\n    else:", "    else:", 1)'
run M4 "$CREATION"

# M5 — единая точка записи выключает контрол, но не называет причину.
mutate "$SAVE" 's = s.replace("\tbutton.tooltip_text = reason", "\tbutton.tooltip_text = \"\"  # MUT", 1)'
run M5 "$SAVE"

# M6 — новый молча выключенный контрол (проверка инвентаря целиком).
mutate "$MENU" 's = s.replace("    _settings_btn.pressed.connect(_on_settings)", "    _settings_btn.disabled = true  # MUT\n    _settings_btn.pressed.connect(_on_settings)", 1)'
run M6 "$MENU"

# M7 — «причина» появилась у доступного пункта (подпись вместо признака).
mutate "$MENU" 's = s.replace("    _style_buttons()", "    _new_game_btn.tooltip_text = \"пояснение ни о чём\"  # MUT\n    _style_buttons()", 1)'
run M7 "$MENU"

echo "ИТОГ: $([ "$FAILED" -eq 0 ] && echo "все мутанты красные (гейт держит)" || echo "ЕСТЬ ЗЕЛЁНЫЕ — гейт дырявый")"
git status --porcelain | grep -v "^??" || echo "дерево чистое"

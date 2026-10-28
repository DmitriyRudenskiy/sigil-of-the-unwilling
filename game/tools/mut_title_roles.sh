#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без этого
# shim'а каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит»,
# ничего не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	# есть gtimeout — работаем им; нет — исполняем команду без ограничения времени
	# (сдвиг аргумента: $1 — длительность, а не команда).
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная батарея гейта «титул главного меню в носителе» (theme-type-hygiene 6.5, D-258).
# Каждый мутант обязан покраснить test_main_menu_title_roles.gd; зелёный мутант = дыра гейта.
# Слои меры: число роли (M1), роль снята с узла (M2), база роли (M3), сценевой оверрайд
# вернулся (M4), шрифт роли (M5), смещение тени (M6), цвет ушёл в носитель до ответа
# владельца по Q-M96 (M7), мутация самого гейта — отрицательный контроль (M8).
#
# Запуск: bash game/tools/mut_title_roles.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/ui/test_main_menu_title_roles.gd
THEME=game/assets/theme/game_theme.tres
SCENE=game/scenes/main_menu.tscn
GUARD=game/tests/unit/ui/test_main_menu_title_roles.gd
FAILED=0

run() {
	local name="$1"
	shift
	local out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "[0-9]+ errors \| [0-9]+ failures" | tail -1)
	echo "$name: $out"
	# Красным считается и падение с ошибкой (errors > 0): мутант, который рвёт прогон,
	# пойман так же, как мутант с фейлом.
	case "$out" in
	"" | *"0 errors | 0 failures"*)
		echo "  !! ЗЕЛЁНЫЙ (или нечитаемый) МУТАНТ — гейт не ловит"
		FAILED=1
		;;
	esac
	git checkout -- "$@"
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

# M1 — кегль роли вне измеренного (206 → 200): сверка объявления и живого резолва краснеет.
mutate "$THEME" 's = s.replace("TitleMain/font_sizes/font_size = 206", "TitleMain/font_sizes/font_size = 200", 1)'
run M1 "$THEME"

# M2 — роль снята с узла (TitleLine2): узел резолвит дефолт движка, а не объявление.
mutate "$SCENE" 's = s.replace("theme_type_variation = &\"TitleLink\"\n", "", 1)'
run M2 "$SCENE"

# M3 — база роли смотрит не в Label: движок вариацию не резолвит (прецедент CityPanel*).
mutate "$THEME" 's = s.replace("TitleWord/base_type = \"Label\"", "TitleWord/base_type = \"RichTextLabel\"", 1)'
run M3 "$THEME"

# M4 — сценевой оверрайд вернулся вместо роли: носитель перекрыт, счёт 6.5 не уменьшился.
mutate "$SCENE" 's = s.replace("theme_type_variation = &\"TitleWord\"\n", "theme_override_font_sizes/font_size = 123\n", 1)'
run M4 "$SCENE"

# M5 — у роли нет шрифта: письмо в никуда по группе fonts, узел получит шрифт по умолчанию.
mutate "$THEME" 's = s.replace("TitleLink/fonts/font = ExtResource(\"9_serif_bold\")\n", "", 1)'
run M5 "$THEME"

# M6 — смещение тени снято с роли (TitleMain): кадр титула меняется, объявления нет.
mutate "$THEME" 's = s.replace("TitleMain/constants/shadow_offset_x = 6\n", "", 1)'
run M6 "$THEME"

# M7 — «заодно перенесли» цвет в носитель до ответа владельца по Q-M96: гард обязан
# покраснеть, иначе срез молча принимает решение о палитре.
mutate "$THEME" 's = s.replace("TitleMain/constants/shadow_offset_y = 6", "TitleMain/constants/shadow_offset_y = 6\nTitleMain/colors/font_color = Color(0.902, 0.812, 0.604, 1)", 1)'
mutate "$SCENE" 's = s.replace("theme_type_variation = &\"TitleMain\"\ntheme_override_colors/font_color = Color(0.902, 0.812, 0.604, 1)\n", "theme_type_variation = &\"TitleMain\"\n", 1)'
run M7 "$THEME" "$SCENE"

# M8 — мутация самого гейта: ожидаемый дефолт движка поднят до кегля титула. Если
# отрицательный контроль (кейс 5) живой, он краснеет: без него «кегель 206» ничего не стоит.
mutate "$GUARD" 's = s.replace("const _ENGINE_FONT_SIZE := 16", "const _ENGINE_FONT_SIZE := 206", 1)'
run M8 "$GUARD"

echo "ИТОГ: $([ "$FAILED" -eq 0 ] && echo "все мутанты красные (гейт держит)" || echo "ЕСТЬ ЗЕЛЁНЫЕ — гейт дырявый")"
git status --porcelain | grep -v "^??" || echo "дерево чистое"

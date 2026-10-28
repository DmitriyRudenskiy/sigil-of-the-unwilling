#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без этого
# shim'а каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит»,
# ничего не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	# есть gtimeout — работаем им; нет — исполняем команду без ограничения времени
	# (сдвиг аргумента: $1 — длительность, а не команда).
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная батарея гейта «носитель зазора формы» (theme-type-hygiene 6.4, D-253).
# Каждый мутант обязан покраснить test_creation_form_row_role.gd; зелёный мутант = дыра
# гейта. Мутации бьют по всем слоям меры: число вне канона (M1, M5), роль снята с узла
# (M2), роль смотрит не в тот базовый тип (M3), сценевой оверрайд вернулся (M4),
# у отрицательного контроля отнят зуб (M6 — мутация самой константы теста).
#
# Запуск: bash game/tools/mut_form_row.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/ui/test_creation_form_row_role.gd
THEME=game/assets/theme/game_theme.tres
SCENE=game/scenes/ui/character_creation.tscn
GUARD=game/tests/unit/ui/test_creation_form_row_role.gd
FAILED=0

run() {
	local name="$1"
	local out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$TEST" 2>&1 | grep -oE "0 errors \| [0-9]+ failures" | tail -1)
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

# M1 — зазор строки вне канона (8 → 6): тест токенов обязан покраснеть.
mutate "$THEME" 's = s.replace("FormRow/constants/separation = 8", "FormRow/constants/separation = 6", 1)'
run M1 "$THEME"

# M2 — роль снята с одной строки формы (CultureRow): инвентарь и резолв краснеют.
mutate "$SCENE" '
head = "[node name=\"CultureRow\" type=\"HBoxContainer\" parent=\"Overlay/Scroll/Root\"]\n"
i = s.index(head); j = s.index("[node ", i + 1)
block = s[i:j].replace("theme_type_variation = &\"FormRow\"\n", "", 1)
assert block != s[i:j], "роли в CultureRow нет — мутация бессильна"
s = s[:i] + block + s[j:]
'
run M2 "$SCENE"

# M3 — база роли смотрит не в BoxContainer (Control вместо него).
mutate "$THEME" 's = s.replace("FormRow/base_type = \"BoxContainer\"", "FormRow/base_type = \"Control\"", 1)'
run M3 "$THEME"

# M4 — сценевой оверрайд вернулся на Root вместо роли FormStack.
mutate "$SCENE" 's = s.replace("theme_type_variation = &\"FormStack\"", "theme_override_constants/separation = 12", 1)'
run M4 "$SCENE"

# M5 — вертикальный ритм формы вне сетки 8 px (16 → 12, ровно как было до среза).
mutate "$THEME" 's = s.replace("FormStack/constants/separation = 16", "FormStack/constants/separation = 12", 1)'
run M5 "$THEME"

# M6 — мутация самого гейта: ожидаемый дефолт движка поднят до 8. Если отрицательный
# контроль (кейс 7) живой, он краснеет: без него «резолв = 8» ничего не стоит.
mutate "$GUARD" 's = s.replace("const _ENGINE_DEFAULT_GAP := 4", "const _ENGINE_DEFAULT_GAP := 8", 1)'
run M6 "$GUARD"

echo "ИТОГ: $([ "$FAILED" -eq 0 ] && echo "все мутанты красные (гейт держит)" || echo "ЕСТЬ ЗЕЛЁНЫЕ — гейт дырявый")"
git status --porcelain | grep -v "^??" || echo "дерево чистое"

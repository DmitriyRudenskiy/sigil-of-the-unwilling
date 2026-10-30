#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без shim'а
# каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит», ничего
# не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная батарея T-300 (рантаймная закраска цвета вне модуля стиля).
#
# Краснеет `test_theme_source_scan.gd` — третий гард файла («цвет состояния, закрашенный
# в узел, обязан браться из ThemeConfig»). Краснеть должен и тест сетки инвентаря: он
# сверяет `modulate` клетки с константой экрана, и если константа снова уедет в литерал,
# тест обязан это заметить, а не молча сравнить литерал с самим собой.
#
# Мутанты:
#   M1 — возврат миграции: тон клетки снова локальная литеральная константа экрана;
#   M2 — новый нарушитель в файле вне допуска (литерал в `add_theme_color_override`);
#   M3 — добавленный нарушитель в файле, который В допуске (проверка, что допуск —
#        число, а не разрешение «красить сколько угодно»);
#   M4 — протухший допуск: нарушитель починили, строка в допуске осталась;
#   M5 — снята калибровка идентичных тонов (`Color(1, 1, 1, 1)` снова считается
#        состоянием) — гард обязан покраснить и это, иначе «допуск» — резинка;
#   M6 — ослеплённый сам гард: классификатор всегда «чисто» (мутация проверки,
#        прецедент M8 в mut_theme_variations.sh).
#
# Запуск: bash game/tools/mut_runtime_color_guard.sh   (из корня репо, дерево чистое)
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TESTS=(-a res://tests/unit/ui/test_theme_source_scan.gd
	-a res://tests/unit/ui/test_inventory_grid.gd)
GRID=game/tests/unit/ui/test_theme_source_scan.gd
INV=game/scripts/ui/artifact_inventory_screen.gd
ARMY=game/scripts/ui/army_panel.gd
# Мишень «файла в допуске» — панель решения: после подсреза 2 (2026-10-30) в допуске
# остались город и она, а город — следующая мишень сведения, поэтому якорь ставится на
# файл, который не поедет от следующего шага тикета.
DP=game/scripts/ui/decision_panel.gd
FAILED=0

run() { # имя, файл-мишень (его и возвращаем)
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
	git checkout -- "$2"
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

# M1 — возврат миграции: тон клетки снова литерал экрана. Гард обязан покраснить файл,
# которого в допуске нет (после T-300 их ноль), иначе весь смысл переноса теряется.
mutate "$INV" '
old = "const CELL_FILLED := ThemeConfig.C_CELL_FILLED"
assert s.count(old) == 1, "константа состояния не найдена: %d" % s.count(old)
s = s.replace(old, "const CELL_FILLED := Color(0.62, 0.55, 0.45, 1.0)", 1)
'
run M1 "$INV"

# M2 — новый нарушитель в файле вне допуска.
mutate "$ARMY" '
old = "\t\tct.add_theme_color_override(\"font_color\", C_TEXT)"
assert s.count(old) == 1, "строка армии не найдена: %d" % s.count(old)
s = s.replace(old, old + "\n\t\tct.add_theme_color_override(\"font_hover_color\", Color(\"#123456\"))", 1)
'
run M2 "$ARMY"

# M3 — тот же литерал в файле, который уже в допуске: допуск — это ЧИСЛО мест, а не
# разрешение. Без этой проверки «файл в списке» превращается в лицензию красить сколько
# угодно, и гард перестаёт ловить именно то, ради чего писался.
mutate "$DP" '
old = "\t\t\t\tcolor_rect.color = Color.GREEN"
assert s.count(old) == 1, "плашка серьёзности не найдена: %d" % s.count(old)
s = s.replace(old, old + "\n\t\t\t\tcolor_rect.color = Color(\"#123456\")", 1)
'
run M3 "$DP"

# M4 — протухший допуск: нарушитель починили (тон поехал в модуль стиля), а строку в
# допуске не убрали. Гард обязан краснить и это — иначе допуск живёт дольше дыры.
mutate "$DP" '
old = "\t\t\t\tcolor_rect.color = Color.GREEN"
assert s.count(old) == 1, "плашка серьёзности не найдена: %d" % s.count(old)
s = s.replace(old, "\t\t\t\tcolor_rect.color = ThemeConfig.C_TEXT_SUCCESS", 1)
'
run M4 "$DP"

# M5 — снята калибровка идентичных тонов. `Color(1, 1, 1, 1)` — «вернуть как есть», не
# состояние; если регулярка снимается, верный код обязан покраснить (иначе допуск —
# резинка и в обратную сторону).
mutate "$GRID" '
old = "const _COLOR_IDENTITY_RE := \"Color"
assert s.count(old) == 1, "регулярка идентичных тонов не найдена: %d" % s.count(old)
i = s.index(old)
j = s.index("\n", i)
s = s[:i] + "const _COLOR_IDENTITY_RE := \"ColorZZZ\"" + s[j:]
'
run M5 "$GRID"

# M6 — ослеплённый гард: классификатор всегда «чисто». Мутация самой проверки; без неё
# «исправили критерий» ничего не стоит.
mutate "$GRID" '
old = "\tvar expr := _strip_identity_colors(rhs)"
assert s.count(old) == 1, "тело классификатора не найдено: %d" % s.count(old)
s = s.replace(old, "\treturn false\n\tvar expr := _strip_identity_colors(rhs)", 1)
'
run M6 "$GRID"

echo "ИТОГ: $([ "$FAILED" -eq 0 ] && echo "все мутанты красные (гейт держит)" || echo "ЕСТЬ ЗЕЛЁНЫЕ — гейт дырявый")"
git status --porcelain | grep -v "^??" || echo "дерево чистое"

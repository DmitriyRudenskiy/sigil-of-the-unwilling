#!/usr/bin/env bash
# Мутационная батарея инварианта мёртвого фасада (T-283).
# Каждый мутант обязан покраснить свой тест; зелёный мутант = дыра гейта.
#
# Что под защитой. `tests/unit/data/test_spell_resolver_deadness.gd` держит две
# правды об одном и том же классе: production-вызова нет (M1 обязан покраснить),
# и сам файл на месте (M2 обязан покраснить). До батареи проверка была
# односторонней: восемь тестов фасада зеленели, и «тесты заклинаний зелёные»
# читалось как «боевая магия работает», хотя бой колдует через `SpellCaster`.
#
# Честная лакуна: M2 удаляет файл из рабочего дерева (единственный способ
# измерить «класса больше нет»). Перед удалением батарея требует чистого дерева
# и отслеживаемости файла, после — восстанавливает его через `git checkout`,
# сверяя байты с бэкапом. Вне чистого дерева батарею не запускать.
#
# Вторую лакуна назовём прямо: вызов из `.tscn` мутантом не проверяется —
# статический вызов из файла сцены не пишется, а `ext_resource`-ссылка на скрипт
# не является вызовом `resolve`. Область скана (`scripts/` + `scenes/`) при этом
# заведена: она нужна для скриптов, которые появятся вместе с вариантом (а) T-267.
#
# Запуск: bash game/tools/mut_spell_deadness.sh   (из корня репо, дерево чистое)
# Классификатор читает строку Statistics целиком: мутант вправе уронить прогон до
# сводки (ошибка компиляции — ожидаемое следствие M1), это тоже красный, но
# подписан он иначе, чем «тест поймал дефект».
set -u
G=${GODOT_BIN:-/home/user/.local/bin/godot}
TEST=res://tests/unit/data/test_spell_resolver_deadness.gd
SRC=game/scripts/data/spell_resolver.gd
HOST=game/scripts/systems/battle_action_resolver.gd
FAILED=0

# Батарея разрушает рабочее дерево только для того, чтобы измерить «файла нет».
git diff --quiet -- "$SRC" "$HOST" || { echo "дерево по $SRC/$HOST грязное — батарея не запускается"; exit 2; }
git ls-files --error-unmatch "$SRC" >/dev/null || { echo "$SRC не отслеживается git — восстанавливать будет нечем"; exit 2; }
cp "$SRC" /tmp/mut_spell_deadness_backup.gd

restore() {
	git checkout -- "$HOST" "$SRC"
	if [ -f /tmp/mut_spell_deadness_backup.gd ]; then
		cmp -s "$SRC" /tmp/mut_spell_deadness_backup.gd \
			|| { echo "  !! восстановление разошлось с бэкапом: $SRC"; exit 3; }
	fi
}

run() { # имя, тест
	local name="$1" test="$2" out
	out=$(cd game && timeout 600 "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
		--ignoreHeadlessMode -c -a "$test" 2>&1 \
		| sed 's/\x1b\[[0-9;]*m//g' | grep -E "^Statistics:" | tail -1 \
		| sed -E 's/(.*orphans \|).*/\1/')
	echo "$name: ${out:-<нет сводки: прогон упал до сводки — тоже красный>}"
	case "$out" in
	*"0 errors | 0 failures"*)
		echo "  !! ЗЕЛЁНЫЙ МУТАНТ — гейт не ловит"
		FAILED=1
		;;
	esac
	restore
}

# M1 — у фасада появился production-вызов: тест обязан покраснеть, потому что
# монтаж резолвера это решение владельца (T-267), а не побочный эффект правки.
python3 - "$HOST" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s0 = p.read_text(encoding="utf-8"); s = s0
s += "\n\nstatic func _mutant_t283(spell: Variant, state: Variant) -> Dictionary:\n\treturn SpellResolver.resolve(spell, state, null)\n"
assert s != s0, "МУТАЦИЯ M1 НЕ ПРИМЕНИЛАСЬ"
p.write_text(s, encoding="utf-8")
PY
run M1 "$TEST"

# M2 — класс удалён молча: восемь тестов фасада при этом просто исчезают из
# прогона, и ни один другой тест об этом не сообщит.
python3 - "$SRC" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
assert p.is_file(), "M2: файл уже отсутствует"
p.unlink()
PY
run M2 "$TEST"

rm -f /tmp/mut_spell_deadness_backup.gd
echo "ИТОГ: $([ $FAILED -eq 0 ] && echo 'все мутанты красные' || echo 'ЕСТЬ ЗЕЛЁНЫЕ МУТАНТЫ')"
exit $FAILED

#!/usr/bin/env bash
# Батарея мутантов значенческого контракта GameNumbersCity (T-227 · С-4).
# Каждый мутант обязан покраснить test_game_numbers_city.gd: зелёный мутант =
# проверка ничего не стоит. Мутанты идут по трём осям теста: расхождение с
# фасадом (M1), немые константы (M2), пары и порядка (M3…M15).
set -u
cd "$(dirname "$0")/.."
CONST=scripts/constants/game_numbers_city.gd
SHIM=scripts/constants/game_numbers.gd
REP=scripts/city/reputation_system.gd
TEST=res://tests/unit/city/test_game_numbers_city.gd
BK=$(mktemp -d)
cp "$CONST" "$BK/game_numbers_city.gd"
cp "$SHIM" "$BK/game_numbers.gd"
cp "$REP" "$BK/reputation_system.gd"
restore() {
  cp "$BK/game_numbers_city.gd" "$CONST"
  cp "$BK/game_numbers.gd" "$SHIM"
  cp "$BK/reputation_system.gd" "$REP"
}
trap restore EXIT

run_red() {
  local name="$1"
  local tag="${name%% *}"
  if [ -n "${ONLY:-}" ] && ! echo " $ONLY " | grep -q " $tag "; then
    restore
    return
  fi
  if cmp -s "$CONST" "$BK/game_numbers_city.gd" && cmp -s "$SHIM" "$BK/game_numbers.gd" \
    && cmp -s "$REP" "$BK/reputation_system.gd"; then
    echo "$name: *** МУТАНТ НЕ ПРИМЕНИЛСЯ — правка не нашла исходник ***"
    return
  fi
  local out
  out=$(timeout 900 godot --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -a "$TEST" 2>&1)
  if echo "$out" | grep -q "FAILED"; then
    echo "$name: RED $(echo "$out" | grep -oE '[0-9]+ failures' | head -1)"
  elif echo "$out" | grep -q "Could not resolve script\|Parse Error"; then
    echo "$name: RED (parse)"
  else
    echo "$name: *** GREEN — тест ничего не проверяет ***"
  fi
  restore
}

# setnum <файл> <имя константы> <новое значение> — правит только числовую часть
# строки const, не зависит от количества пробелов в исходнике.
setnum() {
  python3 - "$1" "$2" "$3" <<'PY'
import re, sys
path, name, value = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path, encoding="utf-8").read()
new, n = re.subn(
    r"(?m)^(const %s\s*:=\s*)[^#\n]+" % re.escape(name),
    lambda m: m.group(1) + value,
    src, count=1)
assert n == 1, "константа %s не найдена" % name
open(path, "w", encoding="utf-8").write(new)
PY
}

# sub <файл> <подстрока> <замена> — одна замена точного куска.
sub() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(path, encoding="utf-8").read()
assert src.count(old) >= 1, "куска нет в исходнике: %s" % old[:60]
open(path, "w", encoding="utf-8").write(src.replace(old, new, 1))
PY
}

# M1: константа домена перестала протекать через фасад (шим её не выписывает).
# Красным здесь становится компиляция теста (он читает REP_DISASTER именем), но
# осевая проверка — скан: он ловит новый случай «константа добавлена, потребителя
# ещё нет», где компилятор молчит, а фасад уже врёт.
sub "$SHIM" "const REP_DISASTER := GameNumbersCity.REP_DISASTER" "# removed by mutant"
run_red "M1 фасад не выписывает константу домена"

# M2: «немому» немцу починили читателя, а строку в замкнутом списке оставили
# (рэтчет обязан гнить в обе стороны).
sub "$REP" "if cha >= 0 and cha <= GameNumbers.SOCIAL_ATTRITION_CHA:" \
  "if cha >= GameNumbers.REP_DISASTER and cha <= GameNumbers.SOCIAL_ATTRITION_CHA:"
run_red "M2 список немых пережил починку константы"

# M3: полоса «золотого века» ниже полосы процветания — порядок полос сломан.
setnum "$CONST" REP_BAND_GOLDEN_AGE 25
run_red "M3 полоса золотого века ниже процветания"

# M4: порог оттока разошёлся с полосой недовольства.
setnum "$CONST" MIGRATE_OUT_AT -20
run_red "M4 порог оттока вне полосы недовольства"

# M5: кривая процветания не монотонна (уровень 3 требует меньше уровня 2).
sub "$CONST" "[55.0, 58.0, 62.0," "[55.0, 51.0, 62.0,"
run_red "M5 кривая уровней не монотонна"

# M6: «кольца 1–3» названы тремя разными числами (CITY_RING_MAX уехал).
setnum "$CONST" CITY_RING_MAX 4
run_red "M6 радиус застройки разошёлся с ареной"

# M7: SCALE_TIERS получил четвёртый порог, а массивы множителей — нет.
setnum "$CONST" SCALE_TIERS "[4, 14, 29, 44]"
run_red "M7 тир порога без пары множителей"

# M8: крупное поселение обслуживает себя дороже мелкого.
setnum "$CONST" SCALE_UPKEEP_MULT "[1.0, 1.05, 0.9, 0.85]"
run_red "M8 upkeep растёт с размером"

# M9: строка таблицы дохода кольца потеряла колонку.
sub "$CONST" "[3.00, 6.00, 0.00, 0.00, 0.00]," "[3.00, 6.00, 0.00, 0.00],"
run_red "M9 строка RING_YIELD уже пяти колонок"

# M10: у надбавки нет значения для третьего кольца (дыра читается как 0 молча).
sub "$CONST" '&"mine": { 1: 0.00, 2: 0.15, 3: 0.20 }' '&"mine": { 1: 0.00, 2: 0.15 }'
run_red "M10 RING_BONUS без кольца 3"

# M11: надбавка называет строительство, которого нет в каталоге.
sub "$CONST" '&"bakery": {' '&"bakeery": {'
run_red "M11 RING_BONUS вне buildings.json"

# M12: шанс рейда вышел за единицу.
setnum "$CONST" RAID_CHANCE_MAX 1.30
run_red "M12 шанс рейда > 1"

# M13: таблица харизмы стала короче диапазона cha (индекс cha-1 уходит за край).
sub "$CONST" "6, 6, 7, 7]" "6, 6, 7]"
run_red "M13 таблица харизмы короче 20"

# M14: степени последствий перестали нарастать.
sub "$CONST" '"id": "severe", "surcharge": 0.50' '"id": "severe", "surcharge": 0.05'
run_red "M14 степени последствий не растут"

# M15: смягчение шторма сильнее самого шторма (штраф больше, чем без смягчения).
setnum "$CONST" ARENA_STORM_MITIG_MULT 0.6
run_red "M15 смягчение шторма сильнее штрафа"

# M16: ядро (кольцо 0) начало приносить доход.
sub "$CONST" "[0.00, 0.00, 0.00, 0.00, 0.00]," "[1.00, 0.00, 0.00, 0.00, 0.00],"
run_red "M16 ядро платит доход"

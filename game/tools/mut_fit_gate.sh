#!/usr/bin/env bash
# Батарея мутантов T-248 (гейт «экран целиком, без прокрутки»).
#
#   M1  минимальный размер убран из замеряемых → «обещанное никто не мерит»
#   M2  объявленный минимум завышен до 1280×720 → проверка «не завышать»
#   M3  базовый канв проекта убран из замеряемых → вписанность в канв не мерится
#   M4  объявленный минимум обнулён → контракт превращается в «любой размер»
#   M5  в allowlist вернули протухшую запись → устаревшая запись должна краснеть,
#       а не печататься предупреждением (иначе список растёт «на всякий случай»)
#
# Каждый мутант обязан покрасить GdUnit-файл. Пустой прогон — дыра в гейте.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT_BIN:-$HOME/.local/bin/godot}"
TESTS=(res://tests/functional/ui/test_ui_responsive.gd)
F=tests/functional/ui/test_ui_responsive.gd
rc=0

run() {
  local name="$1"
  timeout 1800 "$GODOT" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -c -a "${TESTS[@]}" > /tmp/mut_fit.log 2>&1
  local code=$?
  local line
  line=$(grep -E "Overall Summary|Statistics:" /tmp/mut_fit.log | tail -1 | sed 's/\x1b\[[0-9;]*m//g')
  echo "$name: rc=$code | $line"
  if [ "$code" -eq 0 ]; then
    echo "  !! мутант ВЫЖИЛ — гейт дыряв"
    rc=1
  fi
  git checkout -- "$F"
}

# M1 — минимальный размер исчез из набора (проверяется только «красивое» 16:9).
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "\tVector2i(1024, 768),   # 4:3 — объявленный минимум (_MIN_SUPPORTED)\n"
assert s.count(old) == 1, "M1: не найден минимальный размер в _RESOLUTIONS"
open(p, "w", encoding="utf-8").write(s.replace(old, "", 1))
PY
run M1

# M2 — объявленный минимум завышен (он есть в наборе, но не является наименьшим).
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "const _MIN_SUPPORTED := Vector2i(1024, 768)"
assert s.count(old) == 1, "M2: не найден _MIN_SUPPORTED"
open(p, "w", encoding="utf-8").write(s.replace(old, "const _MIN_SUPPORTED := Vector2i(1280, 720)", 1))
PY
run M2

# M3 — базовый канв проекта убран из замеряемых.
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "\tVector2i(1920, 1080),  # базовый канв проекта (project.godot)\n"
assert s.count(old) == 1, "M3: не найден базовый размер в _RESOLUTIONS"
open(p, "w", encoding="utf-8").write(s.replace(old, "", 1))
PY
run M3

# M4 — объявленный минимум обнулён.
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "const _MIN_SUPPORTED := Vector2i(1024, 768)"
assert s.count(old) == 1, "M4: не найден _MIN_SUPPORTED"
open(p, "w", encoding="utf-8").write(s.replace(old, "const _MIN_SUPPORTED := Vector2i.ZERO", 1))
PY
run M4

# M5 — в allowlist вернули запись, которая не воспроизводится.
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "const _KNOWN_VIOLATIONS := {\n}"
assert s.count(old) == 1, "M5: не найден пустой _KNOWN_VIOLATIONS"
open(p, "w", encoding="utf-8").write(
    s.replace(old, 'const _KNOWN_VIOLATIONS := {\n\t"artifact_inventory_screen": ["Center/Window/Bottom/Formations"],\n}', 1))
PY
run M5

echo "battery rc=$rc"
exit $rc

#!/usr/bin/env bash
# `timeout` не из POSIX и на macOS живёт как `gtimeout` (из coreutils). Без этого
# shim'а каждый мутант «падал» до запуска Godot, а батарея печатала «гейт держит»,
# ничего не прогнав: отсутствующая команда = «тоже красный».
timeout() {
	# есть gtimeout — работаем им; нет — исполняем команду без ограничения времени
	# (сдвиг аргумента: $1 — длительность, а не команда).
	if command -v gtimeout >/dev/null; then gtimeout "$@"; else shift; "$@"; fi
}
# Мутационная проверка гарда «строка угрозы доходит до отрендеренной ленты»
# (vertical-slice 2.1, D-249). Правила: рабочее дерево обязано быть чистым
# (восстановление — `git checkout --`), каждая мутация проверяется на применимость,
# восстановление — сразу после прогона.
set -u
cd /home/user/sigil-of-the-unwilling/game || exit 2
git -C /home/user/sigil-of-the-unwilling diff --quiet || { echo "РАБОЧЕЕ ДЕРЕВО ГРЯЗНОЕ — выходим"; exit 2; }
GODOT=/home/user/.local/bin/godot
SUITE=res://tests/functional/ui/test_campaign_chronicle_carrier.gd
PY=/home/user/.venv/map-art/bin/python

run_suite() {
  local out rc
  out=$(timeout 600 "$GODOT" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -c -a "$SUITE" 2>&1)
  rc=$?
  echo "  rc=$rc $(printf '%s' "$out" | grep -oE 'Overall Summary: [0-9]+ test cases \| [0-9]+ errors \| [0-9]+ failures' | tail -1)"
  return $rc
}

check_and_run() { # имя файла старое новое
  local name="$1" f="$2" old="$3" new="$4"
  FILE="$f" OLD="$old" NEW="$new" "$PY" - <<'PY' || exit 4
import os, pathlib
p = pathlib.Path(os.environ["FILE"])
s = p.read_text(encoding="utf-8")
old, new = os.environ["OLD"], os.environ["NEW"]
if s.count(old) != 1:
    raise SystemExit(f"МУТАЦИЯ НЕ ОДНОЗНАЧНА: count={s.count(old)}")
p.write_text(s.replace(old, new, 1), encoding="utf-8")
PY
  if git -C /home/user/sigil-of-the-unwilling diff --quiet; then
    echo "$1: МУТАЦИЯ НЕ ПРИМЕНИЛАСЬ — красный не засчитывается"
    return 3
  fi
  if run_suite; then
    echo "$1: ЗЕЛЁНЫЙ ПОСЛЕ МУТАЦИИ — гард слепой"
  else
    echo "$1: красным подтверждён"
  fi
  git -C /home/user/sigil-of-the-unwilling checkout -- .
}

echo "M1 — бит первого рейда не пишется вовсе"
check_and_run M1 scripts/campaign/campaign_composition.gd \
  'if not chronicle.has_bit("bit_first_raid"):' \
  'if false and not chronicle.has_bit("bit_first_raid"):'

echo "M2 — экран хроники печатает заголовки ходов, но не строки записей"
check_and_run M2 scripts/ui/chronicle_screen.gd \
  'for line in (rec as Dictionary).get("lines", []):' \
  'for line in []:'

echo "M3 — экран хроники открывается, но ленту не перечитывает (пустая лента)"
check_and_run M3 scripts/ui/campaign_hud.gd \
  'chronicle_screen.show_records(_chronicle.records())' \
  'chronicle_screen.show_records([] as Array)'

echo "M4 — бит рейда пишется на старте кампании (гард «до рейда» обязан покраснеть)"
check_and_run M4 scripts/campaign/campaign_composition.gd \
  'chronicle.record_bit(1, "bit_sign", "chronicle.bit_sign")' \
  'chronicle.record_bit(1, "bit_sign", "chronicle.bit_sign")
	chronicle.record_bit(1, "bit_first_raid", "chronicle.bit_first_raid")'

echo "БАЗА (все мутации сняты):"
run_suite
git -C /home/user/sigil-of-the-unwilling diff --quiet && echo "дерево чистое" || echo "ДЕРЕВО ГРЯЗНОЕ"

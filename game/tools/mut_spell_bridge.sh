#!/usr/bin/env bash
# Батарея мутантов контракта моста реестра → книжный формат (T-227 С-4).
# Каждый мутант обязан покраснить test_battle_spell_bridge.gd; зелёный мутант =
# тест ничего не проверяет. Мутант M10 — проверка самого стража: эффект, которого
# нет в словаре keyword, обязан быть пойман, иначе заклинание-пустышка пройдёт
# успешным.
set -u
cd "$(dirname "$0")/.."
SRC=scripts/data/battle_spell_bridge.gd
TEST=res://tests/unit/data/test_battle_spell_bridge.gd
BK=$(mktemp)
cp "$SRC" "$BK"
restore() { cp "$BK" "$SRC"; }
trap restore EXIT

run_red() {
  local name="$1"
  local out
  out=$(timeout 900 godot --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -a "$TEST" 2>&1)
  if echo "$out" | grep -q "FAILED"; then
    echo "$name: RED $(echo "$out" | grep -oE '[0-9]+ failed' | head -1)"
  elif echo "$out" | grep -q "Could not resolve script\|Parse Error"; then
    echo "$name: RED (parse)"
  else
    echo "$name: *** GREEN — тест ничего не проверяет ***"
  fi
  restore
}

# M1: cure теряет собственное исключение и уезжает в бафф по buff_effect.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('''	if s.id == &"cure":
		return T_HEAL_CLEAR''', "")
open(p, "w").write(s)
PY
run_red "M1 cure без исключения HEAL_CLEAR"

# M2: таблица цвета путает Water.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('"Water": "primal",', '"Water": "shadow",')
open(p, "w").write(s)
PY
run_red "M2 таблица школа → цвет испорчена"

# M3: групповой урон теряет групповую цель.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('''		&"fireball", &"armageddon", &"meteor_shower":
			return "ALL_ENEMY_UNITS"''', "")
open(p, "w").write(s)
PY
run_red "M3 таблица целей урона"

# M4: массовость выводится из «это дебафф», а не из id строки.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('p["mass"] = (s.id == &"slow_mass")', 'p["mass"] = true')
open(p, "w").write(s)
PY
run_red "M4 mass = любой дебафф"

# M5: уровень не доезжает до параметров.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('var p: Dictionary = {"level": s.level}', "var p: Dictionary = {}")
open(p, "w").write(s)
PY
run_red "M5 уровень потерян в параметрах"

# M6: чужой объект превращается в заклинание.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('''	var s := def as SpellRegistry.SpellDef
	if s == null:
		return null''', '''	var s := def as SpellRegistry.SpellDef
	if s == null:
		s = SpellRegistry.SpellDef.new()''')
open(p, "w").write(s)
PY
run_red "M6 to_spell не отказывает чужому объекту"

# M7: иммунитет нежити выключен.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace(
    'const UNDEAD_IMMUNE_SPELLS: Array[StringName] = [&"bless", &"cure", &"curse", &"weakness", &"slow"]',
    'const UNDEAD_IMMUNE_SPELLS: Array[StringName] = []')
open(p, "w").write(s)
PY
run_red "M7 иммунитет нежити пуст"

# M8: драконьё правило «ниже четвёртого уровня» снято.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('	if unit.has_tag("dragon") and spell_level < 4:', '	if false:')
open(p, "w").write(s)
PY
run_red "M8 драконьий порог уровня"

# M9: список ментального иммунитета игнорируется.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('		if MIND_IMMUNE_SPELLS.has(spell_id):', '		if false:')
open(p, "w").write(s)
PY
run_red "M9 ментальный иммунитет игнорируется"

# M10: из словаря keyword убран SLOW — ровно тот класс, который должен ловить страж.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('	"SLOW": _SE.Effect.SLOW,\n', "")
open(p, "w").write(s)
PY
run_red "M10 keyword SLOW вне словаря (страж пустышек)"

# M11: отказ по мёртвой цели снят.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('	if not is_res and not target.is_alive():', '	if false:')
open(p, "w").write(s)
PY
run_red "M11 заклинание по мёртвому цели"

# M12: множитель строки реестра игнорируется в уроне.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('		var dmg: int = sp * int(spell.params.get("amount", 1))',
              '		var dmg: int = sp')
open(p, "w").write(s)
PY
run_red "M12 множитель урона игнорируется"

# M13: лечение теряет масштаб.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('		result.heal = sp * 10', '		result.heal = sp * 5')
open(p, "w").write(s)
PY
run_red "M13 лечение = 5 × сила"

# M14: подъём не ограничен размером стека.
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('		result.revive_count = max(1, min(int(sp * 20 / hp), target.max_count))',
              '		result.revive_count = max(1, int(sp * 20 / hp))')
open(p, "w").write(s)
PY
run_red "M14 подъём без ограничения стеком"

# M15: нижняя граница подъёма снята (ноль поднятых = «успех» без подъёма).
python3 - <<'PY'
p = "scripts/data/battle_spell_bridge.gd"
s = open(p).read()
s = s.replace('		result.revive_count = max(1, min(int(sp * 20 / hp), target.max_count))',
              '		result.revive_count = min(int(sp * 20 / hp), target.max_count)')
open(p, "w").write(s)
PY
run_red "M15 нулевой подъём принят"

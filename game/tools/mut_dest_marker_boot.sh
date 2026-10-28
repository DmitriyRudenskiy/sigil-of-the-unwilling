#!/usr/bin/env bash
# Мутационная батарея T-275: «оверлей точки назначения живёт в живом дереве».
# Каждый мутант — правка одной строки в держателе оверлея; красный = падение
# tests/mcp/test_dest_marker_boot.py (живой ботстрэп мира через MCP).
# Дефолт: 2 теста зелёные. Батарея не использует git: восстановление — из копии,
# иначе `git checkout` откатывает непроверенный фикс (так и произошло на 1-м прогоне).
cd "$(dirname "$0")/.." || exit 1
export DISPLAY="${DISPLAY:-:96}" MCP_PORT="${MCP_PORT:-9478}" \
  GODOT_MCP_SERVER="$PWD/addons/godot-mcp/build/index.js" \
  GODOT_PROJECT_PATH="$PWD" \
  GODOT_PATH="${GODOT_PATH:-$HOME/.local/bin/godot}" \
  GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/godot}"
PY="${PYTEST_PY:-/home/user/.venv/godot-mcp-tests/bin/python}"
CTRL=scripts/entities/hero_visual_controller.gd
BAK=/tmp/mut_dest_marker_ctrl.gd
cp "$CTRL" "$BAK"
trap 'cp "$BAK" "$CTRL"' EXIT

run() { timeout 900 "$PY" -m pytest tests/mcp/test_dest_marker_boot.py -q -p no:cacheprovider --timeout=900 2>&1 | tail -1; }
restore() { cp "$BAK" "$CTRL"; }

echo "=== BASE (без мутантов) ==="; run

echo "=== MUT1: нет отложенной повторной попытки add_child (регресс T-275) ==="
python3 - <<'PYEOF'
from pathlib import Path
p = Path("scripts/entities/hero_visual_controller.gd")
s = p.read_text()
i = s.index("\t\tif _marker.get_parent() == null:")
j = s.index("\t\t\t_root.add_child.call_deferred(_marker)") + len("\t\t\t_root.add_child.call_deferred(_marker)\n")
p.write_text(s[:i] + s[j:])
PYEOF
run; restore

echo "=== MUT2: teardown не освобождает маркер (сирота под root) ==="
python3 - <<'PYEOF'
from pathlib import Path
p = Path("scripts/entities/hero_visual_controller.gd")
s = p.read_text()
old = "\t\t_marker.queue_free()\n"
assert s.count(old) == 1
p.write_text(s.replace(old, ""))
PYEOF
run; restore

echo "=== MUT3: маркер едет за деревом героя, а не под root (откат коррекции T-214) ==="
python3 - <<'PYEOF'
from pathlib import Path
p = Path("scripts/entities/hero_visual_controller.gd")
s = p.read_text()
old = "\t\tvar _root := get_tree().root\n"
assert s.count(old) == 1
p.write_text(s.replace(old, "\t\tvar _root := _parent\n"))
PYEOF
run; restore

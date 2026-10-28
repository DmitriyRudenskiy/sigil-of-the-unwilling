#!/usr/bin/env bash
# T-172: батарея — наблюдаемость и обратимость отказа bind().
#
# Каждый мутант снимает ровно одну защиту. Если тест после мутанта зелёный —
# защита не покрыта, а не «и так хорошо».
#
#   1. `_process` больше не крутит retry → порт после отказавшего listen не
#      поднимается никогда (исходный дефект T-172).
#   2. снят лимит попыток → вечный ретрай вместо диагноза в трейсе.
#   3. `_trace()` ничего не пишет → отказ снова невидим.
#   4. код ошибки listen не запоминается → «почему не поднялся» неизвестно.
#   5. явная stop() не защищена от retry-цикла.
#  10. «ноль» в снимке среды печатается как «не прочитано» (см. MUT10 ниже).
set -u
G="${GODOT_BIN:-$HOME/.local/bin/godot}"
S=tools/mcp/mcp_interaction_server.gd
T=tests/unit/core/test_mcp_server.gd
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# PORT — порт MCP-стенда для pytest-мутанта (GdUnit-мутанты порт выбирают сами).
PORT="${MCP_PORT:-9477}"
# Единственный снапшот — /tmp-копия и trap на ней; `git checkout --` здесь
# стёр бы незакоммиченную реализацию (урок зафиксирован в AGENTS.md).
cp "$S" /tmp/mcp_srv_readiness.bak
trap 'cp /tmp/mcp_srv_readiness.bak "$S"; [ -f /tmp/godot_mcp_readiness.bak ] && cp /tmp/godot_mcp_readiness.bak tests/mcp/godot_mcp.py; true' EXIT

# Прогон на мутант ОДИН и имена берутся из него же: второй прогон того же
# мутанта добавлял в список тесты, упавшие по соседству (живые порты), и
# «кто убит» переставало быть фактом об этом мутанте.
run_cases() {  # имена упавших тестов одного прогона (T — целевой файл)
  "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
      --ignoreHeadlessMode -c -a "res://$T" 2>&1 \
    | sed 's/\x1b\[[0-9;]*m//g' | grep "FAILED" | sed 's/.*> //' | cut -d' ' -f1 | sort -u
}

apply() {
python3 - "$1" <<'PY'
import sys
import pathlib
p = pathlib.Path("tools/mcp/mcp_interaction_server.gd")
s = p.read_text()
m = sys.argv[1]
if m == "1":
    old = "\tif not _started:\n\t\t_retry_bind_if_due()\n\t\treturn\n"
    new = "\tif not _started:\n\t\treturn\n"
elif m == "2":
    old = "\tif _bind_attempts >= MAX_BIND_ATTEMPTS:"
    new = "\tif false:"
elif m == "3":
    old = "\tvar path := boot_trace_path()\n\tif path.is_empty() or not OS.is_debug_build():"
    new = "\tvar path := \"\"\n\tif path.is_empty() or not OS.is_debug_build():"
elif m == "4":
    old = "\t_last_bind_error = err\n"
    new = ""
elif m == "5":
    old = "\t_stop_requested = true\n"
    new = ""
else:
    raise SystemExit("unknown mutant " + m)
assert s.count(old) == 1, (m, s.count(old))
p.write_text(s.replace(old, new))
PY
}

for m in 1 2 3 4 5; do
  # Откат перед КАЖДЫМ мутантом: иначе мутант 2 применяется поверх мутанта 1 и
  # «убитые» тесты рассказывают историю уже несуществующей правки.
  cp /tmp/mcp_srv_readiness.bak "$S"
  if ! apply "$m"; then echo "MUT$m: APPLY FAILED"; continue; fi
  victims="$(run_cases)"
  if [ -z "$victims" ]; then echo "MUT$m: SURVIVED (тесты зелёные — защита не покрыта)"
  else echo "MUT$m: killed -> $(echo "$victims" | tr '\n' ' ')"; fi
done

# MUT6 — счётчик живых движков в стенде. Мутация живёт не в GD-файле, а в
# godot_mcp.py, и проверяется не GdUnit, а pytest-файлом про саму наблюдаемость.
H=tests/mcp/godot_mcp.py
PYTEST_PY="${PYTEST_PY:-/home/user/.venv/godot-mcp-tests/bin/python}"
run_pytest_cases() {
  (cd "$ROOT" && DISPLAY="${DISPLAY:-:96}" MCP_PORT="$PORT" \
    GODOT_PROJECT_PATH="$ROOT" \
    GODOT_MCP_SERVER="$ROOT/addons/godot-mcp/build/index.js" \
    GODOT_PATH="${GODOT_PATH:-godot}" \
    "$PYTEST_PY" -m pytest tests/mcp/test_readiness_evidence.py \
      tests/mcp/test_godot_launcher.py -q -p no:cacheprovider --timeout=900 2>&1) || true
}

cp "$H" /tmp/godot_mcp_readiness.bak
python3 - "$H" <<'PYEOF'
import sys
from pathlib import Path
p = Path(sys.argv[1])
s = p.read_text()
old = "if not name.startswith(needle):"
new = 'if needle in _read_text(f"{proc_root}/{pid}/cmdline").lower():'
assert s.count(old) == 1, s.count(old)
p.write_text(s.replace(old, new))
PYEOF
victims="$(run_pytest_cases | sed -n 's/^FAILED tests\/mcp\/test_readiness_evidence\.py::\([a-z_0-9]*\).*/\1/p' | sort -u | tr '\n' ' ')"
if [ -z "$victims" ]; then echo "MUT6: SURVIVED (тесты зелёные — защита не покрыта)"
else echo "MUT6: killed -> $victims"; fi
cp /tmp/godot_mcp_readiness.bak "$H"

# MUT7 — хвост лога запуска выключен: «почему игра не дошла» снова неизвестно.
cp /tmp/godot_mcp_readiness.bak "$H"
python3 - "$H" <<'PYEOF'
import sys
from pathlib import Path
p = Path(sys.argv[1])
s = p.read_text()
old = '        return "лог запуска не собирался (MCP_GODOT_LOG не задан)"'
assert s.count(old) == 1, s.count(old)
s = s.replace(old, '        return ""', 1)
old2 = '            f"лог запуска {log_path} пуст — Godot не напечатал ни байта "'
assert s.count(old2) == 1, s.count(old2)
s = s.replace(old2, '            ""', 1)
p.write_text(s)
PYEOF
victims="$(run_pytest_cases | sed -n 's/^FAILED tests\/mcp\/test_\([a-z_]*\)\.py::\([a-z_0-9]*\).*/\2/p' | sort -u | tr '\n' ' ')"
if [ -z "$victims" ]; then echo "MUT7: SURVIVED (тесты зелёные — защита не покрыта)"
else echo "MUT7: killed -> $victims"; fi
cp /tmp/godot_mcp_readiness.bak "$H"

# MUT8 — точка блокировки движка превращается в «?»: отчёт снова нем про «чем он стоит».
cp /tmp/godot_mcp_readiness.bak "$H"
python3 - "$H" <<'PYEOF'
import sys
from pathlib import Path
p = Path(sys.argv[1])
s = p.read_text()
old = '    return {"wchan": wchan, "syscall": syscall, "fds": fds}'
assert s.count(old) == 1, s.count(old)
s = s.replace(old, '    return {"wchan": "?", "syscall": "?", "fds": -1}', 1)
p.write_text(s)
PYEOF
victims="$(run_pytest_cases | sed -n 's/^FAILED tests\/mcp\/test_\([a-z_]*\)\.py::\([a-z_0-9]*\).*/\2/p' | sort -u | tr '\n' ' ')"
if [ -z "$victims" ]; then echo "MUT8: SURVIVED (тесты зелёные — защита не покрыта)"
else echo "MUT8: killed -> $victims"; fi
cp /tmp/godot_mcp_readiness.bak "$H"

# MUT9 — зонд порта всегда «не проверялся»: развилка «порта нет» / «accept не случился»
# исчезает из отчёта, и жертва снова выглядит как «среда».
cp /tmp/godot_mcp_readiness.bak "$H"
python3 - "$H" <<'PYEOF'
import sys
from pathlib import Path
p = Path(sys.argv[1])
s = p.read_text()
old = '    if not port:\n        return "не проверялся (порт не задан)"'
assert s.count(old) == 1, s.count(old)
s = s.replace(old, '    if port is not None:\n        return "не проверялся (порт не задан)"', 1)
p.write_text(s)
PYEOF
victims="$(run_pytest_cases | sed -n 's/^FAILED tests\/mcp\/test_\([a-z_]*\)\.py::\([a-z_0-9]*\).*/\2/p' | sort -u | tr '\n' ' ')"
if [ -z "$victims" ]; then echo "MUT9: SURVIVED (тесты зелёные — защита не покрыта)"
else echo "MUT9: killed -> $victims"; fi
cp /tmp/godot_mcp_readiness.bak "$H"

# MUT10 — `round(kb / 1024) or None`: ноль доступной памяти сливается с отсутствием
# данных, и отчёт печатает «не прочитано» ровно на том номере, который и решает
# гипотезу «среда отняла память» (замер гейта 2026-10-28: swap_free=403/20479MB).
cp /tmp/godot_mcp_readiness.bak "$H"
python3 - "$H" <<'PYEOF'
import sys
from pathlib import Path
p = Path(sys.argv[1])
s = p.read_text()
old = '    kb = mem.get(key)\n    return None if kb is None else round(kb / 1024)'
assert s.count(old) == 1, s.count(old)
s = s.replace(old, '    return round(mem.get(key, 0) / 1024) or None', 1)
p.write_text(s)
PYEOF
victims="$(run_pytest_cases | sed -n 's/^FAILED tests\/mcp\/test_\([a-z_]*\)\.py::\([a-z_0-9]*\).*/\2/p' | sort -u | tr '\n' ' ')"
if [ -z "$victims" ]; then echo "MUT10: SURVIVED (тесты зелёные — защита не покрыта)"
else echo "MUT10: killed -> $victims"; fi
cp /tmp/godot_mcp_readiness.bak "$H"

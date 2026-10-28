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
set -u
G="${GODOT_BIN:-$HOME/.local/bin/godot}"
S=tools/mcp/mcp_interaction_server.gd
T=tests/unit/core/test_mcp_server.gd
cd "$(dirname "$0")/.."
# Единственный снапшот — /tmp-копия и trap на ней; `git checkout --` здесь
# стёр бы незакоммиченную реализацию (урок зафиксирован в AGENTS.md).
cp "$S" /tmp/mcp_srv_readiness.bak
trap 'cp /tmp/mcp_srv_readiness.bak "$S"' EXIT

fail_cases() {  # ожидаемые падение теста; печатает FAILED-имена
  "$G" --headless --path . -s addons/gdunit4/bin/GdUnitCmdTool.gd \
      --ignoreHeadlessMode -c -a "res://$T" 2>&1 \
    | sed 's/\x1b\[[0-9;]*m//g' | grep "FAILED" | sed 's/.*> //' | cut -d' ' -f1 | sort -u
}
green() { [ -z "$(fail_cases)" ]; }

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
  if ! apply "$m"; then echo "MUT$m: APPLY FAILED"; continue; fi
  if green; then echo "MUT$m: SURVIVED (тесты зелёные — защита не покрыта)"
  else echo "MUT$m: killed -> $(fail_cases | tr '\n' ' ')"; fi
done

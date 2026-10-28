#!/bin/sh
# T-172: обёртка Godot для MCP-стенда — единственный способ увидеть, что движок
# говорил до отказа readiness.
#
# Стенд не управляет тем, как вендорский node-сервер запускает игру: он только
# передаёт путь в GODOT_PATH. Значит канал для логов — сам путь. Обёртка
# перенаправляет stdout+stderr движка в файл (MCP_GODOT_LOG) и передаёт управление
# настоящему бинарю через `exec`.
#
# `exec` обязателен, а не «запустить и ждать»: node-сервер хранит PID этого
# процесса и убивает именно его (`activeProcess.process.kill()`). Обычный запуск
# оставил бы shell-посредника, а Godot пережил бы kill — утёкший движок следующего
# теста занимает порт и память (ровний класс симптомов, который мы и ловим).
#
# --version идёт транзитом без перенаправления: сервер читает версию из stdout
# (`execFileAsync(godotPath, ['--version'])`), и перенаправление съело бы её.
#
# Без MCP_GODOT_LOG обёртка прозрачна: тот же argv, тот же stdout.
REAL="${MCP_GODOT_REAL:?MCP_GODOT_REAL не задан (обёртка найдётся в tests/mcp/)}"

for arg in "$@"; do
    if [ "$arg" = "--version" ]; then
        exec "$REAL" "$@"
    fi
done

if [ -z "${MCP_GODOT_LOG:-}" ]; then
    exec "$REAL" "$@"
fi

mkdir -p "$(dirname "$MCP_GODOT_LOG")" 2>/dev/null
exec "$REAL" "$@" >>"$MCP_GODOT_LOG" 2>&1

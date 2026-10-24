#!/usr/bin/env bash
# Проверка сервера генерации перед фазой 6 (задача 6.2 tasks.md).
# Каждый инструмент вызван, каждый узел запрошен — вывод в журнал
# battle-demo/artifacts/comfy-check.log (пиксели в git не идут, логи — да).
set -u
cd "$(dirname "$0")/.."

MCP="${MCP_URL:-http://192.168.0.230:9000/mcp}"
COMFY="${COMFY_URL:-http://192.168.0.230:8188}"
HDR=(-H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream')

# Сервер stateless (uvicorn, без mcp-session-id) — заголовок подставляется, только
# если он всё же пришёл.
mcp() {
	if [ -n "$SID" ]; then
		curl -sS -m 120 "${HDR[@]}" -H "mcp-session-id: $SID" -d "$1" "$MCP"
	else
		curl -sS -m 120 "${HDR[@]}" -d "$1" "$MCP"
	fi
	echo
}

echo "== initialize $MCP"
HEADERS=$(mktemp)
INIT=$(curl -sS -m 30 -D "$HEADERS" "${HDR[@]}" \
	-d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"battle-demo","version":"1"}}}' "$MCP")
SID=$(grep -i '^mcp-session-id:' "$HEADERS" | tr -d '\r' | awk '{print $2}')
rm -f "$HEADERS"
echo "$INIT" | grep -o '"serverInfo":{[^}]*}'
echo "session: ${SID:-нет (stateless)}"

echo "== tools/list"
mcp '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | grep -o '"name":"[a-z0-9_]*"' | sort -u

for tool in get_queue_status list_models list_workflows; do
	echo "== tools/call $tool"
	mcp "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"$tool\",\"arguments\":{}}}" | head -c 1200
	echo
done

echo "== GET $COMFY/queue"
curl -sS -m 20 "$COMFY/queue" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("running=%d pending=%d" % (len(d["queue_running"]), len(d["queue_pending"])))'

echo "== GET $COMFY/object_info (узлы графа D13/D14)"
for node in TextEncodeQwenImage21 QwenImage21Cache UNETLoader CLIPLoader VAELoader LoadImage SaveImage KSampler VAEDecode OpenposePreprocessor; do
	printf '%s ' "$node"
	curl -sS -m 20 "$COMFY/object_info/$node" | python3 -c "import json,sys; d=json.load(sys.stdin); print('OK' if '$node' in d else 'НЕТ')"
done

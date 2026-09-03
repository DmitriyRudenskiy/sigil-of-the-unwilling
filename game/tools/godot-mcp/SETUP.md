# godot-mcp (Full Control) — integration

AI-controlled-running-Godot over a TCP socket. Two halves:

1. **In-game GDScript server** — `game/scripts/autoload/mcp_interaction_server.gd`
   (+ `godot_operations.gd`), registered as the `McpInteractionServer` autoload.
   Listens on `127.0.0.1:9090`, accepts newline-delimited JSON commands.
2. **Node MCP server** — this folder (`build/index.js`), MCP-stdio facing the AI
   client (Claude Code / Cursor / Cline ...). Exposes **157 tools**
   (`game_eval`, `game_screenshot`, `get_scene_tree`, `set_property`, keys/mouse,
   shaders, physics ...). It connects back to the in-game server on 9090.

## Config
`.mcp.json` at the repo root wires the Node server into an MCP-capable AI client.
Edit `args[0]` if the repo moves.

## Run the full loop
```bash
# 1. Launch the game with the MCP flag (SocketController on 9095 stays OFF).
godot --path game --headless --mcp-server --scene scenes/MainMenu.tscn

# 2. In the AI client, add .mcp.json and connect. The server auto-connects to 9090.
```
The GDScript server is **flag-gated** (`--mcp-server`), so normal/windowed builds
don't spin up an always-on TCP server — same convention as `SocketController`
(`--socket-server` → 9095).

## Protocol (direct, without the Node server)
Newline-delimited JSON. Example:
```json
{"command":"get_performance","id":1}
```
See `mcp_interaction_server.gd` `_handle_command` for the full command table.

## Notes
- Requires Godot 4.4+ (project is 4.7 — verified compiles + live TCP round-trip).
- `node_modules/` is gitignored; run `npm install` to regenerate.
- Build: `npm run build` (tsc + scripts/build.js) → `build/`.
- Does **not** ship the project's game-specific commands (`EMULATE_BATTLE`,
  `CITY_BUILD`, ...). Those live on `SocketController` (9095) and its 13 Python
  scenarios. Use `game_eval` to call them indirectly, or keep driving the socket
  harness as-is.

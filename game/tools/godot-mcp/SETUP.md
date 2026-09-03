# godot-mcp (Full Control) — integration

AI-controlled-running-Godot over a TCP socket. Two halves:

1. **In-game GDScript server** — `game/scripts/autoload/mcp_interaction_server.gd`
   (+ `godot_operations.gd`), registered as the `McpInteractionServer` autoload.
   Listens on `127.0.0.1:9090`, accepts newline-delimited JSON commands.
2. **Node MCP server** — this folder (`build/index.js`), MCP-stdio facing the AI
   client (Claude Code / Cursor / Cline ...). Exposes **157 tools**
   (`game_eval`, `game_screenshot`, `get_scene_tree`, `set_property`, keys/mouse,
   shaders, physics ...). It is a **lifecycle manager**: it launches the game
   itself (`run_project`) and connects back to it on 9090.

## Config
`.mcp.json` at the repo root wires the Node server into an MCP-capable AI client.
`GODOT_PATH` (macOS auto-detects `/Applications/Godot.app/.../Godot`) and
`GODOT_MCP_ALLOWED_DIRS` point it at this project.

## Run the full loop
```bash
# 1. In the AI client, add .mcp.json and connect.
# 2. Tell it to start the game, e.g. call the `run_project` tool:
#      { "projectPath": "/Users/user/sigil-of-the-unwilling/game",
#        "scene": "scenes/MainMenu.tscn" }
#    The Node server launches `godot -d --path <proj> [scene]` and connects.
# 3. Drive it with any of the 157 tools, e.g. `game_eval`:
#      { "code": "return int(get_tree().root.get_node_count())" }
```
The GDScript server **listens whenever the game runs** (the autoload is opt-in —
it only exists after installing godot-mcp — and binds loopback-only). No launch
flag is needed; `run_project` starts Godot without one.

## Notes
- Requires Godot 4.4+ (project is 4.7 — verified: compiles, live TCP round-trip,
  Node returns 157 tools, `game_eval` executes arbitrary GDScript reliably).
- `node_modules/` is gitignored; run `npm install` to regenerate.
- Build: `npm run build` (tsc + scripts/build.js) → `build/`.
- Does **not** ship the project's game-specific commands (`EMULATE_BATTLE`,
  `CITY_BUILD`, ...). Those live on `SocketController` (9095) and its 13 Python
  scenarios. Reach them via `game_eval` (call the socket helpers directly) or keep
  driving the socket harness as-is.
- If `game_eval` ever hangs, the upstream server holds a `_busy` lock until a
  ~30s safety timeout recovers it; a command that throws before responding leaves
  the lock held. (Upstream behaviour — no try/catch around the command dispatch.)

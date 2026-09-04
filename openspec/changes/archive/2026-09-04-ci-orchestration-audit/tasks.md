## Tasks

- [x] Inspect `game/tools/shell/*` and the tool scripts they drive.
- [x] Confirm the GUT-rewrite is infeasible (registry bootstrap needs `--editor`;
      subprocess log scanning and Python socket scenarios are shell/CI concerns;
      no `game/tests/integration/` pattern exists; proposed pseudocode references
      non-existent methods).
- [x] Record the assessment in design.md so the rewrite is not re-proposed.
- [x] (optional) Add a one-line comment to `play_scenario.sh` pointing at
      `SocketController.gd` as the source of `PORT=9095`.

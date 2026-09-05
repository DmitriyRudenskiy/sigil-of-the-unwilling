extends RefCounted
class_name GameSettings
## Общие константы (аудит #16: доменные конфиги вынесены в
## BattleConfig / MapConfig / UIConfig / EndgameConfig).

const INF := 1e9  # float, compatible with PackedFloat32Array

# --- Save/Load ---
const SAVE_MAGIC := "SIG_SAVE"

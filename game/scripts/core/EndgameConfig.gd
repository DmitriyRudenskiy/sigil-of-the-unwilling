## scripts/core/EndgameConfig.gd
## Константы эндгейма (аудит #16: вынесено из GameSettings).
class_name EndgameConfig
extends RefCounted

# --- Endgame (endgame-conditions) ---
## Победа «Путь завершён»: суммарная слава забега (GloryTracker.total).
const ENDGAME_GLORY_VICTORY := 500

## Победа «Доминация»: все вражеские стеки уничтожены. Если false —
## условие победы по доминации не проверяется.
const ENDGAME_DOMINATION_ENABLED := true

## Поражение «Тотальный коллапс»: у игрока не осталось городов.
const ENDGAME_COLLAPSE_ENABLED := true

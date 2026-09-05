## scripts/core/BattleConfig.gd
## Константы боя (аудит #16: вынесено из GameSettings).
class_name BattleConfig
extends RefCounted

## Максимум юнитов (инициатив) в бою с каждой из сторон.
const BATTLE_MAX_UNITS_PER_SIDE := 7

# --- Battle ---
const BATTLE_AI_THINK_TIME := 0.7

const BATTLE_TURN_DELAY := 0.15

const BATTLE_RETREAT_LOSS_FRACTION := 0.5

const BATTLE_DEFEND_BONUS_DEFENSE := 0.20

const BATTLE_SPELL_ANIM_TIME := 0.35

const BATTLE_ATTACK_ANIM_SEC := 0.3

const ASTAR_HEURISTIC_WEIGHT := 1.0  # 1.0 = optimal path, >1.0 = faster but not optimal

# --- Battle magic numbers ---
const STATUS_PROC_CHANCE := 0.20  # petrify / blind

const REBIRTH_CHANCE := 0.20

const CHARGE_MULT := 1.5

const BREATH_DMG_RATIO := 0.5

const RETREAT_STACK_LIMIT := 2

const CLICK_RADIUS_PX := 60.0

# --- Battle View ---
const BATTLE_FIELD_RING := 5

const BATTLE_HEX_OUTLINE_RADIUS := 38.0

const BATTLE_ATTACK_LUNGE_PX := 26.0

const BATTLE_MOVE_TWEEN_SEC := 0.15

const BATTLE_FLOATING_TEXT_OFFSET := Vector2(-30, -60)

const BATTLE_DAMAGE_NUMBER_OFFSET := Vector2(-16, -50)

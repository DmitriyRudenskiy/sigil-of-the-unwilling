class_name GameNumbersHero
extends RefCounted

const HERO_DAILY_MOVEMENT       := 10.0
const HERO_BASE_SPEED           := 120.0
const TOOL_INVENTORY_SLOTS      := 8
const MAX_BACKPACK_SIZE         := 16
const MAX_HERO_ARMY_SIZE        := 7
const HERO_RETREAT_LOSS_FRACTION := 0.5
const HERO_LEVEL_UP_EXP         := 100
const HERO_BASE_MANA            := 20
# Ранняя игра: личный боец героя (early-game-foundation)
const HERO_BATTLE_KEY           := "hero"
const HERO_PERSONAL_SPEED       := 5
const RANGER_ANIMAL_DAMAGE_BONUS := 3
const ROGUE_CRIT_CHANCE         := 0.15
const ROGUE_CRIT_MULTIPLIER     := 2
const PRIEST_TURN_HEAL          := 2
# Дикие животные 1-го кольца (Druid: убегают; Ranger: +урон)
const WILD_ANIMAL_KEYS          := ["wolves", "gremlin"]
const HERO_MANA_TICK            := 1
const NEED_REST_DECAY           := 0.10
const NEED_SOCIAL_DECAY         := 0.08
const NEED_INSP_DECAY           := 0.05
const NEED_REST_RECOVERY_CITY   := 0.36
const NEED_REST_RECOVERY_POP    := 0.12
const NEED_SOCIAL_RECOVERY_CITY := 0.30
const NEED_SOCIAL_RECOVERY_POP  := 0.10
const NEED_INSP_RECOVERY_CITY   := 0.15
const NEED_INSP_RECOVERY_POP    := 0.05
const NEED_SOCIAL_RECOVERY_LOW  := -0.05
const SUCCESSION_RESURRECT_IND  := 500.0
const SUCCESSION_RESURRECT_GOLD := 100.0
const SUCCESSION_SPECIAL_KEY    := &"gold"
const GLORY_VICTORY_THRESHOLD   := 500
const ENDGAME_DOMINATION_ENABLED := true
const ENDGAME_COLLAPSE_ENABLED   := true

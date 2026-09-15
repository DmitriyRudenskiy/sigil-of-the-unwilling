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
# Рюкзак героя: общий лимит и расширение (early-game-foundation)
const BACKPACK_TOTAL_CAP        := 12
const BACKPACK_CART_BONUS       := 6
const BACKPACK_CART_COST        := 20.0
# attribute-weight-system: весовая переноска.
# ponytail: базовая 16 + defense*1.0 — грубая калибровка под defense 2–8;
# upgrade path: отдельная таблица по defense, если баланс-проба покажет
# непропорциональность на высоких defense.
const WEIGHT_BASE_CAP           := 16.0
const WEIGHT_PER_DEFENSE        := 1.0
# Штраф экипировки сверх лимита: доля превышения → −20% MP и +0.10 REST/ход
# на максимум превышения (50%+). ponytail: линейно, без ступеней.
const OVERLOAD_MP_PENALTY_MAX   := 0.20
const OVERLOAD_REST_PENALTY_MAX := 0.10
# Сила: добыча (REST-штраф −50% при attack 8+, улов +1 при attack 6+).
# ponytail: две ступени, не формула; upgrade: плавная шкала, если захочется
# более тонкого баланса.
const EXTRACT_REST_REDUCE_MIN_ATTACK := 8
const EXTRACT_YIELD_BONUS_ATTACK     := 6
# Внимательность: шанс скрытого узла +5% на уровень 2+ (база 0.08).
const HIDDEN_NODE_CHANCE_BASE   := 0.08
const HIDDEN_NODE_KNOWLEDGE_BONUS := 0.05
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
# ponytail: «низкий» (не в городе) соц.реставр — +0.05, был -0.05: герой вне
# города не должен терять социальность быстрее, чем отдыхает (отдых вне
# города +0.02) — баланс по balance-core прогону: одинокий герой умирал от
# изоляции на 9-м ходу, не успев ни построить, ни рекрутить. Если ранняя
# игра станет слишком прощённой — поднимать SOCIAL_DECAY, не возвращать LOW.
# ponytail: «низкий» (вне города) реставр — ≈ decay, чистый спад −0.01/ход:
# герой без города умирает от needs ~на 100-м ходу, а не на 9–12-м (ранние
# DEFEAT balance-core: изоляция на 9, истощение на 12). Механика «нужно
# посещать город» сохранена, но давит на длинной дистанции, а не в ранней
# игре. Если герой станет бессмертным — поднимать DECAY, не опускать LOW.
const NEED_SOCIAL_RECOVERY_LOW  := 0.07
const NEED_REST_RECOVERY_LOW    := 0.09
const NEED_INSP_RECOVERY_LOW    := 0.04
const SUCCESSION_RESURRECT_IND  := 500.0
const SUCCESSION_RESURRECT_GOLD := 100.0
const SUCCESSION_SPECIAL_KEY    := &"gold"
const GLORY_VICTORY_THRESHOLD   := 500
const ENDGAME_DOMINATION_ENABLED := true
const ENDGAME_COLLAPSE_ENABLED   := true


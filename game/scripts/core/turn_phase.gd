class_name TurnPhase
extends RefCounted
## T-010: канонический реестр фаз хода (владелец, round 7 §2.2, «порядок фиксирован»).
##
## Порядок фаз хода (фиксирован, не зависит от порядка регистрации):
##   1. city_population          — городские и популяционные события
##   2. hero_movement            — движение героя/армии
##   3. caravans_trade           — караваны и торговля
##   4. diplomacy_council        — дипломатия и Совет
##   5. battle_raid_resolution   — разрешение боёв и рейдов
##   6. production               — расчёт производства
##
## MVP-маска: caravans_trade и diplomacy_council — каркас (Post-MVP, F3):
## фазы присутствуют в конвейере, процессоры-заглушки возвращают
## {"skeleton": true} и не изменяют состояние.
## unphased — процессоры без явной фазы: выполняются последними (legacy-совместимость).

enum ID {
	CITY_POPULATION,
	HERO_MOVEMENT,
	CARAVANS_TRADE,
	DIPLOMACY_COUNCIL,
	BATTLE_RAID_RESOLUTION,
	PRODUCTION,
	UNPHASED,
}

const PHASE_IDS: Array[StringName] = [
	&"city_population",
	&"hero_movement",
	&"caravans_trade",
	&"diplomacy_council",
	&"battle_raid_resolution",
	&"production",
	&"unphased",
]

## Фазы-каркас в MVP (Post-MVP): присутствуют в конвейере, не изменяют состояние.
const MVP_SKELETON: Array[StringName] = [
	&"caravans_trade",
	&"diplomacy_council",
]


static func phase_name(id: int) -> StringName:
	if id >= 0 and id < PHASE_IDS.size():
		return PHASE_IDS[id]
	return &"unphased"


## Позиция фазы в каноническом порядке; неизвестная фаза — последняя.
static func order_index(phase: StringName) -> int:
	var i: int = PHASE_IDS.find(phase)
	return i if i >= 0 else PHASE_IDS.size() - 1


static func is_skeleton(phase: StringName) -> bool:
	return MVP_SKELETON.has(phase)

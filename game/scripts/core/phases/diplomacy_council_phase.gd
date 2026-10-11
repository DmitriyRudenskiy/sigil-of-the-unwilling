class_name DiplomacyCouncilPhase
extends TurnPhaseProcessor
## T-010: фаза «дипломатия и Совет» — MVP-каркас (Post-MVP).
## Фаза присутствует в конвейере (порядок фиксирован), состояние не изменяет.
## Совет (K-M16: MVP — одна сессия, ход 12) подключается здесь в Post-MVP.

func get_phase_id() -> StringName:
	return TurnPhase.phase_name(TurnPhase.ID.DIPLOMACY_COUNCIL)


func get_phase() -> StringName:
	return get_phase_id()


func process(_ctx: TurnContext) -> Dictionary:
	return {"skeleton": true, "post_mvp": true}

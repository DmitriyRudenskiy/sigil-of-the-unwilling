class_name CaravansTradePhase
extends TurnPhaseProcessor
## T-010: фаза «караваны и торговля» — MVP-каркас (Post-MVP, F3: караваны вне MVP-маски).
## Фаза присутствует в конвейере (порядок фиксирован), состояние не изменяет.

func get_phase_id() -> StringName:
	return TurnPhase.phase_name(TurnPhase.ID.CARAVANS_TRADE)


func get_phase() -> StringName:
	return get_phase_id()


func process(_ctx: TurnContext) -> Dictionary:
	return {"skeleton": true, "post_mvp": true}

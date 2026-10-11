class_name TurnPhaseProcessor
extends RefCounted

func get_phase_id() -> StringName:
	return &""

## T-010: каноническая фаза (TurnPhase.PHASE_IDS). Определяет блок исполнения
## в фиксированном порядке хода; внутри фазы — get_priority(), затем порядок регистрации.
## По умолчанию &"unphased" (legacy-совместимость: выполняется последним).
func get_phase() -> StringName:
	return TurnPhase.phase_name(TurnPhase.ID.UNPHASED)

func get_priority() -> int:
	return 100

func process(_ctx: TurnContext) -> Dictionary:
	return {}

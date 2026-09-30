class_name TurnPhaseProcessor
extends RefCounted

func get_phase_id() -> StringName:
	return &""

func get_priority() -> int:
	return 100

func process(_ctx: TurnContext) -> Dictionary:
	return {}

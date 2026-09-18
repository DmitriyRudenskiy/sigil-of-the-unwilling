class_name CollectorRole
extends ScenarioRole
## autopilot-scenario-matrix: Собиратель — собрать N редких ресурсов за 60 ходов.

func goal_met(pilot) -> bool:
	return pilot.rare_count() >= int(target.get("rare_goal", 0))

func metrics(pilot) -> Dictionary:
	return {
		"rare_extracted": pilot.rare_count(),
		"rare_goal": int(target.get("rare_goal", 0)),
		"resources_extracted": pilot.extracted_total,
	}

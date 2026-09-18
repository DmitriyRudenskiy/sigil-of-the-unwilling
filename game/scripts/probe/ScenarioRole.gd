class_name ScenarioRole
extends RefCounted
## autopilot-scenario-matrix (D1): роль = политика поверх общего автопилота.
## pick_action/goal_met/metrics — интерфейс политики; базовый _step переиспользует BalanceProbe.

var id: String = ""
var target: Dictionary = {}

## Цель достигнута? (ранний финиш прогона)
func goal_met(pilot) -> bool:
	return false

## Метрики роли для отчёта.
func metrics(pilot) -> Dictionary:
	return {}

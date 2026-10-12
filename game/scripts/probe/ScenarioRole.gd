class_name ScenarioRole
extends RefCounted
## autopilot-matrix (D1): роль = политика поверх общего автопилота.
## goal_met/metrics — обязательный интерфейс; хуки — опциональная
## кастомизация базового цикла BalanceProbe (сбор, враги, полный кадр).

var id: String = ""
var target: Dictionary = {}

## Цель достигнута? (ранний финиш забега)
func goal_met(_pilot: Node) -> bool:
	return false

## Метрики роли для отчёта.
func metrics(_pilot: Node) -> Dictionary:
	return {}

## Кадр роли: true — кадр обработан (базовый _step не вызывается).
func act(_pilot: Node) -> bool:
	return false

## Цель сбора: null — базовая логика; Vector2i — конкретная клетка;
## Vector2i(-1,-1) — цели нет (сбор пропускается).
func collect_target(_pilot: Node):
	return null

## Цель атаки: null — базовая логика; Vector2i — конкретная клетка;
## Vector2i(-1,-1) — цели нет.
func enemy_target(_pilot: Node):
	return null

## Победа/поражение в бою героя (авторитетный WorldBattleCoordinator event).
func on_battle_won(_pilot: Node, _cell: Vector2i) -> void:
	pass

func on_battle_lost(_pilot: Node, _cell: Vector2i) -> void:
	pass

## Герой жив и нет DEFEAT в конце мира.
func survived(pilot: Node) -> bool:
	var eg: Dictionary = pilot._world.get_endgame_state() if pilot._world != null else {}
	return str(eg.get("state", "")) != "DEFEAT"

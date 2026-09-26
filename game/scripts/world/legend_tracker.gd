class_name LegendTracker
extends RefCounted
## Отслеживает легенду героя сквозь поколения.
## Легенда — это совокупность пути, уровня славы и накопленных знаний.

signal generation_completed(generation: int, hero_name: String, outcome: String)

var path_id: StringName = &""
var level: int = 0
var total_glory: float = 0.0
var generation_count: int = 0
var battles_won: int = 0
var battles_lost: int = 0
var deaths_by_cause: Dictionary = {}
var resurrection_count: int = 0

## Инициализация легенды при создании нового героя.
func init_legend(p_path_id: StringName) -> void:
	path_id = p_path_id
	level = 0
	total_glory = 0.0
	generation_count = 1
	battles_won = 0
	battles_lost = 0
	deaths_by_cause = {}
	resurrection_count = 0

## Запись смерти текущего героя.
func record_death(cause: StringName) -> void:
	deaths_by_cause[cause] = int(deaths_by_cause.get(cause, 0)) + 1

## Запись победы в бою.
func record_battle_won() -> void:
	battles_won += 1

## Запись поражения в бою.
func record_battle_lost() -> void:
	battles_lost += 1

## Добавление славы.
func add_glory(amount: float) -> void:
	total_glory += maxf(0.0, amount)

## Запись воскрешения.
func record_resurrection() -> void:
	resurrection_count += 1

## Переход к следующему поколению.
func advance_generation(hero_name: String, outcome: String = "succession") -> void:
	generation_count += 1
	generation_completed.emit(generation_count, hero_name, outcome)

## Проверка, завершён ли путь (победа).
func is_path_complete(threshold: float) -> bool:
	return total_glory >= threshold

## Сериализация.
func serialize() -> Dictionary:
	return {
		"path_id": String(path_id),
		"level": level,
		"total_glory": total_glory,
		"generation_count": generation_count,
		"battles_won": battles_won,
		"battles_lost": battles_lost,
		"deaths_by_cause": deaths_by_cause.duplicate(),
		"resurrection_count": resurrection_count,
	}

## Десериализация.
func deserialize(data: Dictionary) -> void:
	path_id = StringName(str(data.get("path_id", "")))
	level = int(data.get("level", 0))
	total_glory = float(data.get("total_glory", 0.0))
	generation_count = int(data.get("generation_count", 0))
	battles_won = int(data.get("battles_won", 0))
	battles_lost = int(data.get("battles_lost", 0))
	deaths_by_cause = (data.get("deaths_by_cause", {}) as Dictionary).duplicate()
	resurrection_count = int(data.get("resurrection_count", 0))

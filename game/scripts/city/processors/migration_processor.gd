class_name MigrationProcessor
extends CitySubProcessor
## Reputation-driven migration (immigrants/emigrants).

signal migration_occurred(city_uid: int, immigrants: int, emigrants: int)


func get_id() -> StringName:
	return &"migration"

## social-stats-weapon-tech: провайдер героя (для cha-модификатора иммиграции)
var hero_provider: Callable = Callable()

func _hero_cha(city: City) -> int:
	if hero_provider.is_valid():
		var hero = hero_provider.call()
		if hero != null and city != null and hero.current_cell == city.center:
			return int(hero.stats.get("cha", -1))
	return -1


func process(city: City, _turn: int, report: Dictionary) -> void:
	var mig: Dictionary = ReputationSystem.process_migration(city, _hero_cha(city))
	report["immigrants"] = int(mig.immigrants)
	report["emigrants"] = int(mig.emigrants)
	if int(mig.immigrants) > 0 or int(mig.emigrants) > 0:
		migration_occurred.emit(city.uid, int(mig.immigrants), int(mig.emigrants))

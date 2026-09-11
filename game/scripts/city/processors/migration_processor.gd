class_name MigrationProcessor
extends CitySubProcessor
## Reputation-driven migration (immigrants/emigrants).

signal migration_occurred(city_uid: int, immigrants: int, emigrants: int)


func get_id() -> StringName:
	return &"migration"


func process(city: City, _turn: int, report: Dictionary) -> void:
	var mig: Dictionary = ReputationSystem.process_migration(city)
	report["immigrants"] = int(mig.immigrants)
	report["emigrants"] = int(mig.emigrants)
	if int(mig.immigrants) > 0 or int(mig.emigrants) > 0:
		migration_occurred.emit(city.uid, int(mig.immigrants), int(mig.emigrants))

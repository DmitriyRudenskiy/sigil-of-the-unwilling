class_name CityEventsProcessor
extends CitySubProcessor
## Random city events.

signal city_event_occurred(city_uid: int, event_id: StringName)


func get_id() -> StringName:
	return &"city_events"


func process(city: City, turn: int, report: Dictionary) -> void:
	var ev: Dictionary = CityEvents.resolve(city, turn)
	if bool(ev.occurred):
		report["event_occurred"] = 1
		report["event"] = String(ev.event_id)
		city_event_occurred.emit(city.uid, ev.event_id)

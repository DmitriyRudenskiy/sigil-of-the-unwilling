class_name TurnContext
extends RefCounted

var turn_number: int = 0
var month: int = 1
var week: int = 1
var day: int = 1
var season: int = Season.ID.SPRING
var weather: int = GameNumbers.WEATHER_CLEAR

var cities: Array[City] = []
var heroes: Array = []
var global_resources: Variant = null
var event_queue: Array[Dictionary] = []
var rng: RandomNumberGenerator = null

func get_date_label() -> String:
	return "день %d (%d/%d/%d)" % [turn_number, day, week, month]

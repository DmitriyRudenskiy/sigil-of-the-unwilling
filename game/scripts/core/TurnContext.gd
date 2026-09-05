class_name TurnContext
extends RefCounted
## Контекст хода: передаётся всем фазовым процессорам TurnScheduler.
##
## Содержит дату/сезон/погоду и ссылки на срезы игрового мира
## (города, герои). Процессоры читают мир через ctx и возвращают
## отчёты; мутация допустима только через публичные API сущностей.

var turn_number: int = 0
var month: int = 1
var week: int = 1
var day: int = 1
## Сезон (Season.ID). Пересчитывается планировщиком из month.
var season: int = Season.ID.SPRING
## Погода (MapConfig.WEATHER_*). По умолчанию — ясно.
var weather: int = MapConfig.WEATHER_CLEAR

## Города мира (срединка: Array[City] городами CityManager).
var cities: Array[City] = []
## Герои (не типизированно: entities-слой не должен зависеть от core).
var heroes: Array = []
## Глобальное хранилище ресурсов (M1). null до инициализации экономики.
## Тип Variant намеренно: core не должен хардкодом тянуть economy/.
var global_resources: Variant = null
## Очередь событий хода: процессоры могут добавлять сюда события
## для обработки последующими фазами / интеграционным слоем.
var event_queue: Array[Dictionary] = []
## RNG для недетерминированных фаз (демография и т.п.). null =
## процессор сам сидирует (воспроизводимо по (ход, сущность)).
var rng: RandomNumberGenerator = null


func get_date_label() -> String:
	return "день %d (%d/%d/%d)" % [turn_number, day, week, month]

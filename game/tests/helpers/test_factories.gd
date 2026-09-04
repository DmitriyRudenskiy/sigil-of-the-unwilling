class_name TestFactories
extends RefCounted
## Совместные фабрики для тестов (см. design.md D6).
##
## Заменяют дублирующиеся локальные `_make_*` хелперы: каждый вызов
## `TestFactories.make_city()`/`make_hero()`/`make_follower()` возвращает
## новый объект с тем же стартовым состоянием, что и прежний локальный
## хелпер, поэтому поведение тестов не меняется.
##
## Хелперы-заглушки (stub) в harness-тестах (test_hero_survival,
## test_succession, test_legend_chronicle, test_worldcontroller_succession_
## wiring, test_city_income_processor, test_follower, test_follower_race_class)
## НЕ переносятся: они строят локальные `_Hero`/`_Follower`/`_City` двойники
## для изолированного тестирования внутренних систем и не являются дубликацией.

const City := preload("res://scripts/world/City.gd")
const HeroController := preload("res://scripts/entities/HeroController.gd")
const Follower := preload("res://scripts/entities/Follower.gd")


## Город по умолчанию: `make_city(uid: int = 1, stronghold: int = 2)` — та же
## стартовая точка, что и в test_city_systems / test_economic_processor /
## test_city_processor / test_city_chains / test_save_v3.
static func make_city(uid: int = 1, stronghold: int = 2) -> City:
	var city := City.new()
	city.uid = uid
	city.display_name = "TestTown %d" % uid
	city.center = Vector2i(5, 5)
	city.stronghold_level = stronghold
	city.storage[&"industry"] = 500.0
	return city


## Герой с путём по умолчанию `archivist`.
static func make_hero(path := &"archivist") -> HeroController:
	var h := HeroController.new()
	h.hero_name = "Darkstorn"
	h.path_id = path
	return h


## Последователь с путём по умолчанию.
static func make_follower(uid: int, path := &"archivist") -> Follower:
	var f := Follower.new()
	f.uid = uid
	f.path = path
	return f

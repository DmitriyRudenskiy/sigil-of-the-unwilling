extends RefCounted
class_name SaveData
## Save file data container.

const CURRENT_VERSION := 5
const CURRENT_GENERATOR_VERSION := 1

var version: int = CURRENT_VERSION
var generator_version: int = CURRENT_GENERATOR_VERSION
var run_seed: int = 0
var date: Dictionary = {"month": 1, "week": 1, "day": 1}
var hero: Dictionary = {}
var world: Dictionary = {}
# --- Сохранение v3 (Каскад Сложности): состояние городов и персонажей ---
## Сериализованные города (City.serialize()). v2-сейвы: пустой список.
var cities: Array = []
## Сериализованные персонажи (CharacterRegistry.serialize()). v2: пусто.
var characters: Array = []
# --- Сохранение v4 (Succession-Sigil): преемник и легенда ---
## Преемник (SuccessionController.build_successor serialize). Пусто, пока
## герой жив или преемник не выбран.
var successor: Dictionary = {}
## Состояние легенды: путь, уровень, слава. Пусто по умолчанию.
var legend: Dictionary = {}
# --- Сохранение v5 (endgame-conditions): состояние забега ---
## Состояние забега (GameSession.serialize): state/end_reason/счётчики.
## v4-сейвы: пусто → RUNNING (миграция ниже).
var session: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"version": version,
		"generator_version": generator_version,
		"run_seed": run_seed,
		"date": date,
		"hero": hero,
		"world": world,
		"cities": cities,
		"characters": characters,
		"successor": successor,
		"legend": legend,
		"session": session,
	}


func from_dict(data: Dictionary) -> void:
	version = int(data.get("version", 1))
	generator_version = int(data.get("generator_version", 1))

	# Migrate save data across versions
	if version < 2:
		_migrate_v1_to_v2(data)
	if version < 3:
		_migrate_v2_to_v3(data)
	if version < 4:
		_migrate_v3_to_v4(data)
	if version < 5:
		_migrate_v4_to_v5(data)
	version = CURRENT_VERSION

	run_seed = int(data.get("run_seed", 0))
	var raw_date = data.get("date", {})
	if not (raw_date is Dictionary):
		raw_date = {}

	date = {
		"month": int(raw_date.get("month", 1)),
		"week": int(raw_date.get("week", 1)),
		"day": int(raw_date.get("day", 1)),
	}
	hero = data.get("hero", {})
	world = data.get("world", {})
	var raw_cities = data.get("cities", [])
	cities = raw_cities if raw_cities is Array else []
	var raw_chars = data.get("characters", [])
	characters = raw_chars if raw_chars is Array else []
	successor = data.get("successor", {})
	if not (successor is Dictionary):
		successor = {}
	legend = data.get("legend", {})
	if not (legend is Dictionary):
		legend = {}
	session = data.get("session", {})
	if not (session is Dictionary):
		session = {}

func _migrate_v1_to_v2(data: Dictionary) -> void:
	## v2: ensure hero.time_mp_spent exists for mana persistence
	if not data.has("hero"):
		data["hero"] = {}
	if not data["hero"].has("time_mp_spent"):
		data["hero"]["time_mp_spent"] = 0.0


func _migrate_v2_to_v3(data: Dictionary) -> void:
	## v3: города и персонажи (Каскад Сложности). В v2-сейвах их нет —
	## город пересоздаётся при загрузке, персонажи появятся в первый ход.
	if not data.has("cities") or not (data["cities"] is Array):
		data["cities"] = []
	if not data.has("characters") or not (data["characters"] is Array):
		data["characters"] = []

func _migrate_v3_to_v4(data: Dictionary) -> void:
	## v4: преемник и легенда. В v3-сейвах их нет — заполняем пустыми
	## словарями (преемник не выбран, легенда не накоплена).
	if not data.has("successor") or not (data["successor"] is Dictionary):
		data["successor"] = {}
	if not data.has("legend") or not (data["legend"] is Dictionary):
		data["legend"] = {}

	# path_id героя уже сериализуется с v4 (HeroController.path_id); для
	# v3-сейвов без него — путь героя остаётся пустым (pristine run).
	if not data["hero"].has("path_id"):
		data["hero"]["path_id"] = ""


func _migrate_v4_to_v5(data: Dictionary) -> void:
	## v5: состояние забега (endgame). В v4-сейвах его нет — забег считается
	## живым (RUNNING без причины).
	if not data.has("session") or not (data["session"] is Dictionary):
		data["session"] = {}


func is_valid() -> bool:
	# Version is already migrated in from_dict(); we only need structural checks
	if run_seed <= 0:
		return false
	if not (hero is Dictionary) or hero.is_empty():
		return false
	if not hero.has("cell"):
		return false
	if not (hero["cell"] is Dictionary):
		return false
	if not (world is Dictionary):
		return false
	return true

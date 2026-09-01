class_name RaceClassRegistry
extends RefCounted
## city-in-world: data-driven реестр рас и классов (Pathfinder) из
## `races_classes.json`. Ленивая загрузка. Хранит 6 рас × 16 классов × 4
## архетипа + подсистемы (bloodlines/domains/prestige/feats) как данные
## для будущих циклов. Не ломает текущую модель героя — только модификаторы.
##
## Все cross-file-типы — preload-константы (Godot резолвит preload-константу
## как аннотацию типа, в отличие от class_name другого файла).

const JSON_PATH := "res://assets/data/races_classes.json"

const _RaceDef = preload("res://scripts/data/RaceDef.gd")
const _ClassDef = preload("res://scripts/data/ClassDef.gd")

var _races: Dictionary[StringName, _RaceDef] = {}      # id -> RaceDef
var _classes: Dictionary[StringName, _ClassDef] = {}   # id -> ClassDef
var _bloodlines: Dictionary = {}  # id -> Dictionary
var _domains: Dictionary = {}     # id -> Dictionary
var _prestige: Dictionary = {}    # id -> Dictionary
var _feats: Dictionary = {}       # id -> Dictionary
var _loaded: bool = false

## Ленивая загрузка из JSON (один раз).
func ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_load_from_json()

## Пересборка (для тестов/рестарта мира).
func reset() -> void:
	_races.clear()
	_classes.clear()
	_bloodlines.clear()
	_domains.clear()
	_prestige.clear()
	_feats.clear()
	_loaded = false

func _load_from_json() -> void:
	if not FileAccess.file_exists(JSON_PATH):
		push_warning("RaceClassRegistry: %s not found" % JSON_PATH)
		return
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null or not (data is Dictionary):
		push_error("RaceClassRegistry: invalid JSON format")
		return
	_parse_races(Array(data.get("races", [])))
	_parse_classes(Array(data.get("classes", [])))
	_bloodlines = _index(data.get("bloodlines", []))
	_domains = _index(data.get("domains", []))
	_prestige = _index(data.get("prestige_classes", []))
	_feats = _index(data.get("feats", []))
	GameLogger.info(
		"Loaded %d races, %d classes from %s"
		% [_races.size(), _classes.size(), JSON_PATH], "RaceClass")

func _parse_races(entries: Array) -> void:
	for e in entries:
		if not (e is Dictionary):
			continue
		var rd: _RaceDef = _RaceDef.from_dict(e)
		if not rd.id.is_empty():
			_races[rd.id] = rd

func _parse_classes(entries: Array) -> void:
	for e in entries:
		if not (e is Dictionary):
			continue
		var cd: _ClassDef = _ClassDef.from_dict(e)
		if not cd.id.is_empty():
			_classes[cd.id] = cd

func _index(entries: Array) -> Dictionary:
	var out: Dictionary = {}
	for e in entries:
		if e is Dictionary and e.get("id", "") != "":
			out[StringName(String(e["id"]))] = e
	return out

## --- Доступ ---
func get_race(id: Variant) -> _RaceDef:
	ensure()
	return _races.get(String(id))

func get_class_def(id: Variant) -> _ClassDef:
	ensure()
	return _classes.get(String(id))

func all_races() -> Array[_RaceDef]:
	ensure()
	return _races.values()

func all_classes() -> Array[_ClassDef]:
	ensure()
	return _classes.values()

## Размер без авто-загрузки: чистый запрос текущего размера (после ensure()).
func count_races() -> int:
	return _races.size()

func count_classes() -> int:
	return _classes.size()

## --- Подсистемы (данные для будущих циклов) ---
func get_bloodline(id: Variant) -> Dictionary:
	ensure()
	var v: Dictionary = _bloodlines.get(String(id))
	return v if v != null else {}

func get_domain(id: Variant) -> Dictionary:
	ensure()
	var v: Dictionary = _domains.get(String(id))
	return v if v != null else {}

func get_prestige(id: Variant) -> Dictionary:
	ensure()
	var v: Dictionary = _prestige.get(String(id))
	return v if v != null else {}

func get_feat(id: Variant) -> Dictionary:
	ensure()
	var v: Dictionary = _feats.get(String(id))
	return v if v != null else {}

## --- Взвешенный выбор (веса = 1 по умолчанию) ---
func pick_race(rng: RandomNumberGenerator) -> _RaceDef:
	var list := all_races()
	if list.is_empty():
		return null
	return list[rng.randi_range(0, list.size() - 1)]

func pick_class(rng: RandomNumberGenerator) -> _ClassDef:
	var list := all_classes()
	if list.is_empty():
		return null
	return list[rng.randi_range(0, list.size() - 1)]

## Выбор архетипа класса (or null, если архетипов нет).
func pick_archetype(class_def: _ClassDef, rng: RandomNumberGenerator) -> Dictionary:
	if class_def == null:
		return {}
	var arches: Array[Dictionary] = class_def.archetypes
	if arches.is_empty():
		return {}
	return arches[rng.randi_range(0, arches.size() - 1)]

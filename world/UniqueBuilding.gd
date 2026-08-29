class_name UniqueBuilding
extends RefCounted
## Уникальное здание (строится вне районов), до 3 уровней.
## Постройка = уровень 1; улучшения 2/3 требуют ресурсов, закрепления
## последователей и физического присутствия героя на клетке здания.

class Def extends RefCounted:
	var id: StringName = &""
	var display_name := ""
	## Требования по уровням: levels[0] — постройка, levels[1] — ур.2, levels[2] — ур.3.
	var levels: Array = []
	## Если true — строится только на спец. площадке (руины/святилище/луга),
	## без ограничения дистанции.
	var requires_site := false

class LevelReq extends RefCounted:
	var industry := 0.0
	var special_resource: StringName = &""  # ключ городского склада, &"" = не нужен
	var special_amount := 0.0
	var followers := 0  # закрепляется за зданием (списывается из свободных)

var def: Def = null
var cell := Vector2i(-1, -1)
var level := 0  # 0 = не построено (объект-запись), рабочие здания — 1..3
var uid := 0
var assigned_followers := 0
# --- Зонирование и экономика (M1/M3) ---
## Тип зоны (ZoningSystem.ZoneType). 0 = не участвует в зонировании.
var zone_type: int = 0
## Цепочка производства (M1). null = здание не производит.
var production_chain: ProductionChain = null
## Поддержка: StringName -> float (ресурсов в день).
var upkeep: Dictionary = {}  # {} = поддержки нет


func get_zone_type() -> int:
	return zone_type


func get_production_chain() -> ProductionChain:
	return production_chain


func get_upkeep() -> Dictionary:
	return upkeep


func next_level_req() -> LevelReq:
	## Требования перехода на следующий уровень или null.
	if def == null or level >= CityBalance.BUILDING_MAX_LEVEL:
		return null
	if level >= def.levels.size():
		return null
	return def.levels[level]

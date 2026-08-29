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
	## Спринт 7: жильё — PopUnit.State (int) -> слотов. Пусто = не жильё.
	## Рабочие: хижина; ополченцы: казарма; учёные: особняк.
	var housing: Dictionary = {}
	## Спринт 8: цепочка производства по умолчанию (ставится при постройке;
	## UI/тесты могут переопределить bld.production_chain).
	var production_chain: ProductionChain = null
	## Спринт 8: upkeep/зона по умолчанию (legacy-поля здания).
	var default_upkeep: Dictionary = {}
	var default_zone := 0

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
## Множитель зоны (ZoningSystem, M3). Обновляется CityTurnProcessor каждый
## ход; 1.0 = без бонусов. Экономическая фаза умножает на логистику.
var zone_multiplier: float = 1.0


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


## ==================== СЕРИАЛИЗАЦИЯ (save v3) ====================
func serialize() -> Dictionary:
	var d := {
		"def_id": String(def.id) if def != null else "",
		"cell": {"x": cell.x, "y": cell.y},
		"level": level,
		"uid": uid,
		"assigned_followers": assigned_followers,
		"zone_type": zone_type,
		"upkeep": {},
		"zone_multiplier": zone_multiplier,
	}
	var upkeep_str: Dictionary = {}
	for k in upkeep:
		upkeep_str[String(k)] = float(upkeep[k])
	d["upkeep"] = upkeep_str
	if production_chain != null:
		d["chain"] = production_chain.to_dict()
	return d


static func deserialize(data: Dictionary, def: UniqueBuilding.Def) -> UniqueBuilding:
	## def — перевязка по BuildingDefs.def_by_id() (делает вызывающий).
	var b := UniqueBuilding.new()
	b.def = def
	var c: Dictionary = data.get("cell", {})
	b.cell = Vector2i(int(c.get("x", -1)), int(c.get("y", -1)))
	b.level = int(data.get("level", 0))
	b.uid = int(data.get("uid", 0))
	b.assigned_followers = int(data.get("assigned_followers", 0))
	b.zone_type = int(data.get("zone_type", 0))
	b.zone_multiplier = float(data.get("zone_multiplier", 1.0))
	var raw_upkeep: Dictionary = data.get("upkeep", {})
	for k in raw_upkeep:
		b.upkeep[StringName(k)] = float(raw_upkeep[k])
	var raw_chain: Dictionary = data.get("chain", {})
	if not raw_chain.is_empty():
		b.production_chain = ProductionChain.from_dict(raw_chain)
	return b

class_name BuildingDefs
extends RefCounted
## Каталог уникальных зданий. Только данные — логика в City/BoroughRules.

const SITE_RUINS := &"ruins"
const SITE_SHRINE := &"shrine"
const SITE_MEADOW := &"meadow"

## Великий Храм: определяет циклический приток (База = 2 + L×2). Требует святилище.
static func great_temple() -> UniqueBuilding.Def:
	return _mk(&"great_temple", "Великий Храм", true, [
		_req(30.0),
		_req(60.0, 2),
		_req(120.0, 3, &"gold", 50.0),
	])

static func market() -> UniqueBuilding.Def:
	return _mk(&"market", "Рынок", false, [
		_req(25.0),
		_req(50.0, 2, &"gold", 40.0),
		_req(100.0, 3, &"gold", 80.0),
	])

static func barracks() -> UniqueBuilding.Def:
	## Казармы: +5 слотов ополчения (Спринт 7).
	var d := _mk(&"barracks", "Казармы", false, [
		_req(20.0),
		_req(40.0, 2),
		_req(80.0, 3, &"gold", 30.0),
	])
	d.housing[PopUnit.State.MILITIA] = 5
	return d

static func ancient_vault() -> UniqueBuilding.Def:
	return _mk(&"ancient_vault", "Древнее хранилище", true, [
		_req(35.0),
		_req(70.0, 2),
		_req(140.0, 3, &"gold", 60.0),
	])


static func walls() -> UniqueBuilding.Def:
	## Стены (Спринт 10): защита города от рейдов.
	## +RaidSystem.DEFENSE_PER_WALL к обороне за каждый уровень.
	return _mk(&"walls", "Стены", false, [
		_req(20.0),
		_req(50.0, 2, &"gold", 30.0),
		_req(100.0, 3, &"gold", 60.0),
	])


## --- Цепочки производства (Спринт 8) ---
## Порядок цепочек: зерно->мука->хлеб, руда->инструменты,
## училище->баллы учёных, таверна/торговый пост->золото.
static func farm() -> UniqueBuilding.Def:
	## Ферма: 2 рабочих -> зерно.
	var d := _mk(&"farm", "Ферма", false, [_req(12.0)])
	d.production_chain = _chain(&"farm_chain", 2, {}, {&"grain": 3.0})
	return d


static func mill() -> UniqueBuilding.Def:
	## Мельница: 1 рабочий, зерно -> мука. Бонус: у 2+ ферм x1.5 (adjacency).
	var d := _mk(&"mill", "Мельница", false, [_req(18.0)])
	d.production_chain = _chain(&"mill_chain", 1, {&"grain": 2.0}, {&"flour": 2.0})
	d.default_upkeep[&"wood"] = 1.0
	return d


static func bakery() -> UniqueBuilding.Def:
	## Пекарня: 1 рабочий, мука -> хлеб.
	var d := _mk(&"bakery", "Пекарня", false, [_req(18.0)])
	d.production_chain = _chain(&"bakery_chain", 1, {&"flour": 2.0}, {&"bread": 2.0})
	d.default_upkeep[&"wood"] = 1.0
	return d


static func mine() -> UniqueBuilding.Def:
	## Рудник: 2 рабочих -> руда.
	var d := _mk(&"mine", "Рудник", false, [_req(20.0)])
	d.production_chain = _chain(&"mine_chain", 2, {}, {&"ore": 2.0})
	return d


static func smithy() -> UniqueBuilding.Def:
	## Кузница: 1 рабочий, руда + дерево -> инструменты.
	## Бонус: у рудника x3 (adjacency).
	var d := _mk(&"smithy", "Кузница", false, [_req(25.0)])
	d.production_chain = _chain(&"smithy_chain", 1,
		{&"ore": 1.0, &"wood": 1.0}, {&"tools": 1.0})
	d.default_upkeep[&"wood"] = 1.0
	return d


static func school() -> UniqueBuilding.Def:
	## Училище: 1 рабочий -> баллы учёных (повышение, Спринт 7).
	var d := _mk(&"school", "Училище", false, [_req(30.0)])
	d.production_chain = _chain(&"school_chain", 1, {}, {&"scholar_points": 1.0})
	d.default_upkeep[&"wood"] = 2.0
	return d


static func tavern() -> UniqueBuilding.Def:
	## Таверна: 1 рабочий -> золото. Бонус: у жилья +2 репутации.
	var d := _mk(&"tavern", "Таверна", false, [_req(22.0)])
	d.production_chain = _chain(&"tavern_chain", 1, {}, {&"gold": 1.0})
	return d


static func trade_post() -> UniqueBuilding.Def:
	## Торговый пост: 2 рабочих, хлеб -> золото (продажа излишков).
	var d := _mk(&"trade_post", "Торговый пост", false, [_req(28.0)])
	d.production_chain = _chain(&"trade_post_chain", 2, {&"bread": 1.0}, {&"gold": 2.0})
	return d


## --- Жильё (Спринт 7) ---
static func shack() -> UniqueBuilding.Def:
	## Хижина: +10 слотов рабочих.
	var d := _mk(&"shack", "Хижина", false, [_req(15.0)])
	d.housing[PopUnit.State.WORKER] = 10
	return d


static func manor() -> UniqueBuilding.Def:
	## Особняк: +2 слота учёных (жильё для повышения).
	var d := _mk(&"manor", "Особняк", false, [_req(40.0)])
	d.housing[PopUnit.State.SCHOLAR] = 2
	return d


## city-in-world: полный каталог определений (CityScreen: список строящихся).
static func all() -> Array[UniqueBuilding.Def]:
	return [
		great_temple(), market(), barracks(), ancient_vault(), walls(),
		farm(), mill(), bakery(), mine(), smithy(), school(), tavern(),
		trade_post(), shack(), manor(),
	]


## Перевязка определения по id (save v3: восстановление зданий).
## Неизвестный id -> null (здание не восстанавливается).
static func def_by_id(id: StringName) -> UniqueBuilding.Def:
	match id:
		&"great_temple":
			return great_temple()
		&"market":
			return market()
		&"barracks":
			return barracks()
		&"ancient_vault":
			return ancient_vault()
		&"walls":
			return walls()
		&"shack":
			return shack()
		&"manor":
			return manor()
		&"farm":
			return farm()
		&"mill":
			return mill()
		&"bakery":
			return bakery()
		&"mine":
			return mine()
		&"smithy":
			return smithy()
		&"school":
			return school()
		&"tavern":
			return tavern()
		&"trade_post":
			return trade_post()
	return null


static func _mk(
	id: StringName, display_name: String, requires_site: bool, levels: Array
) -> UniqueBuilding.Def:
	var d := UniqueBuilding.Def.new()
	d.id = id
	d.display_name = display_name
	d.requires_site = requires_site
	d.levels = levels
	return d


## Цепочка производства здания (копируется per-building при постройке).
static func _chain(
	id: StringName, workers: int,
	inputs: Dictionary = {}, outputs: Dictionary = {}
) -> ProductionChain:
	var c := ProductionChain.new()
	c.id = id
	c.required_workers = workers
	for k in inputs:
		c.inputs[StringName(k)] = float(inputs[k])
	for k in outputs:
		c.outputs[StringName(k)] = float(outputs[k])
	return c


static func _req(
	industry: float, followers := 0, res := &"", amount := 0.0
) -> UniqueBuilding.LevelReq:
	var r := UniqueBuilding.LevelReq.new()
	r.industry = industry
	r.followers = followers
	r.special_resource = res
	r.special_amount = amount
	return r

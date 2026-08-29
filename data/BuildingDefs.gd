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
		&"shack":
			return shack()
		&"manor":
			return manor()
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


static func _req(
	industry: float, followers := 0, res := &"", amount := 0.0
) -> UniqueBuilding.LevelReq:
	var r := UniqueBuilding.LevelReq.new()
	r.industry = industry
	r.followers = followers
	r.special_resource = res
	r.special_amount = amount
	return r

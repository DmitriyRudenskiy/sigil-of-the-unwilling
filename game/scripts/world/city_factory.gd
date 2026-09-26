class_name CityFactory
extends RefCounted

const VILLAGE_NAMES: Array = [
	"Озёрные Пруды", "Медвежий Лог", "Глухая Падь", "Старый Мост",
	"Берёзовая Роща", "Каменная Бухта", "Тихая Гавань", "Сосновый Курган",
	"Ярмарочная Слобода", "Пепельный Край", "Зелёные Ворота", "Волчий Перевал",
	"Млиный Утёс", "Тёплый Рудник", "Северное Село", "Дальний Посад",
]

static func village_name(seed_val: int, cell: Vector2i) -> String:
	var h: int = hash([seed_val, cell.x, cell.y])
	return VILLAGE_NAMES[absi(h) % VILLAGE_NAMES.size()]

static func create_village(center: Vector2i, display_name: String, _seed: int = 0) -> City:
	var city := City.new()
	city.center = center
	city.display_name = display_name
	city.owner = &"player"
	city.stronghold_level = 1
	city.faction = City.Faction.DEFAULT
	apply_starting_kit(city)
	return city

static func apply_starting_kit(city: City) -> void:
	if city == null:
		return
	city.storage[&"industry"] = GameNumbers.VILLAGE_START_INDUSTRY
	city.food_stockpile = GameNumbers.VILLAGE_START_FOOD
	city.ensure_resource_ctx()
	city.resource_ctx.add(&"gold", GameNumbers.VILLAGE_START_GOLD)
	for i in GameNumbers.VILLAGE_START_WORKERS:
		var u: PopUnit = city.add_migrant(PopUnit.State.WORKER, -1)
		u.tile = _first_free_worker_tile(city)
	for i in GameNumbers.VILLAGE_START_FOLLOWERS:
		city.add_migrant(PopUnit.State.FOLLOWER, -1)

static func _first_free_worker_tile(city: City) -> Vector2i:
	for nb in HexUtils.get_all_neighbors(city.center):
		if city.is_worker_tile_free(nb):
			return nb
	return Vector2i(-1, -1)

class_name CityFactory
extends RefCounted
## city-in-world: фабрика городов мира. Общий конструктор для захвата деревни
## и восстановления города при загрузке сейва (один код — одна детермина).

## Имена деревень (статическая таблица; индекс — от (seed, cell)).
const VILLAGE_NAMES: Array = [
	"Озёрные Пруды", "Медвежий Лог", "Глухая Падь", "Старый Мост",
	"Берёзовая Роща", "Каменная Бухта", "Тихая Гавань", "Сосновый Курган",
	"Ярмарочная Слобода", "Пепельный Край", "Зелёные Ворота", "Волчий Перевал",
	"Млиный Утёс", "Тёплый Рудник", "Северное Село", "Дальний Посад",
]

## Детерминированное имя деревни: одно и то же (seed, cell) → одно имя.
## Используется и захватом, и при восстановлении из сейва.
static func village_name(seed: int, cell: Vector2i) -> String:
	var h: int = hash([seed, cell.x, cell.y])
	return VILLAGE_NAMES[absi(h) % VILLAGE_NAMES.size()]


## Создаёт захваченную деревню: уровень 1, владелец — игрок, стартовый
## набор (apply_starting_kit).
static func create_village(center: Vector2i, display_name: String, seed: int = 0) -> City:
	var city := City.new()
	city.center = center
	city.display_name = display_name
	city.owner = &"player"
	city.stronghold_level = 1
	city.faction = City.Faction.DEFAULT
	apply_starting_kit(city)
	return city


## Стартовый набор города мира (деревня и столица): ресурсы + рабочие на
## клетках-соседях центра (детерминированная расстановка: фиксированный
## порядок get_all_neighbors) + свободные последователи (CITY_HIRE работает
## с первого хода). Рабочие занимают клетки, последователи — нет.
static func apply_starting_kit(city: City) -> void:
	if city == null:
		return
	city.storage[&"industry"] = CityBalance.VILLAGE_START_INDUSTRY
	city.food_stockpile = CityBalance.VILLAGE_START_FOOD
	city.ensure_resource_ctx()
	city.resource_ctx.add(&"gold", CityBalance.VILLAGE_START_GOLD)
	# Рабочие: первые свободные клетки-соседи центра (порядок HexUtils фиксирован).
	for i in CityBalance.VILLAGE_START_WORKERS:
		var u: PopUnit = city.add_migrant(PopUnit.State.WORKER, -1)
		u.tile = _first_free_worker_tile(city)
	# Свободные последователи: без клеток (pop-юниты FOLLOWER, tile = -1,-1).
	for i in CityBalance.VILLAGE_START_FOLLOWERS:
		city.add_migrant(PopUnit.State.FOLLOWER, -1)


static func _first_free_worker_tile(city: City) -> Vector2i:
	for nb in HexUtils.get_all_neighbors(city.center):
		if city.is_worker_tile_free(nb):
			return nb
	return Vector2i(-1, -1)

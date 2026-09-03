## R2 (world-controller-decoupling): сериализация городов вынесена из
## SocketController в отдельный класс (weak coupling, KISS). RefCounted,
## без class_name — detached-тесты не грузят автозагрузки.
extends RefCounted

## city-in-world: действие в городе через РЕАЛЬНЫЙ CityScreen: открыть
## экран для города → выполнить то же действие, что делает кнопка → результат.
func city_action(world_ctrl, req: Dictionary, action: String) -> Dictionary:
	if world_ctrl == null or not world_ctrl.is_world_visible():
		return {"error": "Not in World mode"}
	var city = resolve_city(world_ctrl, req)
	if city == null:
		return {"error": "City not found"}
	var ui_mgr = world_ctrl.get_ui_manager()
	if ui_mgr == null:
		return {"error": "No UI manager (city screen unavailable)"}
	var hero = world_ctrl.get_hero()
	var hero_cell: Vector2i = hero.current_cell if hero != null else Vector2i(-1, -1)
	var args: Variant = req.get("args", {})
	if not (args is Dictionary):
		args = {}
	var building := str(args.get("building", "farm"))
	var res: Dictionary = ui_mgr.city_screen_action(action, city, hero_cell, building)
	res["city"] = city_state_dict(city)
	return res

## city-in-world: город из args: {"uid": N} или {"cell": {"x","y"}}; если
## ничего не передано — столица.
func resolve_city(world_ctrl, req: Dictionary) -> City:
	var cities = world_ctrl.get_cities()
	if cities == null:
		return null
	var args: Variant = req.get("args", {})
	if args is Dictionary:
		if args.has("uid"):
			var c = cities.get_city_by_uid(int(args.get("uid")))
			if c != null:
				return c
			return null
		if args.has("cell") and args.get("cell") is Dictionary:
			var cell: Dictionary = args.get("cell")
			var c = cities.city_at(Vector2i(int(cell.get("x", -1)), int(cell.get("y", -1))))
			if c != null:
				return c
	return cities.capital

## city-in-world: JSON-совместимый снимок города (GET_STATE / ответы CITY_*).
func city_state_dict(city: City) -> Dictionary:
	if city == null:
		return {}
	return {
		"uid": city.uid,
		"name": city.display_name,
		"center": {"x": city.center.x, "y": city.center.y},
		"level": city.level,
		"owner": String(city.owner),
		"population": city.pop_capped(),
		"free_followers": city.free_followers(),
		"food": city.food_stockpile,
		"prosperity": city.prosperity,
		"gold": city.resource_ctx.amount(&"gold") if city.resource_ctx != null else 0.0,
		"industry": float(city.storage.get(&"industry", 0.0)),
		"buildings": city.buildings.size(),
	}
